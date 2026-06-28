const std = @import("std");

const decoder = @import("packet/decode.zig");
const encoder = @import("packet/encode.zig");
const packet = @import("packet/packet.zig");
const Account = @import("core").domains.Account;

const Io = std.Io;
const net = Io.net;

const IDatabase = @import("db").Database;

const Stream = net.Stream;

const logger = std.log;

const INIT_CODE = 0x1F11F311;

pub const Peer = struct {
    pub const FNChangeState = *const fn (*anyopaque, *Peer, State) void;

    pub const State = enum(u4) {
        Invalid = 0b0000,
        Empty = 0b0001,
        Accepted = 0b0010,
        Logged = 0b0110,
        Connected = 0b1110,
        Disconnected = 0b0100,
    };

    userID: u32,
    stream: Stream,
    state: State,

    bufferReader: [10 * 1024]u8,
    bufferWriter: [10 * 1024]u8,

    reader: net.Stream.Reader,
    writer: net.Stream.Writer,

    account: Account,

    fnChangeState: ?FNChangeState,
    userdata: *anyopaque,
    db: IDatabase,
    lastReceiveTime: u64 = 0,

    pub fn init(
        database: IDatabase,
        userID: u32,
        stream: Stream,
        onchange: FNChangeState,
        userdata: *anyopaque,
    ) Peer {
        return .{
            .stream = stream,
            .userID = userID,
            .state = .Accepted,
            .reader = undefined,
            .bufferReader = undefined,
            .bufferWriter = undefined,
            .writer = undefined,
            .account = undefined,
            .fnChangeState = onchange,
            .userdata = userdata,
            .db = database,
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
            .account = undefined,
            .writer = undefined,
            .fnChangeState = null,
            .userdata = undefined,
            .db = undefined,
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

        logger.debug("sending message: {s}", .{message.message});

        const encoded = encoder.encode(packet.PacketTextMessage, &message) catch |err| {
            logger.err("failed to encode message: {s}", @errorName(err));
            return err;
        };

        logger.info("{b64}", .{encoded});
        try writer.writeAll(encoded);
        try writer.flush();
    }

    pub fn sendPacket(self: *Peer, comptime T: anytype, message: *T) !void {
        var writer = &self.writer.interface;

        const encoded = encoder.encode(T, message) catch |err| {
            logger.err("failed to encode message: {s}", @errorName(err));
            return err;
        };

        logger.info("{b64}", .{encoded});
        try writer.writeAll(encoded);
        try writer.flush();
    }

    pub fn sendPulse(self: *Peer, code: u16) !void {
        var header = packet.Header{
            .operationCode = code,
            .index = @intCast(self.userID),
            .time = std.time.epoch.unix,
            .verifier = undefined,
        };

        return try self.sendPacket(
            packet.Header,
            &header,
        );
    }

    fn callChangeState(self: *Peer, state: State) void {
        self.state = state;
        if (self.fnChangeState) |func| {
            func(self.userdata, self, state);
        }
    }

    fn readMessages(self: *Peer, io: Io, reader: *Io.Reader) void {
        const userID = self.userID;

        // first message has a initCode,
        while (@intFromEnum(self.state) & 0b10 > 0) {
            const sizeBytes = reader.peekArray(2) catch |err| {
                logger.warn("failed to get size {s}", .{@errorName(err)});
                self.callChangeState(.Invalid);
                return;
            };

            const size: u16 = @bitCast(sizeBytes[0..2].*);
            logger.debug("[{d}] waiting message size={d}", .{ userID, size });
            const data = reader.take(@intCast(size)) catch |err| {
                logger.warn("failed to get message {s}", .{@errorName(err)});
                self.callChangeState(.Invalid);
                return;
            };

            logger.debug("[{d}] received {b64}", .{ userID, data });
            const packetDecoded = decoder.decode(data) catch |err| {
                logger.debug("[{d}] failed to accept message: {s}", .{ userID, @errorName(err) });
                self.sendTextMessage("cliente invalido") catch {};
                self.callChangeState(.Invalid);
                continue;
            };

            self.lastReceiveTime = std.time.epoch.unix;
            switch (packetDecoded) {
                .login => |login| {
                    if (!self.onLogin(io, login)) {
                        self.sendTextMessage("usuario ou senha invalido") catch {
                            logger.err("failed to respond", .{});
                        };
                        self.callChangeState(.Invalid);
                        return;
                    }

                    self.callChangeState(.Connected);
                },
                .ping => {},
                .pin => |pin| {
                    if (self.account.mode == .unset) {
                        const pinPassword = Account.PinPassword.fromChar(pin.numeric);
                        self.account.pinBits = pinPassword;
                        self.account.mode = .normal;
                    } else {
                        var pinAccount: [6]u8 = undefined;
                        self.account.pinBits.toChars(&pinAccount);
                        if (!std.mem.eql(u8, pinAccount[0..], pin.numeric[0..])) {
                            self.sendPulse(packet.Opcode.PINFAIL) catch {
                                self.callChangeState(.Disconnected);
                                return;
                            };
                        }
                    }
                },
                .unknown => |header| {
                    logger.debug("[{d}] Unknown opcode: {X}", .{ userID, header.operationCode });
                },
            }
        }
    }

    fn onLogin(self: *Peer, io: Io, login: packet.PacketLogin) bool {
        if (self.state != .Accepted) {
            return false;
        }

        const username = std.mem.sliceTo(&login.username, 0);
        const password = std.mem.sliceTo(&login.password, 0);

        if (!self.db.login(io, username, password, &self.account)) {
            if (!self.db.signup(io, username, password, &self.account)) {
                logger.debug("username({s}) not found", .{username});
                return false;
            }
        }

        var charList = packet.PacketCharList{
            .header = .{
                .operationCode = packet.Opcode.CHARLIST,
                .index = @intCast(self.userID),
                .time = 0,
                .verifier = undefined,
            },
            .cargo = self.account.cargo,
            .cash = 0,
            .characters = .{
                .exp = [4]u32{ 0, 0, 0, 0 },
                .guild = [4]u16{ 0, 0, 0, 0 },
                .name = undefined,
                .inventory = undefined,
                .positionX = [4]i16{ 0, 0, 0, 0 },
                .positionY = [4]i16{ 0, 0, 0, 0 },
                .stats = undefined,
                .gold = [_]i32{1000} ** 4,
            },
            .dorimee = 0,
            .gold = 1000,
            .keys = undefined,
            .name = self.account.name,
        };
        self.sendPacket(packet.PacketCharList, &charList) catch {
            return false;
        };
        return true;
    }
};
