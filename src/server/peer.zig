const std = @import("std");

const decoder = @import("packet/decode.zig");
const encoder = @import("packet/encode.zig");
const packet = @import("packet/packet.zig");

const domain = @import("core").domains;
const Account = @import("core").domains.Account;
const Character = @import("core").domains.Character;

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

    pub const PlayerState = struct {
        positionX: i16 = 0,
        positionY: i16 = 0,
        charSelected: i8 = 0,
    };

    userID: u32,
    stream: Stream,
    state: State,

    bufferReader: [10 * 1024]u8,
    bufferWriter: [10 * 1024]u8,

    reader: net.Stream.Reader,
    writer: net.Stream.Writer,

    account: Account,
    playerState: PlayerState = .{},

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

    pub fn sendTextMessage(self: *Peer, comptime format: []const u8, args: anytype) !void {
        var writer = &self.writer.interface;

        const header = packet.Header{
            .index = @intCast(self.userID),
            .operationCode = @intFromEnum(packet.Opcode.TEXTMESSAGE),
            .time = 0,
            .verifier = undefined,
        };

        var message = packet.PacketTextMessage{
            .header = header,
        };

        const text = std.fmt.bufPrint(message.message[0..], format, args) catch {
            return error.FormatMessage;
        };

        logger.debug("sending message: {s}", .{text});

        const encoded = encoder.encode(packet.PacketTextMessage, &message) catch |err| {
            logger.err("failed to encode message: {s}", @errorName(err));
            return err;
        };

        logger.info("{b64}", .{encoded});
        try writer.writeAll(encoded);
        try writer.flush();
    }

    pub fn sendPacket(self: *Peer, message: anytype) !void {
        const T = switch (@typeInfo(@TypeOf(message))) {
            .pointer => |t| t.child,
            else => @compileError("message must be a pointer"),
        };

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

            const packetDecoded = decoder.decode(data) catch |err| {
                logger.debug("[{d}] failed to accept message: {s}", .{ userID, @errorName(err) });
                self.sendTextMessage("client is invalid", .{}) catch {};
                self.callChangeState(.Invalid);
                continue;
            };

            self.lastReceiveTime = std.time.epoch.unix;
            switch (packetDecoded) {
                .login => |login| {
                    if (!self.onLogin(io, login)) {
                        self.sendTextMessage("username or password is invalid", .{}) catch {
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
                        self.sendTextMessage("failed to delete character", .{}) catch {};
                        logger.err("failed to create char", .{});
                    }
                },
                .charDelete => |req| {
                    if (!self.onDeleteCharacter(io, req)) {
                        self.sendTextMessage("password is invalid", .{}) catch {};
                        logger.err("failed to delete char", .{});
                    }
                },
                .enterWorld => |req| {
                    self.onEnterWorld(io, req);
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
                .moveItem => |req| {
                    self.onMoveItem(io, req);
                },
                .moviment => |req| {
                    self.onAction(req);
                },
                .unknown => |unk| {
                    logger.debug("[{d}] Unknown opcode: {X}", .{ userID, unk.operationCode });
                },
            }
        }
    }

    fn onAction(self: *Peer, req: packet.PacketActionInput) void {
        var request = req;

        logger.info("pos({any}) to ({any})", .{ req.position, req.destination });
        request.header.time = @intCast(self.lastReceiveTime);
        request.header.operationCode = 0x369;
        request.position = req.position;
        request.header.index = @intCast(self.userID);
        request.command = [_]u8{0} ** 24;
        request.kind = 0;
        request.speed = req.speed * 10;

        self.sendPacket(&request) catch {};
    }

    fn onEnterWorld(self: *Peer, io: Io, req: packet.PacketEnterWorldInput) void {
        const slot: usize = @intCast(req.charSlot);
        if (slot > 4) {
            self.sendTextMessage("try again", .{}) catch {};
            return;
        }

        logger.info("ID: {d}", .{req.header.index});
        const char = &self.account.characters[slot];
        if (char.name[0] == 0) {
            self.sendTextMessage("character is invalid", .{}) catch {};
            return;
        }

        self.account.charSelected = @intCast(req.charSlot);
        self.playerState.charSelected = @intCast(req.charSlot);
        self.playerState.positionX = char.positionX;
        self.playerState.positionY = char.positionY;

        if (!self.db.updateAccount(io, &self.account)) {
            return;
        }

        char.positionX = 2112;
        char.positionY = 2042;

        var output = packet.PacketEnterWorldOutput{
            .header = .{
                .index = 0x7530,
                .operationCode = @intFromEnum(packet.Opcode.ENTERED_WORLD),
                .time = 0,
            },
            .position = .{ .x = char.positionX, .y = char.positionY },
            .character = .from(@intCast(self.userID), char),
        };

        self.sendPacket(&output) catch {
            return;
        };

        var trenier = std.mem.zeroInit(packet.PacketSpawnOutput, .{
            .header = .{
                .operationCode = 0x364,
                .index = 0x7530,
            },
            .position = .{ .x = char.positionX, .y = char.positionY },
            .mob = .{
                .entityId = @as(u16, @intCast(self.userID)),
                .stats = packet.CharStatsData.from(char.stats),
            },
        });

        @memcpy(trenier.mob.name[0..], char.name[0..12]);

        inline for (0..16) |id| {
            trenier.mob.items[id] = char.equipments[id].itemID;
        }

        self.sendPacket(&trenier) catch {};
        return;
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

        std.debug.print("tam = {d}\n", .{@sizeOf(packet.PacketCharList)});
        self.sendCharacterList(.CHAR_LIST);
        return true;
    }

    fn onMoveItem(self: *Peer, io: Io, req: packet.PacketMoveItemInput) void {
        self.swapItem(
            io,
            req.sourceSlot,
            req.sourceStorage,
            req.destSlot,
            req.destStorage,
        );
    }

    fn getItem(self: *Peer, slot: u8, storage: packet.StorageType) ?*domain.Item {
        const char = &self.account.characters[@intCast(self.playerState.charSelected)];
        return switch (storage) {
            .equip => &char.equipments[slot],
            .inventory => &char.carry[slot],
            .cargo => return &self.account.cargo[slot],
        };
    }

    fn swapItem(
        self: *Peer,
        io: Io,
        sourceSlot: u8,
        sourceStorage: packet.StorageType,
        destSlot: u8,
        destStorage: packet.StorageType,
    ) void {
        const sourceItem = self.getItem(sourceSlot, sourceStorage) orelse return;
        const destItem = self.getItem(destSlot, destStorage) orelse return;

        var from = packet.PacketCreateItemOutput{
            .header = .{
                .operationCode = @intFromEnum(packet.Opcode.CREATE_ITEM),
                .index = @intCast(self.userID),
                .time = std.time.epoch.unix,
            },
            .slot = sourceSlot,
            .slotType = @intCast(@intFromEnum(sourceStorage)),
            .item = .{ .index = destItem.itemID, .effects = destItem.effect },
        };

        var to = packet.PacketCreateItemOutput{
            .header = from.header,
            .slot = destSlot,
            .slotType = @intCast(@intFromEnum(destStorage)),
            .item = .{ .index = sourceItem.itemID, .effects = sourceItem.effect },
        };

        self.sendPacket(&from) catch {};
        self.sendPacket(&to) catch {};

        const copy = sourceItem.*;
        sourceItem.* = destItem.*;
        destItem.* = copy;
        _ = self.db.updateAccount(io, &self.account);
    }

    fn sendCharacterList(self: *Peer, opcode: packet.Opcode) void {
        var charList = std.mem.zeroInit(packet.PacketCharList, .{
            .header = packet.Header{
                .index = @intCast(self.userID),
                .operationCode = @intFromEnum(opcode),
                .time = std.time.epoch.unix,
            },
            .gold = self.account.gold,
            .name = self.account.name,
            .characters = packet.PacketCharListData.from(self.account),
        });

        self.sendPacket(&charList) catch |err| {
            logger.err("failed to sent charlist: {s}", .{@errorName(err)});
        };
    }

    fn onDeleteCharacter(self: *Peer, io: Io, request: packet.PacketCharDeleteInput) bool {
        const slot: usize = @intCast(request.slot);

        const char = &self.account.characters[slot];
        if (char.name[0] == 0) {
            return false;
        }

        const password = std.mem.sliceTo(self.account.password[0..], 0);
        const passwordRequest = std.mem.sliceTo(request.password[0..], 0);

        if (!std.mem.eql(u8, password[0..], passwordRequest[0..])) {
            return false;
        }

        // all bytes to zero
        char.* = std.mem.zeroes(Character);
        if (!self.db.updateAccount(io, &self.account)) {
            return false;
        }

        var output = packet.PacketCharDeleteOutput{
            .header = .{
                .index = @intCast(self.userID),
                .operationCode = @intFromEnum(packet.Opcode.CHAR_DELETED),
                .time = 0,
            },
            .characters = .from(self.account),
        };

        self.sendPacket(&output) catch {
            return false;
        };

        const name = std.mem.sliceTo(request.name[0..], 0);
        self.sendTextMessage("{s} was deleted", .{name}) catch {};
        return true;
    }

    fn onCreateCharacter(self: *Peer, io: Io, request: packet.PacketCharCreateInput) bool {
        const slot: usize = @intCast(request.slot);
        var account = &self.account;

        if ((slot < 0 or slot > 4) or account.characters[slot].name[0] != 0) {
            self.sendPulse(.CHAR_CREATE_FAIL) catch {
                return false;
            };
            self.sendTextMessage("try again operation", .{}) catch {
                return false;
            };
            return false;
        }

        var char = &account.characters[slot];

        char.* = Character.fromClass(@enumFromInt(@intFromEnum(request.class)));
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
        char.class = @enumFromInt(@intFromEnum(request.class));

        if (!self.db.updateAccount(io, account)) {
            return false;
        }

        var pack = packet.PacketCharCreateOutput{
            .header = .{
                .index = @intCast(self.userID),
                .operationCode = @intFromEnum(packet.Opcode.CHAR_CREATED),
                .time = std.time.epoch.unix,
            },
            .characters = .from(self.account),
        };

        self.sendPacket(&pack) catch {
            return false;
        };

        self.sendTextMessage("{s} was created", .{request.name}) catch {
            return false;
        };
        return true;
    }
};
