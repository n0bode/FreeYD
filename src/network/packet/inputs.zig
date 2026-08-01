const std = @import("std");
const Header = @import("packet.zig").Header;
const Opcode = @import("packet.zig").Opcode;
const crypto = @import("crypto.zig");
const logger = std.log.scoped(.packet);

pub const PacketData = union(OpcodeFromClient) {
    unknown,
    ping,
    login: PacketLoginInput,
    pinPassword: PacketPinPasswordInput,
    createChar: PacketCharCreateInput,
    deleteChar: PacketCharDeleteInput,
    spawnChar: PacketEnterWorldInput,
    motionMob: PacketMotionInput,
    moveItem: PacketMoveItemInput,
    updateAttribute: PacketUpdateAttribute,
    chatWhisper: PacketChatWhisperInput,
    chatMessage: PacketChatMessageInput,
    teleport: PacketTeleportInput,
    interactionMob: PacketMobInteractInput,
    dropItem: PacketDropItemInput,
    interactGroundItem: PacketGroundItemInteractInput,
    //attack: PacketAttackInput,
    attackOne: PacketAttackOneInput,
    attackTwo: PacketAttackTwoInput,
};

// This a Packet abstract union received from Client
pub const PacketInput = struct {
    header: Header,
    data: PacketData,

    pub fn decode(bMessage: []u8) !PacketInput {
        const header = crypto.descrypt(bMessage) catch {
            return error.DescryptInvalid;
        };

        const opcode: OpcodeFromClient = .parse(header.operationCode);
        inline for (std.meta.fields(PacketData)) |field| {
            if (opcode == @field(PacketData, field.name)) {
                if (field.type == void) {
                    return .{
                        .header = header,
                        .data = @unionInit(PacketData, field.name, {}),
                    };
                }

                var packet = std.mem.zeroes(field.type);
                parsePacket(field.type, &packet, bMessage) catch |err| {
                    logger.err("parsePacket {X}: {s}", .{ header.operationCode, @errorName(err) });
                    return err;
                };
                return .{
                    .header = header,
                    .data = @unionInit(PacketData, field.name, packet),
                };
            }
        }

        return .{
            .header = header,
            .data = .unknown,
        };
    }
};

fn parsePacket(comptime T: anytype, ptr: *T, bMessage: []u8) !void {
    const start = @sizeOf(Header);
    const header: Header = @bitCast(bMessage[0..start].*);
    //const expectSize = start + @sizeOf(T);

    //if (expectSize > header.verifier.size) {
    //    logger.err("packet size mismatch, expected {d}, got {d}", .{ expectSize - start, header.verifier.size - start });
    //    return error.PacketTooShort;
    //}

    const end = @min(start + @sizeOf(T), header.verifier.size);
    const len = end - start;

    logger.info("len = {d}; end = {d}", .{ len, end });
    // just hea
    if (start > end) return;
    const buffer = std.mem.asBytes(ptr);
    @memcpy(buffer[0..len], bMessage[start..(start + len)]);
}

pub const OpcodeFromClient = enum(u16) {
    unknown,
    ping = @intFromEnum(Opcode.PING),
    login = @intFromEnum(Opcode.LOGIN),
    pinPassword = @intFromEnum(Opcode.PIN),
    createChar = @intFromEnum(Opcode.CHAR_CREATE),
    deleteChar = @intFromEnum(Opcode.CHAR_DELETE),
    spawnChar = @intFromEnum(Opcode.CHAR_SPAWN),
    motionMob = @intFromEnum(Opcode.MOB_MOTION),
    moveItem = @intFromEnum(Opcode.ITEM_MOVE),
    updateAttribute = @intFromEnum(Opcode.SET_ATTRIBUTE),
    chatWhisper = @intFromEnum(Opcode.MSG_WHISPER),
    chatMessage = @intFromEnum(Opcode.MSG_CHAT),
    teleport = @intFromEnum(Opcode.TELEPORT),
    interactionMob = @intFromEnum(Opcode.MOB_INTERACT),
    dropItem = @intFromEnum(Opcode.DROP_ITEM),
    interactGroundItem = @intFromEnum(Opcode.INTERACT_GROUND_ITEM),
    //attack = @intFromEnum(Opcode.ON_ATTACK),
    attackOne = @intFromEnum(Opcode.ON_ATTACK_ONE),
    attackTwo = @intFromEnum(Opcode.ON_ATTACK_TWO),

    // parse a u16 code to a struct union with correct data
    pub fn parse(code: u16) OpcodeFromClient {
        inline for (std.enums.values(OpcodeFromClient)) |value| {
            if (@intFromEnum(value) == code) {
                return value;
            }
        }
        return .unknown;
    }
};

