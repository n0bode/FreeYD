const std = @import("std");
const binding = @import("../binding.zig");

const State = binding.lua.State;
const network = binding.network;

const Peer = network.Peer;
const builders = network.builders;
const PositionBinding = binding.PositionBinding;
const CharacterBinding = binding.CharacterBinding;
const MobBinding = binding.MobBinding;
const Position = binding.domain.Position;

const responses = network.responses;
const Opcode = network.Opcode;

const CommandFN = *const fn (*Peer, *State) void;

const funcs = std.StaticStringMap(CommandFN).initComptime(&.{
    .{ "spawn_char", charSpawn },
    .{ "spawn_mob", mobSpawn },
    .{ "motion_mob", mobMove },
    .{ "enter_account", enterAccount },
    .{ "password_incorrect", passwordIncorrect },
    .{ "char_created", charCreated },
    .{ "char_create_failed", charCreateFailed },
    .{ "char_deleted", charDeleted },
});

pub fn dispatch(peer: *Peer, command: []const u8, L: *State) bool {
    const fnCommand = funcs.get(command) orelse return false;
    fnCommand(peer, L);
    return true;
}

fn toPosition(L: *State, idx: i32) ?Position {
    if (L.getLuaType(idx) == .Table) {
        L.pushValue(idx);
        L.getField(-1, "x");
        L.checkType(-1, .Number);
        L.getField(-2, "y");
        L.checkType(-1, .Number);
        return .{
            .x = @intCast(L.toInteger(-2)),
            .y = @intCast(L.toInteger(-1)),
        };
    }

    return (PositionBinding.toUserdata(L, idx) orelse {
        return null;
    }).*;
}

fn charSpawn(peer: *Peer, L: *State) void {
    L.checkType(3, .Table);

    L.getField(3, "position");
    var position = toPosition(L, -1) orelse {
        _ = L.throw("spawn_char: 'position' must be a Position or table");
        return;
    };

    L.getField(3, "character");
    const char = CharacterBinding.toUserdata(L, -1) orelse {
        _ = L.throw("spawn_char: 'character' must be a Character instance");
        return;
    };

    var data = builders.buildSpawnChar(
        @intCast(peer.peerId),
        &position,
        char,
    );

    injectOptions(L, &data.header);
    peer.sendPacket(&data) catch {
        _ = L.throw("failed to send packet to peer");
        return;
    };
}

fn mobSpawn(peer: *Peer, L: *State) void {
    L.checkType(3, .Table);

    L.getField(3, "position");
    var pos = toPosition(L, -1) orelse {
        _ = L.throw("mob_spawn: 'position' must be a Position instance or table");
        return;
    };

    L.getField(3, "owner_id");
    const ownerId = L.checkInteger(-1);

    L.getField(3, "mob");
    const mob = MobBinding.toUserdata(L, -1) orelse {
        _ = L.throw("mob_spawn: 'mob' must be a Mob instance");
        return;
    };

    var packet = builders.buildSpawnMob(&pos, @intCast(ownerId), mob);
    injectOptions(L, &packet.header);
    peer.sendPacket(&packet) catch {};
}

fn mobMove(peer: *Peer, L: *State) void {
    L.checkType(3, .Table);

    L.getField(3, "origin");
    var origin = toPosition(L, -1) orelse {
        _ = L.throw("mob_move: 'origin' must be a Position instance");
        return;
    };

    L.getField(3, "kind");
    const kind = L.checkInteger(-1);

    L.getField(3, "speed");
    const speed = L.checkInteger(-1);

    L.getField(3, "destination");
    const dest = PositionBinding.toUserdata(L, -1) orelse {
        _ = L.throw("mob_move: 'destination' must be a Position instance");
        return;
    };

    L.getField(3, "mob_id");
    const mobId = L.checkInteger(-1);

    var packet = builders.buildMotionMob(
        @intCast(mobId),
        &origin,
        dest,
        @intCast(kind),
        @intCast(speed),
    );

    L.getField(3, "routes");
    if (!L.isNil(-1)) {
        const routes: []i8 = @ptrCast(@alignCast(@constCast(L.checkString(-1))));
        const len = @min(packet.route.len, routes.len);
        @memcpy(packet.route[0..len], routes[0..len]);
    }

    injectOptions(L, &packet.header);
    peer.sendPacket(&packet) catch {};
}

fn enterAccount(peer: *Peer, L: *State) void {
    const Respond = network.responses.PacketCharListOutput;
    var packet: Respond = .from(&peer.account, .enterAccount);
    peer.sendPacket(&packet) catch {
        L.pushString("failed to send");
        return;
    };

    if (L.getLuaType(3) == .String) {
        const message = L.toString(3);
        peer.sendTextMessage(message) catch {
            return;
        };
    }

    injectOptions(L, &packet.header);
    peer.sendPacket(&packet) catch {};
}

fn passwordIncorrect(peer: *Peer, L: *State) void {
    if (L.getLuaType(3) == .String) {
        const message = L.toString(3);
        peer.sendTextMessage(message) catch {
            return;
        };
    }

    peer.sendCode(@intFromEnum(Opcode.PIN_FAIL)) catch {
        return;
    };
}

fn charCreated(peer: *Peer, L: *State) void {
    var pack = responses.PacketCharCreateOutput{
        .header = .{
            .operationCode = @intFromEnum(Opcode.CHAR_CREATED),
            .time = std.time.epoch.unix,
        },
        .characters = .from(&peer.account),
    };

    if (L.getLuaType(3) == .String) {
        const message = L.toString(3);
        peer.sendTextMessage(message) catch {
            return;
        };
    }

    peer.sendPacket(&pack) catch {};
}

fn charCreateFailed(peer: *Peer, L: *State) void {
    peer.sendCode(@intFromEnum(Opcode.CHAR_CREATE_FAIL)) catch {};
    if (L.getLuaType(3) == .String) {
        const message = L.toString(3);
        peer.sendTextMessage(message) catch {
            return;
        };
    }
}

fn charDeleted(peer: *Peer, _: *State) void {
    var pack = responses.PacketCharDeleteOutput{
        .header = .{
            .operationCode = @intFromEnum(Opcode.CHAR_DELETED),
        },
        .characters = .from(&peer.account),
    };

    peer.sendPacket(&pack) catch {};
}

fn injectOptions(L: *State, header: *responses.Header) void {
    if (L.getLuaType(4) != .Table) return;

    L.getField(4, "peer_id");
    if (!L.isNil(-1)) header.index = @intCast(L.toInteger(-1));

    L.getField(4, "time");
    if (!L.isNil(-1)) header.time = @intCast(L.toInteger(-1));

    L.getField(4, "opcode");
    if (!L.isNil(-1)) header.operationCode = @intCast(L.toInteger(-1));
}
