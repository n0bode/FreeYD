const root = @import("serverlogic.zig");
const binding = root.bindings;
const lua = root.lua;
const responses = root.network.responses;
const Opcode = root.network.Opcode;
const std = @import("std");

fn parsePositionData(L: *lua.State) !responses.PositionData {
    std.debug.print("{s} \n", .{@tagName(L.getLuaType(-1))});
    const pos = binding.PositionBinding.toUserdata(L, -1) orelse {
        return error.PositionIsNotInstance;
    };
    return responses.PositionData{
        .x = pos.x,
        .y = pos.y,
    };
}

fn parseMobData(L: *lua.State) !responses.MobData {
    const mob = binding.MobBinding.toUserdata(L, -1) orelse {
        return error.MobIsNotInstance;
    };
    return .from(mob);
}

pub fn parseToPacketSpawn(L: *lua.State) !responses.PacketSpawnOutput {
    L.checkType(3, .Table);

    L.getField(3, "position");
    const position = try parsePositionData(L);
    L.pop(1);

    L.getField(3, "mob");
    const mob = try parseMobData(L);
    L.pop(1);

    return .{
        .header = .{ .operationCode = @intFromEnum(Opcode.MOB_CREATE) },
        .position = position,
        .mob = mob,
    };
}
