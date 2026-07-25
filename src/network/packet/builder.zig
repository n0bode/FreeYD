const std = @import("std");

const packets = @import("packet.zig").server;
const Opcode = @import("packet.zig").Opcode;
const domain = @import("packet.zig").domains;

const Position = domain.Position;
const Character = domain.Character;
const Mob = domain.Mob;
const Item = domain.Item;

pub const builders = @This();

pub fn buildSpawnChar(
    peerId: u16,
    position: *Position,
    char: *Character,
) packets.PacketCharSpawnOutput {
    return packets.PacketCharSpawnOutput{
        .header = .{
            .operationCode = @intFromEnum(Opcode.CHAR_SPAWNED),
            .index = 0,
            .time = 0,
        },
        .position = @bitCast(position.*),
        .character = .from(peerId, char),
    };
}

pub fn buildSpawnMob(
    position: *Position,
    ownerId: u16,
    mob: *Mob,
) packets.PacketSpawnOutput {
    return packets.PacketSpawnOutput{
        .header = .{
            .operationCode = @intFromEnum(Opcode.MOB_CREATE),
            .index = 0,
            .time = 0,
        },
        .position = @bitCast(position.*),
        .ownerId = ownerId,
        .mob = .from(mob),
    };
}

pub fn buildDeleteMob(
    mobId: u16,
) packets.PacketEmpty {
    return packets.PacketEmpty{
        .header = .{
            .operationCode = @intFromEnum(Opcode.MOB_DELETE),
            .index = mobId,
            .time = 0,
        },
    };
}

pub fn buildMotionMob(
    mobId: u16,
    origin: *Position,
    destination: *Position,
    kind: u8,
    speed: u8,
) packets.PacketMobMoveOutput {
    return packets.PacketMobMoveOutput{
        .header = .{
            .operationCode = @intFromEnum(Opcode.MOB_MOTION),
            .index = @intCast(mobId),
        },
        .origin = .{ .x = origin.x, .y = origin.y },
        .kind = @intCast(kind),
        .speed = @intCast(speed),
        .destination = .{ .x = destination.x, .y = destination.y },
    };
}

pub fn buildItemMove(
    peerId: u16,
    storage: u16,
    slot: u16,
    item: Item,
) packets.PacketItemCreateOutput {
    return packets.PacketItemCreateOutput{
        .header = .{
            .operationCode = @intFromEnum(Opcode.ITEM_MOVED),
            .index = peerId,
        },
        .storage = storage,
        .slot = slot,
        .item = @bitCast(item),
    };
}

pub fn buildUpdateEquipment(
    mob: *Mob,
) packets.PacketUpdateEquipmentOutput {
    return packets.PacketUpdateEquipmentOutput{
        .header = .{
            .operationCode = @intFromEnum(Opcode.UPDATE_EQUIPMENTS),
            .index = mob.mobId,
        },
        .equipments = @bitCast(mob.equipments),
        .anctCode = mob.anctCode,
    };
}

pub fn buildChatMessage(
    mobId: u16,
    message: []const u8,
    _: u8,
) packets.PacketMessageTextOutput {
    var self = packets.PacketMessageTextOutput{
        .header = .{
            .operationCode = @intFromEnum(Opcode.MSG_CHAT),
            .index = mobId,
        },
    };
    const len = @min(self.text.len, message.len);
    @memcpy(self.text[0..len], message[0..len]);
    return self;
}

pub fn buildItemDrop(
    mobId: u16,
    storage: u32,
    slot: u32,
    position: Position,
    rotation: Position,
    itemId: u16,
) packets.PacketDropItemOutput {
    return packets.PacketDropItemOutput{
        .header = .{
            .operationCode = @intFromEnum(Opcode.DROP_ITEM),
            .index = mobId,
        },
        .itemID = itemId,
        .position = @bitCast(position),
        .rotation = @bitCast(rotation),
        .slot = slot,
        .sourceType = storage,
    };
}
