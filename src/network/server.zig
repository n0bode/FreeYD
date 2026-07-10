const std = @import("std");
const net = std.Io.net;

const Init = std.process.Init;
const Address = net.IpAddress;
const Allocator = std.mem.Allocator;
const Peer = @import("peer.zig").Peer;
const Database = @import("db").Database;
const logger = std.log;

const PacketInput = @import("packet/packet.zig").PacketInput;

pub const Callbacks = struct {
    onReceivePacket: ?struct {
        userdata: *anyopaque,
        func: *const fn (*anyopaque, peer: *Peer, packet: ?*PacketInput) bool,
    } = null,
};

const LinkedList = std.SinglyLinkedList;

const PeerListItem = struct {
    peer: Peer,
    node: LinkedList.Node = .{},
};

pub const Server = struct {
    pub const ServerConfig = struct {
        host: []const u8,
        port: u16,
        pub fn default() ServerConfig {
            return .{
                .port = 8281,
                .host = "0.0.0.0",
            };
        }
    };

    const State = enum {
        none,
        running,
        disconnected,
        disconnecting,
    };

    address: ?Address,
    state: State,
    socketServer: ?net.Server,
    group: std.Io.Group,
    allocator: Allocator,
    peers: []?*Peer,
    callbacks: Callbacks,

    pub fn init(
        allocator: Allocator,
        config: ServerConfig,
        callbacks: Callbacks,
    ) !Server {
        const address = net.IpAddress.parse(config.host, config.port) catch |err| {
            logger.err("host:port({s}:{d}) invalid: {s}", .{ config.host, config.port, @errorName(err) });
            return error.ParseIP;
        };

        var self = Server{
            .state = .none,
            .socketServer = null,
            .address = address,
            .group = .init,
            .allocator = allocator,
            .peers = undefined,
            .callbacks = callbacks,
        };

        self.peers = try allocator.alloc(?*Peer, 100);
        for (self.peers, 0..) |_, slot| {
            self.peers[slot] = null;
        }
        return self;
    }

    pub fn deinit(self: *Server, io: std.Io) void {
        self.socketServer.?.deinit(io);
    }

    pub fn run(self: *Server, io: std.Io) !void {
        const address = self.address orelse return;

        self.group = .init;
        self.socketServer = address.listen(io, .{
            .mode = .stream,
            .reuse_address = true,
        }) catch |err| {
            logger.err("failed to listen server: {s}", .{@errorName(err)});
            return error.BindSocket;
        };

        self.state = .running;
        try self.group.concurrent(io, Server.waitAcceptConnect, .{ self, io });
    }

    pub fn stop(self: *Server, io: std.Io) !void {
        if (self.state == .running) {
            self.state = .disconnecting;
            self.group.cancel(io);

            if (self.socketServer) |*server| {
                server.deinit(io);
            }
            self.state = .disconnected;
        }
        try self.group.await(io);
    }

    fn waitAcceptConnect(self: *Server, io: std.Io) void {
        while (self.state == .running) {
            self.acceptConnection(io) catch |err| {
                logger.warn("accept connection failed: {s}\n", .{@errorName(err)});
                continue;
            };
        }
    }

    fn acceptConnection(self: *Server, io: std.Io) !void {
        var socketServer = self.socketServer orelse return;
        logger.debug("wait new connection", .{});
        const stream = socketServer.accept(io) catch |err| switch (err) {
            net.Server.AcceptError.Canceled => {
                return error.Canceled;
            },
            else => {
                logger.warn("failed to accept peer: {s}", .{@errorName(err)});
                return error.AcceptPeer;
            },
        };

        var buffer: [16]u8 = undefined;
        if (formatIpAddress(io, stream.socket.address, &buffer)) |ipAddress| {
            logger.debug("new connection from: {s}", .{ipAddress});
        }

        if (self.getEmptySlot()) |peerId| {
            self.peers[peerId] = try Peer.initAlloc(
                self.allocator,
                @intCast(peerId),
                stream,
                .{
                    .onChangeState = .{
                        .userdata = self,
                        .func = onChangePeerState,
                    },
                    .onReceivePacket = .{
                        .userdata = self,
                        .func = onReceivePacket,
                    },
                },
            );

            logger.debug("{d} peer accepted", .{peerId});
            if (self.peers[peerId]) |peer| {
                peer.accept(io, &self.group) catch |err| {
                    switch (err) {
                        error.InvalidInitCode => {
                            logger.err("peer cannot init with invalid code", .{});
                        },
                        else => {
                            logger.err("failed to accept peer: {s}", .{@errorName(err)});
                        },
                    }
                    stream.socket.close(io);
                };
            }
        } else {
            logger.debug("server is full", .{});
            stream.close(io);
        }
    }

    fn clearSlot(self: *Server, peerId: usize) void {
        if (self.peers[peerId]) |*peer| {
            self.peers[peerId] = null;
            self.allocator.destroy(peer);
        }
    }

    fn getEmptySlot(self: *Server) ?usize {
        for (1..self.peers.len) |slot| {
            if (self.peers[slot]) |peer| {
                // empty or disconnected
                if (@intFromEnum(peer.state) & 0b10 == 0) {
                    return slot;
                }
                continue;
            }
            return slot;
        }
        return null;
    }
};

fn formatIpAddress(io: std.Io, address: net.IpAddress, buffer: []u8) ?[]u8 {
    var writer = std.Io.Writer.fixed(buffer);
    address.formatResolved(io, &writer) catch {
        return null;
    };
    return writer.buffered();
}

fn onChangePeerState(server: *anyopaque, io: std.Io, peer: *Peer, state: Peer.State) void {
    const self: *Server = @ptrCast(@alignCast(server));
    logger.info("user({d}): handle event {s}", .{ peer.peerID, @tagName(state) });
    switch (state) {
        .Disconnected => {
            if (self.callbacks.onReceivePacket) |callback| {
                if (peer.state == .Connected) {
                    _ = callback.func(callback.userdata, peer, null);
                }
            }
            peer.stream.close(io);
            self.clearSlot(peer.peerID);
        },
        .Invalid => {
            if (self.callbacks.onReceivePacket) |callback| {
                if (peer.state == .Connected) {
                    _ = callback.func(callback.userdata, peer, null);
                }
            }
            peer.stream.close(io);
            self.clearSlot(peer.peerID);
        },
        else => {
            logger.info("no handled", .{});
        },
    }
}

fn onReceivePacket(op: *anyopaque, peer: *Peer, packet: ?*PacketInput) bool {
    const self: *Server = @ptrCast(@alignCast(op));

    if (self.callbacks.onReceivePacket) |callback| {
        return callback.func(callback.userdata, peer, packet);
    }
    return true;
}
