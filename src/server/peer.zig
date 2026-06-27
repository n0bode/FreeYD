const std = @import("std");

const decoder = @import("packet/decode.zig");
const encoder = @import("packet/encode.zig");
const packet = @import("packet/packet.zig");

const Io = std.Io;
const net = Io.net;

const Stream = net.Stream;

const logger = std.log;

const INIT_CODE = 0x1F11F311;

pub const Peer = struct {
    const State = enum(u3) {
        Empty = 0b000,
        Accepted = 0b001,
        Connected = 0b011,
        Disconnected = 0b010,
        Invalid = 0b100,
    };

    userID: u32,
    stream: Stream,
    state: State,

    bufferReader: [10 * 1024]u8,
    bufferWriter: [10 * 1024]u8,

    reader: net.Stream.Reader,
    writer: net.Stream.Writer,

    pub fn init(
        userID: u32,
        stream: Stream,
    ) Peer {
        return .{
            .stream = stream,
            .userID = userID,
            .state = .Accepted,
            .reader = undefined,
            .bufferReader = undefined,
            .bufferWriter = undefined,
            .writer = undefined,
        };
    }

    pub fn empty() Peer {
        return Peer{
            .stream = undefined,
            .userID = 0,
            .state = .Empty,
            .reader = undefined,
            .bufferReader = undefined,
            .bufferWriter = undefined,
            .writer = undefined,
        };
    }

    pub fn deinit(self: Peer, io: std.Io) void {
        self.stream.close(io);
    }

    pub fn accept(self: *Peer, io: Io, group: *Io.Group) !void {
        self.reader = self.stream.reader(io, &self.bufferReader);
        const reader = &self.reader.interface;

        self.writer = self.stream.writer(io, &self.bufferWriter);

        const initCode = try reader.takeInt(u32, .little);
        logger.debug("[{d}] initcode => {X}", .{ self.userID, initCode });
        if (initCode != INIT_CODE) {
            self.state = .Invalid;
            return error.InvalidInitCode;
        }

        group.async(io, Peer.readMessages, .{ self, io, reader });
    }

    pub fn sendTextMessage(self: *Peer, text: []const u8) !void {
        var writer = &self.writer.interface;

        const header = packet.Header{
            .index = @intCast(self.userID),
            .operationCode = packet.Opcode.TEXTMESSAGE,
            .time = 0,
            .verifier = undefined,
        };

        var message = packet.PacketTextMessage{
            .header = header,
            .message = undefined,
        };

        const min = @min(96, text.len);
        @memcpy(message.message[0..min], text[0..min]);

        const encoded = encoder.encode(packet.PacketTextMessage, &message) catch |err| {
            logger.err("failed to encode message: {s}", @errorName(err));
            return err;
        };

        logger.info("{b64}", .{encoded});
        try writer.writeAll(encoded);
        try writer.flush();
    }

    fn readMessages(self: *Peer, io: Io, reader: *Io.Reader) void {
        defer self.stream.socket.close(io);
        const userID = self.userID;

        // first message has a initCode,
        while (@intFromEnum(self.state) & 0b01 > 0) {
            const sizeBytes = reader.peekArray(2) catch |err| {
                logger.warn("failed to get size {s}", .{@errorName(err)});
                self.state = .Disconnected;
                return;
            };

            const size: u16 = @bitCast(sizeBytes[0..2].*);

            logger.debug("[{d}] waiting message size={d}", .{ userID, size });
            const data = reader.take(@intCast(size)) catch |err| {
                logger.warn("failed to get message {s}", .{@errorName(err)});
                self.state = .Disconnected;
                return;
            };

            logger.debug("[{d}] received {b64}", .{ userID, data });
            const packetDecoded = decoder.decode(data) catch |err| {
                logger.debug("[{d}] failed to accept message: {s}", .{ userID, @errorName(err) });
                self.state = .Invalid;
                return;
            };

            switch (packetDecoded) {
                .login => |login| {
                    logger.debug("[{d}] Login: User({s}):({s})", .{ userID, login.username, login.password });
                    self.sendTextMessage("Crazy train") catch {
                        logger.err("failed to send message", .{});
                    };
                },
                .textmessage => |message| {
                    logger.debug("[{d}] Message Received: {s}", .{ userID, message.message });
                },
                .unknown => |header| {
                    logger.debug("[{d}] Unknown opcode: {X}", .{ userID, header.operationCode });
                },
            }
        }
    }
};
