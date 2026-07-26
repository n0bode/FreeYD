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
    .{ "delete_mob", mobDelete },
    .{ "move_item", itemMove },
    .{ "update_equipments", updateEquipment },
    .{ "chat_message", chatMessage },
    .{ "drop_item", dropItem },
    .{ "create_item", createItem },
});

pub fn dispatch(peer: *Peer, command: []const u8, L: *State) bool {
    const fnCommand = funcs.get(command) orelse return false;
    fnCommand(peer, L);
    return true;
}

fn charSpawn(peer: *Peer, L: *State) void {
    L.checkType(3, .Table);

    L.getField(3, "position");
    var position = PositionBinding.toUserdata(L, -1) orelse {
        _ = L.throw("spawn_char: 'position' must be a Position or table");
        return;
    };
    L.pop(1);

    L.getField(3, "character");
    const char = CharacterBinding.toUserdata(L, -1) orelse {
        _ = L.throw("spawn_char: 'character' must be a Character instance");
        return;
    };
    L.pop(1);

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
    var pos = PositionBinding.toUserdata(L, -1) orelse {
        _ = L.throw("mob_spawn: 'position' must be a Position instance or table");
        return;
    };
    L.pop(1);

    L.getField(3, "owner_id");
    const ownerId = L.checkInteger(u16, -1);
    L.pop(1);

    L.getField(3, "mob");
    const mob = MobBinding.toUserdata(L, -1) orelse {
        _ = L.throw("mob_spawn: 'mob' must be a Mob instance");
        return;
    };
    L.pop(1);

    var packet = builders.buildSpawnMob(&pos, ownerId, mob);
    injectOptions(L, &packet.header);
    peer.sendPacket(&packet) catch {};
}

