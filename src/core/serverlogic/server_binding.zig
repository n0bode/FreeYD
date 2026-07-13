const lua = @import("serverlogic.zig").lua;
const network = @import("serverlogic.zig").network;
const Logic = @import("serverlogic.zig").Logic;
const dblib = @import("serverlogic.zig").dblib;
const DatabaseBinding = @import("serverlogic.zig").bindings.DatabaseBinding;

const Database = dblib.Database;
const Account = dblib.Account;
const Character = dblib.Character;

const State = lua.State;
const Reg = lua.Reg;

const std = @import("std");

pub const ServerBinding = @This();

pub fn bind(logic: *Logic) void {
    const L = logic.L;
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
            .name = "multicast",
            .value = .{
                .func = .{
                    .func = lua_multicast,
                    .userdata = logic,
                },
            },
        },
    });
}

fn lua_on_bind(L: *State) i32 {
    const self: *Logic = L.toUserdata(Logic, L.upValueIndex(2)) orelse {
        return 0;
    };

    L.checkType(2, .String);
    const eventName = L.toString(2);

    L.checkType(3, .Function);
    const regIdx = L.saveRegistry(3);

    self.bindEvent(eventName, regIdx) catch {
        _ = L.throw("failed to bind function");
        return 0;
    };
    return 0;
}

fn lua_get_database(L: *State) i32 {
    const self = L.toUserdata(Logic, L.upValueIndex(2)) orelse {
        L.pushNil();
        return 1;
    };

    DatabaseBinding.newUserdata(L, .{ .db = self.db, .io = self.io });
    return 1;
}

fn lua_multicast(L: *State) i32 {
    const self: *Logic = L.toUserdata(Logic, L.upValueIndex(2)) orelse {
        L.pushNil();
        return 1;
    };

    const eventName = L.checkString(2);

    _ = self.execCommand(eventName, L);
    return 0;
}
