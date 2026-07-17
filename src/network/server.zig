const std = @import("std");
const net = std.Io.net;

const Init = std.process.Init;
const Address = net.IpAddress;
const Allocator = std.mem.Allocator;
const Peer = @import("peer.zig").Peer;
const Database = @import("db").Database;
const logger = std.log.scoped(.server);
const Clock = std.Io.Clock;

const PacketInput = @import("packet/packet.zig").PacketInput;

const ReceivePeerMessageFN = *const fn (*anyopaque, peer: *Peer, packet: ?*PacketInput) bool;

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

    allocator: Allocator,
    socketServer: ?net.Server,
    address: ?Address,

    state: State,
    group: std.Io.Group,
    io: std.Io,

    peers: []?*Peer,

    fnOnReceivePeerMessage: ?ReceivePeerMessageFN = null,
    udOnReceivePeerMessage: *anyopaque = undefined,

    startedAt: i64 = 0,

    pub fn init(
        allocator: Allocator,
        config: ServerConfig,
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
            .io = undefined,
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

    pub fn setOnReceivePeerMessage(self: *Server, func: ReceivePeerMessageFN, userdata: *anyopaque) void {
        self.fnOnReceivePeerMessage = func;
        self.udOnReceivePeerMessage = userdata;
    }

    pub fn run(self: *Server, io: std.Io) !void {
        const address = self.address orelse return;

        self.group = .init;
        self.io = io;
        self.socketServer = address.listen(io, .{
            .mode = .stream,
            .reuse_address = true,
        }) catch |err| {
            logger.err("failed to listen server: {s}", .{@errorName(err)});
            return error.BindSocket;
        };

        self.state = .running;
        self.startedAt = std.Io.Clock.boot.now(io).toMilliseconds();
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
            const ptr = try self.allocator.create(Peer);
            ptr.* = .init(self, @intCast(peerId), stream);

            self.peers[peerId] = ptr;
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
        if (self.peers[peerId]) |peer| {
            self.peers[peerId] = null;
            peer.deinit(self.io);
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

    pub fn getServerTime(self: *Server) i64 {
        return Clock.boot.now(self.io).toMilliseconds() - self.startedAt;
    }

    pub fn getLocalDate(self: *Server) std.Io.Timestamp {
        return Clock.real.now(self.io);
    }

    pub fn callPeerReceivePacket(self: *Server, peer: *Peer, packet: ?*PacketInput) bool {
        if (self.fnOnReceivePeerMessage) |callback| {
            return callback(self.udOnReceivePeerMessage, peer, packet);
        }
        return true;
    }

    pub fn onPeerChangeState(self: *Server, peer: *Peer, state: Peer.State) void {
        logger.info("user({d}): handle event {s}", .{ peer.peerId, @tagName(state) });
        switch (state) {
            .Disconnected => {
                if (self.fnOnReceivePeerMessage) |callback| {
                    _ = callback(self.udOnReceivePeerMessage, peer, null);
                }
                self.clearSlot(peer.peerId);
            },
            .Invalid => {
                if (self.fnOnReceivePeerMessage) |callback| {
                    _ = callback(self.udOnReceivePeerMessage, peer, null);
                }
                self.clearSlot(peer.peerId);
            },
            else => {
                logger.info("no handled", .{});
            },
        }
    }
};

fn formatIpAddress(io: std.Io, address: net.IpAddress, buffer: []u8) ?[]u8 {
    var writer = std.Io.Writer.fixed(buffer);
    address.formatResolved(io, &writer) catch {
        return null;
    };
    return writer.buffered();
}
