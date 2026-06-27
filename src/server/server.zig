const std = @import("std");
const net = std.Io.net;

const Init = std.process.Init;
const Address = net.IpAddress;
const Allocator = std.mem.Allocator;
const Peer = @import("peer.zig").Peer;
const logger = std.log;

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

    const PeerChangeStateData = struct {
        server: *Server,
        io: std.Io,
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
    peers: []Peer,
    userdata: PeerChangeStateData,

    pub fn init(allocator: Allocator, config: ServerConfig) !Server {
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
            .userdata = undefined,
        };

        self.peers = try allocator.alloc(Peer, 1024);
        for (self.peers, 0..) |_, i| {
            self.peers[i] = .empty();
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

        self.userdata = .{
            .server = self,
            .io = io,
        };
        self.state = .running;
        try self.group.concurrent(io, Server.waitAcceptConnect, .{ self, io });
    }

    pub fn stop(self: *Server, io: std.Io) void {
        if (self.state == .running) {
            self.state = .disconnecting;
            self.group.cancel(io);

            if (self.socketServer) |*server| {
                server.deinit(io);
            }
            self.state = .disconnected;
        }
    }

    fn waitAcceptConnect(self: *Server, io: std.Io) void {
        while (self.state == .running) {
            self.acceptConnection(io) catch |err| {
                logger.warn("accept connection failed: {s}\n", .{@errorName(err)});
                return;
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
            logger.debug("{d} peer accepted", .{peerId});
            self.peers[peerId] = .init(
                @intCast(peerId),
                stream,
                Server.onChangePeerState,
                &self.userdata,
            );

            var peer = self.peers[peerId];
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
        } else {
            logger.debug("server is full", .{});
            stream.close(io);
        }
    }

    fn onChangePeerState(ptr: *anyopaque, peer: *Peer, state: Peer.State) void {
        const data: *PeerChangeStateData = @ptrCast(@alignCast(ptr));
        const io = data.io;
        switch (state) {
            .Disconnected => {
                peer.stream.close(io);
            },
            .Invalid => {
                peer.stream.close(io);
            },
            else => {
                logger.info("no handled", .{});
            },
        }
    }

    fn getEmptySlot(self: *Server) ?usize {
        for (self.peers, 0..) |peer, id| {
            // empty or disconnected
            if (@intFromEnum(peer.state) & 0b10 == 0) {
                return id;
            }
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
