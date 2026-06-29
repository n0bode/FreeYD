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
            .operationCode = @intFromEnum(packet.Opcode.TEXTMESSAGE),
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

    pub fn sendPulse(self: *Peer, code: packet.Opcode) !void {
        var header = packet.Header{
            .operationCode = @intFromEnum(code),
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
                .charCreate => |req| {
                    logger.debug("create new char: {s} class: {s}", .{ req.name, @tagName(req.class) });
                    if (!self.onCreateCharacter(io, req)) {
                        logger.err("failed to create char", .{});
                    }
                },
                .pin => |pin| {
                    if (self.account.mode == .unset) {
                        const pinPassword = Account.PinPassword.fromChar(pin.numeric);
                        self.account.pinPassword = pinPassword;
                        self.account.mode = .normal;
                        if (!self.db.updateAccount(io, &self.account)) {
                            self.callChangeState(.Disconnected);
                        }
                    } else {
                        var pinAccount: [6]u8 = undefined;
                        self.account.pinPassword.toChars(pinAccount[0..]);
                        std.debug.print("{c}{c}-{c}{c}-{c}{c}\n", .{ pinAccount[0], pinAccount[1], pinAccount[2], pinAccount[3], pinAccount[4], pinAccount[5] });
                        if (!std.mem.eql(u8, pinAccount[0..], pin.numeric[0..])) {
                            self.sendPulse(packet.Opcode.PIN_FAIL) catch {
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

        var charList = std.mem.zeroInit(packet.PacketCharList, .{
            .header = packet.Header{
                .index = @intCast(self.userID),
                .operationCode = @intFromEnum(packet.Opcode.CHAR_LIST),
                .time = std.time.epoch.unix,
            },
            .gold = self.account.gold,
            .name = self.account.name,
            .characters = packet.PacketCharListData.from(self.account),
        });

        self.sendPacket(packet.PacketCharList, &charList) catch |err| {
            logger.err("failed to sent charlist: {s}", .{@errorName(err)});
            return false;
        };
        return true;
    }

    fn onCreateCharacter(self: *Peer, io: Io, request: packet.PacketCharCreate) bool {
        const slot: usize = @intCast(request.slot);
        var account = &self.account;

        if ((slot < 0 or slot > 4) or account.characters[slot].name[0] != 0) {
            self.sendPulse(.CHAR_CREATE_FAIL) catch {
                return false;
            };
            self.sendTextMessage("impossivel") catch {
                return false;
            };
            return false;
        }

        var char = &account.characters[slot];
        const name = std.mem.sliceTo(request.name[0..], 0);

        if (std.mem.eql(u8, name, "GM")) {
            self.sendPulse(.CHAR_CREATE_FAIL) catch {
                return false;
            };
            return false;
        }

        @memcpy(char.name[0..name.len], name[0..]);

        char.positionX = 2112;
        char.positionY = 2112;

        return self.db.updateAccount(io, account);
    }
};