fn mobMove(peer: *Peer, L: *State) void {
    L.checkType(3, .Table);

    L.getField(3, "origin");
    var origin = PositionBinding.toUserdata(L, -1) orelse {
        _ = L.throw("mob_move: 'origin' must be a Position instance");
        return;
    };
    L.pop(1);

    L.getField(3, "kind");
    const kind = L.checkInteger(u8, -1);
    L.pop(1);

    L.getField(3, "speed");
    const speed = L.checkInteger(u8, -1);
    L.pop(1);

    L.getField(3, "destination");
    var dest = PositionBinding.toUserdata(L, -1) orelse {
        _ = L.throw("mob_move: 'destination' must be a Position instance");
        return;
    };

    L.getField(3, "mob_id");
    const mobId = L.checkInteger(u16, -1);
    L.pop(1);

    var packet = builders.buildMotionMob(
        mobId,
        &origin,
        &dest,
        kind,
        speed,
    );

    L.getField(3, "routes");
    if (!L.isNil(-1)) {
        const routes: []i8 = @ptrCast(@alignCast(@constCast(L.checkString(-1))));
        const len = @min(packet.route.len, routes.len);
        @memcpy(packet.route[0..len], routes[0..len]);
    }
    L.pop(1);

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

fn mobDelete(peer: *Peer, L: *State) void {
    L.checkType(3, .Table);
    L.getField(3, "mob_id");
    const mobId = L.checkInteger(u16, -1);
    L.pop(1);
    var pack = builders.buildDeleteMob(mobId);

    peer.sendPacket(&pack) catch {};
}

fn itemMove(peer: *Peer, L: *State) void {
    L.checkType(3, .Table);

    L.getField(3, "storage");
    const storage = L.checkInteger(u8, -1);
    L.pop(1);

    L.getField(3, "slot");
    const slot = L.checkInteger(u8, -1);
    L.pop(1);

    L.getField(3, "mob_id");
    const mobId = L.checkInteger(u16, -1);
    L.pop(1);

    L.getField(3, "item");
    const item = binding.ItemBinding.toUserdata(L, -1) orelse {
        _ = L.throw("item_move: 'item' must be an Item instance");
        return;
    };
    L.pop(1);

    var pack = builders.buildItemMove(mobId, storage, slot, item.*);
    peer.sendPacket(&pack) catch {};
}

fn updateEquipment(peer: *Peer, L: *State) void {
    L.checkType(3, .Table);

    L.getField(3, "mob");
    const mob = binding.MobBinding.toUserdata(L, -1) orelse {
        _ = L.throw("update_equipment: 'mob' must be a Mob instance");
        return;
    };
    L.pop(1);

    var pack = builders.buildUpdateEquipment(mob);
    peer.sendPacket(&pack) catch {};
}

fn chatMessage(peer: *Peer, L: *State) void {
    L.checkType(3, .Table);

    L.getField(3, "mob_id");
    const mobId = L.checkInteger(u16, -1);
    L.pop(1);

    L.getField(3, "message");
    const message = L.checkString(-1);
    L.pop(1);

    L.getField(3, "type");
    const msgType = L.checkInteger(u8, -1);
    L.pop(1);

    var pack = builders.buildChatMessage(mobId, message, msgType);
    peer.sendPacket(&pack) catch {};
}

fn dropItem(peer: *Peer, L: *State) void {
    L.checkType(3, .Table);

    L.getField(3, "slot");
    const slot = L.checkInteger(u16, -1);
    L.pop(1);

    L.getField(3, "storage");
    const storage = L.checkInteger(u16, -1);
    L.pop(1);

    L.getField(3, "position");
    const position = binding.PositionBinding.toUserdata(L, -1) orelse {
        _ = L.throw("drop_item: 'position' must be a Position instance");
        return;
    };
    L.pop(1);

    L.getField(3, "rotation");
    const rotation = binding.PositionBinding.toUserdata(L, -1) orelse {
        _ = L.throw("drop_item: 'position' must be a Position instance");
        return;
    };
    L.pop(1);

    L.getField(3, "item_id");
    const itemId = L.checkInteger(u16, -1);
    L.pop(1);

    L.getField(3, "mob_id");
    const mobId = L.checkInteger(u16, -1);
    L.pop(1);

    var pack = builders.buildItemDrop(mobId, storage, slot, position, rotation, itemId);
    peer.sendPacket(&pack) catch {};
}

fn createItem(peer: *Peer, L: *State) void {
    L.checkType(3, .Table);

    L.getField(3, "position");
    const position = PositionBinding.toUserdata(L, -1) orelse {
        _ = L.throw("create_item: 'position' must be a Position instance");
        return;
    };
    L.pop(1);

    L.getField(3, "item_id");
    const itemId = L.checkInteger(u16, -1);
    L.pop(1);

    L.getField(3, "item");
    const item = binding.ItemBinding.toUserdata(L, -1) orelse {
        _ = L.throw("create_item: 'item' must be an Item instance");
        return;
    };
    L.pop(1);

    L.getField(3, "rotate");
    const rotate = L.checkInteger(u8, -1);
    L.pop(1);

    L.getField(3, "state");
    const state = L.checkInteger(u8, -1);
    L.pop(1);

    L.getField(3, "height");
    const height = L.checkInteger(u8, -1);
    L.pop(1);

    L.getField(3, "create");
    const create = L.checkInteger(u8, -1);
    L.pop(1);

    var pack = builders.buildItemCreate(position, itemId, item.*, rotate, state, height, create);
    injectOptions(L, &pack.header);
    peer.sendPacket(&pack) catch {};
}

fn injectOptions(L: *State, header: *responses.Header) void {
    if (L.getLuaType(4) != .Table) return;

    L.getField(4, "peer_id");
    if (!L.isNil(-1)) header.index = L.toInteger(u16, -1);

    L.getField(4, "time");
    if (!L.isNil(-1)) header.time = L.toInteger(u32, -1);

    L.getField(4, "opcode");
    if (!L.isNil(-1)) header.operationCode = L.toInteger(u16, -1);
}
