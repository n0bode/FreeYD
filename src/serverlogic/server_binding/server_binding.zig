const std = @import("std");

const serverlogic = @import("../serverlogic.zig");
const lua = serverlogic.lua;
const bindings = serverlogic.bindings;

const network = serverlogic.network;
const ServerLogic = serverlogic.ServerLogic;
const DatabaseBinding = bindings.DatabaseBinding;

const Database = serverlogic.Database;

const core = serverlogic.core;
const Account = core.domains.Account;
const Character = core.domains.Character;

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
    });
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
    L.pushInteger(time);
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

    const peerId = L.checkInteger(-1);

    if (self.server.peers[@intCast(peerId)]) |peer| {
        bindings.PeerBinding.newUserdata(L, peer);
    } else {
        L.pushNil();
    }
    return 1;
}
