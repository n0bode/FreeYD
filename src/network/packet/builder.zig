const std = @import("std");

const packets = @import("packet.zig").server;
const Opcode = @import("packet.zig").Opcode;
const domain = @import("packet.zig").domains;

const Position = domain.Position;
const Character = domain.Character;
const Mob = domain.Mob;

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
            .operationCode = @intFromEnum(Opcode.CHAR_SPAWNED),
            .index = 0,
            .time = 0,
        },
        .position = @bitCast(position.*),
        .ownerId = ownerId,
        .mob = .from(mob),
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
