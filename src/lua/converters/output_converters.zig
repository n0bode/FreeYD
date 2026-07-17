const std = @import("std");

const bindings = @import("lua_binding");
const lua = @import("lua");
const network = @import("network");

const responses = network.responses;
const Opcode = network.Opcode;

fn toPosition(L: *lua.State, idx: i32) !responses.PositionData {
    const pos = bindings.PositionBinding.toUserdata(L, idx) orelse {
        return error.PositionIsNotInstance;
    };
    return responses.PositionData{
        .x = pos.x,
        .y = pos.y,
    };
}

fn toMobData(L: *lua.State, idx: i32) !responses.MobData {
    const mob = bindings.MobBinding.toUserdata(L, idx) orelse {
        return error.MobIsNotInstance;
    };
    return .from(mob);
}

/// Injeta campos opcionais do 4º argumento Lua (tabela de opções) no header.
fn injectOptions(L: *lua.State, idx: i32, header: *responses.Header) void {
    if (L.getLuaType(idx) != .Table) {
        return;
    }

    L.getField(idx, "peer_id");
    if (!L.isNil(-1)) {
        header.index = @intCast(L.toInteger(-1));
    }

    L.getField(idx, "time");
    if (!L.isNil(-1)) {
        header.time = @intCast(L.toInteger(-1));
    }

    L.getField(idx, "opcode");
    if (!L.isNil(-1)) {
        header.operationCode = @intCast(L.toInteger(-1));
    }
}

pub fn toPacketMobSpawn(L: *lua.State, idx: i32) !responses.PacketSpawnOutput {
    L.checkType(idx, .Table);

    L.getField(idx, "position");
    const position = try toPosition(L, -1);

    L.getField(idx, "owner_id");
    const ownerId = L.checkInteger(-1);

    L.getField(idx, "mob");
    const mob = try toMobData(L, -1);

    var self = responses.PacketSpawnOutput{
        .header = .{ .operationCode = @intFromEnum(Opcode.MOB_CREATE) },
        .position = position,
        .ownerId = @intCast(ownerId),
        .mob = mob,
    };
    injectOptions(L, &self.header);
    return self;
}

pub fn toPacketMobMove(L: *lua.State, idx: i32) !responses.PacketMobMoveOutput {
    L.checkType(idx, .Table);

    L.getField(idx, "origin");
    const origin = try toPosition(L, -1);

    L.getField(idx, "kind");
    const kind = L.checkInteger(-1);

    L.getField(idx, "speed");
    const speed = L.checkInteger(-1);

    L.getField(idx, "destination");
    const destination = try toPosition(L, -1);

    L.getField(idx, "mob_id");
    const mob = L.checkInteger(-1);

    var packet = responses.PacketMobMoveOutput{
        .header = .{
            .operationCode = @intFromEnum(Opcode.ACTION),
            .index = @intCast(mob),
        },
        .origin = origin,
        .kind = @intCast(kind),
        .speed = @intCast(speed),
        .destination = destination,
    };

    L.getField(idx, "routes");
    if (!L.isNil(-1)) {
        const routes: []i8 = @ptrCast(@alignCast(@constCast(L.checkString(-1))));
        const len = @min(packet.route.len, routes.len);
        @memcpy(packet.route[0..len], routes[0..len]);
    }

    injectOptions(L, &packet.header);
    return packet;
}
