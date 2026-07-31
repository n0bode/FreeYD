const std = @import("std");

const serverlogic = @import("../serverlogic.zig");
const lua = serverlogic.lua;
const bindings = serverlogic.bindings;

const network = serverlogic.network;
const ServerLogic = serverlogic.ServerLogic;
const DatabaseBinding = bindings.DatabaseBinding;
const ItemBinding = bindings.ItemBinding;
const PeerBinding = bindings.PeerBinding;
const PositionBinding = bindings.PositionBinding;
const responses = network.responses;

const Database = serverlogic.Database;

const core = serverlogic.core;
const Account = core.domains.Account;
const Character = core.domains.Character;
const Item = core.domains.Item;

const State = lua.State;
const Reg = lua.Reg;

pub const ServerBinding = @This();

pub fn bind(logic: *ServerLogic) void {
    const L = logic.state;
    _ = L.newLib("server", &.{
        .{
            .name = "on",
            .value = .{
                .func = .{
                    .func = lua_on_bind,
                    .userdata = logic,
                },
            },
        },
        .{
            .name = "get_database",
            .value = .{
                .func = .{
                    .func = lua_get_database,
                    .userdata = logic,
                },
            },
        },
        .{
            .name = "get_time",
            .value = .{
                .func = .{
                    .func = lua_get_time,
                    .userdata = logic,
                },
            },
        },
        .{
            .name = "get_local_date",
            .value = .{
                .func = .{
                    .func = lua_get_local_date,
                    .userdata = logic,
                },
            },
        },
        .{
            .name = "multicast",
            .value = .{
                .func = .{
                    .func = lua_multicast,
                    .userdata = logic,
                },
            },
        },
        .{
            .name = "get_world",
            .value = .{
                .func = .{
                    .func = lua_get_world,
                    .userdata = logic,
                },
            },
        },
        .{
            .name = "get_peer",
            .value = .{
                .func = .{
                    .func = lua_get_peer,
                    .userdata = logic,
                },
            },
        },
        .{
            .name = "create_npc",
            .value = .{
                .func = .{
                    .func = lua_create_npc,
                    .userdata = logic,
                },
            },
        },
        .{
            .name = "spawn_player",
            .value = .{
                .func = .{
                    .func = lua__spawn_player,
                    .userdata = logic,
                },
            },
        },
        .{
            .name = "spawn_item",
            .value = .{
                .func = .{
                    .func = lua__spawn_item,
                    .userdata = logic,
                },
            },
        },
    });
    setGlobals(L, logic);
}

fn setGlobals(L: *State, logic: *ServerLogic) void {
    L.pushInteger(@intCast(logic.maxPlayers));
    L.setGlobal("MAX_PLAYERS");

    L.pushFunction(lua__is_player);
    L.setGlobal("is_player");
}

fn lua__is_player(L: *State) i32 {
    L.getGlobal("MAX_PLAYERS");
    const maxPlayers = L.toInteger(u32, -1);
    L.pop(1);

    const peerId = L.checkInteger(i32, 1);
    L.pushBool(peerId > 0 and peerId < maxPlayers);
    return 1;
}

fn lua_on_bind(L: *State) i32 {
    const self: *ServerLogic = L.toUserdata(ServerLogic, L.upValueIndex(2)) orelse {
        return 0;
    };

    L.checkType(2, .String);
    const eventName = L.toString(2);

    L.checkType(3, .Function);
    const regIdx = L.saveRegistry(3);

    self.dispatcher.bind(eventName, regIdx) catch {
        L.pushString("failed to bind event");
        return 1;
    };
    L.pushNil();
    return 1;
}

fn lua_get_database(L: *State) i32 {
    const self: *ServerLogic = L.toUserdata(ServerLogic, L.upValueIndex(2)) orelse {
        L.pushNil();
        return 1;
    };

    DatabaseBinding.newUserdata(L, .{ .db = self.database, .io = self.server.io });
    return 1;
}

fn lua_multicast(L: *State) i32 {
    L.pushBool(true);
    L.pushNil();
    return 2;
}

fn lua_get_time(L: *State) i32 {
    const self: *ServerLogic = L.toUserdata(ServerLogic, L.upValueIndex(2)) orelse {
        L.pushNil();
        return 1;
    };

    const time = self.server.getServerTime();
    L.pushInteger(@intCast(time));
    return 1;
}

fn lua_get_local_date(L: *State) i32 {
    const self: *ServerLogic = L.toUserdata(ServerLogic, L.upValueIndex(2)) orelse {
        L.pushNil();
        return 1;
    };

    const date = self.server.getLocalDate();
    L.pushInteger(date.toSeconds());
    return 1;
}

fn lua_get_world(L: *State) i32 {
    const self: *ServerLogic = L.toUserdata(ServerLogic, L.upValueIndex(2)) orelse {
        L.pushNil();
        return 1;
    };

    bindings.WorldBinding.newUserdata(L, &self.world);
    return 1;
}

fn lua_get_peer(L: *State) i32 {
    const self: *ServerLogic = L.toUserdata(ServerLogic, L.upValueIndex(2)) orelse {
        L.pushNil();
        return 1;
    };

    const peerId = L.checkInteger(i32, -1);

    if (peerId > self.server.peers.len or peerId <= 0) {
        L.pushNil();
        return 1;
    }

    if (self.server.peers[@intCast(peerId)]) |peer| {
        bindings.PeerBinding.newUserdata(L, peer);
    } else {
        L.pushNil();
    }
    return 1;
}