pub const StorageType = enum(u8) {
    EQUIPMENT = 0,
    INVENTORY = 1,
    WAREHOUSE = 2,
};

pub const PacketMoveItemInput = extern struct {
    destStorage: StorageType,
    destSlot: u8,
    sourceStorage: StorageType,
    sourceSlot: u8,
    _0: u32 = 0,
};

pub const PacketCharCreateInput = extern struct {
    slot: i32,
    name: [16]u8,
    class: u8,
};

pub const PacketEnterWorldInput = extern struct {
    charSlot: i32,
    _dunno: [18]u8 = [_]u8{0} ** 18,
};

pub const PacketPinPasswordInput = extern struct {
    numeric: [6]u8,
    unk: [14]u8,
};

pub const PositionData = extern struct {
    x: i16,
    y: i16,
};

pub const PacketMotionInput = extern struct {
    origin: PositionData,
    speed: i32,
    kind: i32,
    destination: PositionData,
    routes: [22]u8,
};

pub const PacketLoginInput = extern struct {
    username: [16]u8,
    password: [12]u8,
    version: i32,
    none: i32,
    keys: [16]u8,
    ipAddress: [16]u8,
    // need complete 92 bytes
    unks: [36]u8,
};

pub const PacketTeleportInput = extern struct {
    data: [4]u8,
};

pub const PacketChatMessageInput = extern struct {
    message: [96]u8,
};

pub const PacketCharDeleteInput = extern struct {
    slot: i32,
    name: [16]u8,
    password: [12]u8,
};

pub const PacketDropItemInput = extern struct {
    storage: i32,
    slot: i32,
    rotation: PositionData,
    position: PositionData,
    itemID: u16,
};

pub const SectionAttribute = enum(u16) {
    ATTRIBUTES = 0,
    SKILL = 1,
    UNK = 2,
};

pub const PacketUpdateAttribute = extern struct {
    section: SectionAttribute,
    index: u16,
    peerId: u16,
};

pub const PacketChatWhisperInput = extern struct {
    name: [16]u8,
    message: [100]u8,
};

pub const PacketMobInteractInput = extern struct {
    mobId: u16,
    action: u16,
};

pub const PacketGroundItemInteractInput = extern struct {
    itemId: u32,
    state: u32,
};

pub const AttackDamage = extern struct {
    targetId: u16,
    damage: i16,
};

pub const PacketAttackInput = buildAttack(13);
pub const PacketAttackOneInput = buildAttack(1);
pub const PacketAttackTwoInput = buildAttack(2);

fn buildAttack(comptime size: usize) type {
    return extern struct {
        attackerId: u16,
        currentHp: u16,
        attackerPosition: PositionData,
        targetPosition: PositionData,
        skillIndex: i16,
        currentMp: i16,
        motion: u8,
        skillParm: u8,
        flagLocal: u8,
        doubleCritical: u8,
        hold: i32,
        currentExp: i32,
        requiredMp: i16,
        rsv: u16,
        dam: [size]AttackDamage,
    };
}

const t = std.testing;
test "PacketFromClient.decode - it should success" {
    const data = "dAANQgXzvP35GfT9b2RZb2hSYWLy8fT5wvQY/SpQZ3CTU2ph8uQMAOjzAPz1/YT9Gv+k/Rjq6P2vPuT7qFFEcPjyRPyu8XT9NvEM/GbxPP368fQA6uX0+vTq9Pv48Rj/IOWU/UbxYP368fT9+urc/fLxzP0=";
    var buffer: [116]u8 = undefined;

    const decoder = std.base64.standard.Decoder;
    try decoder.decode(buffer[0..], data);

    const _packet = try PacketInput.decode(buffer[0..]);
    switch (_packet.data) {
        else => try t.expect(false),
        .login => |*login| {
            try t.expectEqual(754, login.version);
            try t.expectEqual(@intFromEnum(Opcode.LOGIN), _packet.header.operationCode);
            try t.expectEqualStrings("username", login.username[0..8]);
            try t.expectEqualStrings("password", login.password[0..8]);
        },
    }
}
