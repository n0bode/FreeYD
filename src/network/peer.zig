const std = @import("std");
const brain = @import("brain");

const domain = @import("core").domains;
const Server = @import("server.zig").Server;

const Header = @import("packet/packet.zig").Header;
const Opcode = @import("packet/packet.zig").Opcode;
const encode = @import("packet/packet.zig").encode;

const PacketInput = @import("packet/packet.zig").PacketInput;
const packets = @import("packet/packet.zig").server;
const packetsClient = @import("packet/packet.zig").client;

const Account = @import("core").domains.Account;

const Io = std.Io;
const net = Io.net;

const IDatabase = @import("db").Database;

const Stream = net.Stream;

const logger = std.log.scoped(.peer);

const INIT_CODE = 0x1F11F311;

pub const Peer = struct {
    pub const State = enum(u4) {
        Invalid = 0b0000,
        Empty = 0b0001,
        Accepted = 0b0010,
        Logged = 0b0110,
        Playing = 0b1110,
        Disconnected = 0b0100,
    };

    pub const PlayerState = struct {
        positionX: i16 = 0,
        positionY: i16 = 0,
        charSelected: i8 = 0,
    };

    peerId: u32,
    stream: Stream,
    state: State,

    bufferReader: [10 * 1024]u8 = undefined,
    bufferWriter: [10 * 1024]u8 = undefined,

    reader: net.Stream.Reader = undefined,
    writer: net.Stream.Writer = undefined,

    account: Account = undefined,
    playerState: PlayerState = .{},
    server: *Server,

    lastReceiveTime: u64 = 0,
    pub fn init(
        server: *Server,
        peerId: u32,
        stream: Stream,
    ) Peer {
        return .{
            .state = .Accepted,
            .server = server,
            .peerId = peerId,
            .stream = stream,
        };
    }

    pub fn deinit(self: *Peer, io: std.Io) void {
        self.stream.close(io);
    }

    pub fn accept(self: *Peer, io: Io, group: *Io.Group) !void {
        self.reader = self.stream.reader(io, &self.bufferReader);
        const reader = &self.reader.interface;

        self.writer = self.stream.writer(io, &self.bufferWriter);

        const initCode = try reader.takeInt(u32, .little);
        logger.debug("[{d}] initcode => {X}", .{ self.peerId, initCode });
        if (initCode != INIT_CODE) {
            self.state = .Invalid;
            return error.InvalidInitCode;
        }

        group.async(io, Peer.readMessages, .{ self, reader });
    }

    pub fn sendCode(self: *Peer, code: u16) !void {
        var packet = packets.PacketEmpty{
            .header = .{
                .operationCode = code,
                .index = @intCast(self.peerId),
                .time = std.time.epoch.unix,
                .verifier = undefined,
            },
        };
        try self.sendPacket(&packet);
    }

    pub fn sendTextMessage(self: *Peer, text: []const u8) !void {
        var packet = packets.PacketMessageTextOutput{
            .header = .{
                .operationCode = @intFromEnum(Opcode.TEXTMESSAGE),
            },
        };

        const min = @min(packet.text.len, text.len);
        @memcpy(packet.text[0..min], text[0..min]);
        const data = encode(&packet);
        try self.sendRawPacket(data);
    }

    pub fn sendRawPacket(self: *Peer, data: []u8) !void {
        var writer = &self.writer.interface;
        try writer.writeAll(data);
        try writer.flush();
    }

    pub fn getTime(self: *Peer) i64 {
        return self.server.getServerTime();
    }

    pub fn sendPacket(self: *Peer, message: anytype) !void {
        if (@typeInfo(@TypeOf(message)) != .pointer) {
            @compileError("message must be a pointer");
        }

        if (message.header.time == 0)
            message.header.time = @as(u32, @intCast(self.getTime()));

        if (message.header.index == 0)
            message.header.index = @intCast(self.peerId);

        const encoded = encode(message);
        try self.sendRawPacket(encoded);
    }

    pub fn changeState(self: *Peer, state: State) void {
        self.server.onPeerChangeState(self, state);
        self.state = state;
    }

    pub fn disconnect(self: *Peer) void {
        self.changeState(.Disconnected);
    }

    pub fn setAccount(self: *Peer, account: Account) void {
        self.account = account;
        self.changeState(.Logged);
    }

    fn readMessages(self: *Peer, reader: *Io.Reader) void {
        const peerId = self.peerId;
        //defer self.stream.socket.close(self.io);

        // first message has a initCode,
        while (@intFromEnum(self.state) & 0b10 > 0) {
            const sizeBytes = reader.peekArray(2) catch |err| {
                logger.warn("failed to get size {s}", .{@errorName(err)});
                self.changeState(.Disconnected);
                return;
            };

            const size: u16 = @bitCast(sizeBytes[0..2].*);
            logger.debug("[{d}] waiting message size={d}", .{ peerId, size });
            const data = reader.take(@intCast(size)) catch |err| {
                logger.warn("failed to get message {s}", .{@errorName(err)});
                self.changeState(.Disconnected);
                return;
            };

            var packetDecoded = PacketInput.decode(data) catch |err| {
                logger.err("[{d}] failed to accept message: {s}", .{ peerId, @errorName(err) });
                self.sendTextMessage("client is invalid") catch {};
                self.changeState(.Disconnected);
                continue;
            };

            logger.info("({X}) OPCODE: {X} FROM {X} AT {d}", .{
                self.peerId,
                packetDecoded.header.operationCode,
                packetDecoded.header.index,
                packetDecoded.header.time,
            });

            self.lastReceiveTime = @intCast(self.getTime());
            if (!self.server.callPeerReceivePacket(self, &packetDecoded)) {
                logger.info("peer disconnected by packet execution failed", .{});
                self.changeState(.Disconnected);
            }
        }
    }

    // fn onAction(self: *Peer, req: packets.PacketActionInput) void {
    //     var request = req;

    //     logger.info("pos({any}) to ({any})", .{ req.position, req.destination });
    //     request.header.time = @intCast(self.lastReceiveTime);
    //     request.header.operationCode = 0x369;
    //     request.position = req.position;
    //     request.header.index = @intCast(self.userID);
    //     request.command = [_]u8{0} ** 24;
    //     request.kind = 0;
    //     request.speed = req.speed * 10;

    //     self.sendPacket(&request) catch {};
    // }

    // fn onEnterWorld(self: *Peer, io: Io, req: packets.PacketEnterWorldInput) void {
    //     const slot: usize = @intCast(req.charSlot);
    //     if (slot > 4) {
    //         self.sendTextMessage("try again", .{}) catch {};
    //         return;
    //     }

    //     logger.info("ID: {d}", .{req.header.index});
    //     const char = &self.account.characters[slot];
    //     if (char.name[0] == 0) {
    //         self.sendTextMessage("character is invalid", .{}) catch {};
    //         return;
    //     }

    //     self.account.charSelected = @intCast(req.charSlot);
    //     self.playerState.charSelected = @intCast(req.charSlot);
    //     self.playerState.positionX = char.positionX;
    //     self.playerState.positionY = char.positionY;

    //     if (!self.db.updateAccount(io, &self.account)) {
    //         return;
    //     }

    //     char.positionX = 2112;
    //     char.positionY = 2042;

    //     var output = packets.PacketEnterWorldOutput{
    //         .header = .{
    //             .index = 0x7530,
    //             .operationCode = @intFromEnum(packets.Opcode.ENTERED_WORLD),
    //             .time = 0,
    //         },
    //         .position = .{ .x = char.positionX, .y = char.positionY },
    //         .character = .from(@intCast(self.userID), char),
    //     };

    //     self.sendPacket(&output) catch {
    //         return;
    //     };

    //     var trenier = std.mem.zeroInit(packets.PacketSpawnOutput, .{
    //         .header = .{
    //             .operationCode = 0x364,
    //             .index = 0x7530,
    //         },
    //         .position = .{ .x = char.positionX, .y = char.positionY },
    //         .mob = .{
    //             .entityId = @as(u16, @intCast(self.userID)),
    //             .stats = packets.CharStatsData.from(char.stats),
    //         },
    //     });

    //     @memcpy(trenier.mob.name[0..], char.name[0..12]);

    //     inline for (0..16) |id| {
    //         trenier.mob.items[id] = char.equipments[id].itemID;
    //     }

    //     self.sendPacket(&trenier) catch {};
    //     return;
    // }

    fn onLogin(self: *Peer, _: Io, _: packetsClient.PacketLoginInput) bool {
        if (self.state != .Accepted) {
            return false;
        }

        // const username = std.mem.sliceTo(&login.username, 0);
        // const password = std.mem.sliceTo(&login.password, 0);

        // if (!self.db.login(io, username, password, &self.account)) {
        //     if (!self.db.signup(io, username, password, &self.account)) {
        //         logger.debug("username({s}) not found", .{username});
        //         return false;
        //     }
        // }

        return false;
    }

    // fn onMoveItem(self: *Peer, io: Io, req: packets.PacketMoveItemInput) void {
    //     self.swapItem(
    //         io,
    //         req.sourceSlot,
    //         req.sourceStorage,
    //         req.destSlot,
    //         req.destStorage,
    //     );
    // }

    // fn getItem(self: *Peer, slot: u8, storage: packets.StorageType) ?*domain.Item {
    //     const char = &self.account.characters[@intCast(self.playerState.charSelected)];
    //     return switch (storage) {
    //         .equip => &char.equipments[slot],
    //         .inventory => &char.carry[slot],
    //         .cargo => return &self.account.cargo[slot],
    //     };
    // }

    // fn swapItem(
    //     self: *Peer,
    //     io: Io,
    //     sourceSlot: u8,
    //     sourceStorage: packets.StorageType,
    //     destSlot: u8,
    //     destStorage: packets.StorageType,
    // ) void {
    //     const sourceItem = self.getItem(sourceSlot, sourceStorage) orelse return;
    //     const destItem = self.getItem(destSlot, destStorage) orelse return;

    //     var from = packets.PacketCreateItemOutput{
    //         .header = .{
    //             .operationCode = @intFromEnum(packets.Opcode.CREATE_ITEM),
    //             .index = @intCast(self.userID),
    //             .time = std.time.epoch.unix,
    //         },
    //         .slot = sourceSlot,
    //         .slotType = @intCast(@intFromEnum(sourceStorage)),
    //         .item = .{ .index = destItem.itemID, .effects = destItem.effect },
    //     };

    //     var to = packets.PacketCreateItemOutput{
    //         .header = from.header,
    //         .slot = destSlot,
    //         .slotType = @intCast(@intFromEnum(destStorage)),
    //         .item = .{ .index = sourceItem.itemID, .effects = sourceItem.effect },
    //     };

    //     self.sendPacket(&from) catch {};
    //     self.sendPacket(&to) catch {};

    //     const copy = sourceItem.*;
    //     sourceItem.* = destItem.*;
    //     destItem.* = copy;
    //     _ = self.db.updateAccount(io, &self.account);
    // }

    // fn sendCharacterList(self: *Peer, opcode: packets.Opcode) void {
    //     var charList = std.mem.zeroInit(packets.PacketCharList, .{
    //         .header = packets.Header{
    //             .index = @intCast(self.userID),
    //             .operationCode = @intFromEnum(opcode),
    //             .time = std.time.epoch.unix,
    //         },
    //         .gold = self.account.gold,
    //         .name = self.account.name,
    //         .characters = packets.PacketCharListData.from(self.account),
    //     });

    //     self.sendPacket(&charList) catch |err| {
    //         logger.err("failed to sent charlist: {s}", .{@errorName(err)});
    //     };
    // }

    // fn onDeleteCharacter(self: *Peer, io: Io, request: packets.PacketCharDeleteInput) bool {
    //     const slot: usize = @intCast(request.slot);

    //     const char = &self.account.characters[slot];
    //     if (char.name[0] == 0) {
    //         return false;
    //     }

    //     const password = std.mem.sliceTo(self.account.password[0..], 0);
    //     const passwordRequest = std.mem.sliceTo(request.password[0..], 0);

    //     if (!std.mem.eql(u8, password[0..], passwordRequest[0..])) {
    //         return false;
    //     }

    //     // all bytes to zero
    //     char.* = std.mem.zeroes(Character);
    //     if (!self.db.updateAccount(io, &self.account)) {
    //         return false;
    //     }

    //     var output = packets.PacketCharDeleteOutput{
    //         .header = .{
    //             .index = @intCast(self.userID),
    //             .operationCode = @intFromEnum(packets.Opcode.CHAR_DELETED),
    //             .time = 0,
    //         },
    //         .characters = .from(self.account),
    //     };

    //     self.sendPacket(&output) catch {
    //         return false;
    //     };

    //     const name = std.mem.sliceTo(request.name[0..], 0);
    //     self.sendTextMessage("{s} was deleted", .{name}) catch {};
    //     return true;
    // }

    // fn onCreateCharacter(self: *Peer, io: Io, request: packets.PacketCharCreateInput) bool {
    //     const slot: usize = @intCast(request.slot);
    //     var account = &self.account;

    //     if ((slot < 0 or slot > 4) or account.characters[slot].name[0] != 0) {
    //         self.sendPulse(.CHAR_CREATE_FAIL) catch {
    //             return false;
    //         };
    //         self.sendTextMessage("try again operation", .{}) catch {
    //             return false;
    //         };
    //         return false;
    //     }

    //     var char = &account.characters[slot];

    //     char.* = Character.fromClass(@enumFromInt(@intFromEnum(request.class)));
    //     const name = std.mem.sliceTo(request.name[0..], 0);

    //     if (std.mem.eql(u8, name, "GM")) {
    //         self.sendPulse(.CHAR_CREATE_FAIL) catch {
    //             return false;
    //         };
    //         return false;
    //     }

    //     @memcpy(char.name[0..name.len], name[0..]);

    //     char.positionX = 2112;
    //     char.positionY = 2112;
    //     char.class = @enumFromInt(@intFromEnum(request.class));

    //     if (!self.db.updateAccount(io, account)) {
    //         return false;
    //     }

    //     var pack = packets.PacketCharCreateOutput{
    //         .header = .{
    //             .index = @intCast(self.userID),
    //             .operationCode = @intFromEnum(packets.Opcode.CHAR_CREATED),
    //             .time = std.time.epoch.unix,
    //         },
    //         .characters = .from(self.account),
    //     };

    //     self.sendPacket(&pack) catch {
    //         return false;
    //     };

    //     self.sendTextMessage("{s} was created", .{request.name}) catch {
    //         return false;
    //     };
    //     return true;
    // }
};