fn lua_create_npc(L: *State) i32 {
    //lua code:
    // ---@class NPCCreateInfo
    // ---@field name string name in world
    // ---@field position Position start position in world
    // ---@field on_update fun(npc: NPC) Callback invoked every server tick to update the NPC's state
    // ---@field on_interact fun(npc: NPC, peer: Peer) Callback invoked when a player interacts with the NPC

    const self: *ServerLogic = L.toUserdata(ServerLogic, L.upValueIndex(2)) orelse {
        L.pushNil();
        return 1;
    };

    L.checkType(2, .Table);

    L.getField(2, "name");
    const name = L.checkString(-1);
    L.pop(1);

    L.getField(2, "position");
    const position = bindings.PositionBinding.toUserdata(L, L.getTop()) orelse {
        L.pushNil();
        return 1;
    };
    L.pop(1);

    L.getField(2, "on_update");
    L.checkType(-1, .Function);
    const onUpdateRegId = L.saveRegistry(-1);
    L.pop(1);

    L.getField(2, "on_interact");
    L.checkType(-1, .Function);
    const onInteractRegId = L.saveRegistry(-1);
    L.pop(1);

    L.getField(2, "tick");
    const tick = L.toIntegerOr(u32, -1, 1000);
    L.pop(1);

    var equipments = [_]Item{.{}} ** 16;
    L.getField(2, "equipments");
    if (!L.isNil(-1)) {
        L.pushNil();
        while (L.next(-2)) {
            const index = L.checkInteger(usize, -2);
            const item = ItemBinding.toUserdata(L, -1) orelse {
                return L.panic("equipment must be item");
            };
            equipments[index] = item.*;
            L.pop(1);
        }
        L.pop(1);
    }

    _ = self.world.createNPC(.{
        .name = name,
        .position = position,
        .equipments = equipments,
        .onUpdate = onUpdateRegId,
        .tick = tick,
        .onInteract = onInteractRegId,
    }) catch {
        return L.panic("failed to create NPC: ");
    };
    L.pushNil();
    return 1;
}

fn lua__spawn_item(L: *State) i32 {
    const self: *ServerLogic = L.toUserdata(ServerLogic, L.upValueIndex(2)) orelse {
        L.pushString("missing server argument");
        return 1;
    };

    L.checkType(2, .Table);

    L.getField(2, "item");
    const item = ItemBinding.toUserdata(L, -1) orelse {
        L.pushString("spawn_item: 'item' must be an Item instance");
        return 1;
    };
    L.pop(1);

    L.getField(2, "position");
    const position = PositionBinding.toUserdata(L, -1) orelse {
        L.pushString("spawn_item: 'position' must be a Position instance");
        return 1;
    };
    L.pop(1);

    L.getField(2, "rotation");
    const rotation = L.toIntegerOr(u8, -1, 0);
    L.pop(1);

    L.getField(2, "state");
    const state = L.toIntegerOr(u8, -1, 0);
    L.pop(1);

    L.getField(2, "on_interact");
    if (!L.isType(-1, .Function)) {
        L.pop(1);
        L.pushString("spawn_item: 'on_interact' must be a function");
        return 1;
    }
    const onInteract = L.saveRegistry(-1);
    L.pop(1);

    _ = self.world.spawnItem(.{
        .state = state,
        .item = item.*,
        .position = position,
        .rotation = rotation,
        .onInteract = onInteract,
    }) catch {
        L.pushString("spawn_item: failed to insert item in world");
        return 1;
    };

    var pack = network.builders.buildCreateGroundItem(position, item.itemID, item.*, rotation, state);

    for (self.server.peers) |peer_opt| {
        const peer = peer_opt orelse continue;
        peer.sendPacket(&pack) catch {};
    }

    L.pushNil();
    return 1;
}

fn lua__spawn_player(L: *State) i32 {
    const self: *ServerLogic = L.toUserdata(ServerLogic, L.upValueIndex(2)) orelse {
        L.pushString("missing server argument");
        return 1;
    };

    const peer = PeerBinding.toUserdata(L, 2) orelse {
        L.pushString("missing peer argument");
        return 1;
    };

    const charSlot = L.checkInteger(i8, 3);
    const x = L.checkInteger(i16, 4);
    const y = L.checkInteger(i16, 5);

    const account = &peer.account;
    if (charSlot < 0 or charSlot >= account.characters.len) {
        L.pushString("slot is invalid, must be 0-3");
        return 1;
    }

    const char: *Character = @constCast(&account.characters[@intCast(charSlot)]);
    account.charSelected = @intCast(charSlot);
    const state = &peer.playerState;

    state.mob = char.toMob();
    state.mob.mobId = @intCast(peer.peerId);

    const peerId: u16 = @intCast(peer.peerId);

    const obj = self.world.spawnMobWithId(&state.mob, @intCast(peerId), x, y) catch {
        L.pushString("spawn in world invalid");
        return 1;
    };
    state.mobPoint = &obj.point;

    peer.sendPacket(@constCast(
        &responses.PacketCharSpawnOutput{
            .header = .{
                .index = peerId,
                .operationCode = @intFromEnum(responses.Opcode.CHAR_SPAWNED),
                .time = @intCast(self.server.getServerTime()),
            },
            .character = .from(peerId, char),
            .position = .{ .x = x, .y = y },
        },
    )) catch {
        _ = state.mobPoint.?.remove();
        L.pushString("failed to send spawn mob packet");
        return 1;
    };

    peer.sendPacket(@constCast(
        &responses.PacketSpawnOutput{
            .header = .{
                .index = peerId,
                .operationCode = @intFromEnum(responses.Opcode.MOB_CREATE),
                .time = @intCast(self.server.getServerTime()),
            },
            .ownerId = peerId,
            .mob = .from(&state.mob),
            .position = .{ .x = x, .y = y },
        },
    )) catch {
        _ = state.mobPoint.?.remove();
        L.pushString("failed to send spawn mob packet");
        return 1;
    };
    L.pushNil();
    return 1;
}
