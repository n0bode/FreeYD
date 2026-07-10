const State = @import("binding.zig").lua.State;
const Database = @import("binding.zig").Database;
const std = @import("std");

const AccountBinding = @import("binding.zig").AccountBinding;
const Account = @import("binding.zig").domain.Account;

pub const DatabaseBinding = @This();

pub const metatableName = "mt_Database";

pub const DBCtx = struct {
    db: Database,
    io: std.Io,
};

pub fn toUserdata(L: *State, idx: i32) ?*DBCtx {
    const ptr: *DBCtx = L.toUserdata(DBCtx, idx) orelse {
        return null;
    };
    return ptr;
}

pub fn newUserdata(L: *State, ctx: DBCtx) void {
    const ptr: *DBCtx = L.newUserdata(DBCtx);
    ptr.* = ctx;
    L.getMetatableByName(metatableName);
    _ = L.setMetatable(-2);
}

pub fn bind(L: *State) void {
    _ = L.newMetatable(metatableName);
    L.pushValue(-1);
    L.setField(-2, "__index");
    L.setFuncs(&.{
        .{
            .name = "get_account_by_credentials",
            .value = .{
                .func = .{
                    .func = lua_get_account_by_credentials,
                },
            },
        },
        .{
            .name = "create_account",
            .value = .{
                .func = .{
                    .func = lua_create_account,
                },
            },
        },
        .{
            .name = "get_account_by_username",
            .value = .{
                .func = .{
                    .func = lua__get_account_by_username,
                },
            },
        },
    });
}

fn lua_create_account(L: *State) i32 {
    const self = (toUserdata(L, 1) orelse {
        L.pushNil();
        return 1;
    });

    L.checkType(2, .Table);

    L.getField(2, "username");
    const login = L.toString(-1);

    L.getField(2, "password");
    const password = L.toString(-1);

    var account: Account = undefined;
    if (!self.db.signup(self.io, login, password, &account)) {
        L.pushNil();
        return 1;
    }

    const ptr: *Account = L.newUserdata(Account);
    ptr.* = account;
    AccountBinding.newUserdata(L, ptr);
    return 1;
}

fn lua_get_account_by_credentials(L: *State) i32 {
    const self = (toUserdata(L, 1) orelse {
        L.pushNil();
        return 1;
    });

    L.checkType(2, .String);
    const login = L.toString(2);

    L.checkType(3, .String);
    const password = L.toString(3);

    var account: Account = undefined;
    if (!self.db.login(self.io, login, password, &account)) {
        L.pushNil();
        return 1;
    }

    // WARN: create struct account in HEAP memory
    const ptr: *Account = L.newUserdata(Account);
    ptr.* = account;
    AccountBinding.newUserdata(L, ptr);

    return 1;
}

fn lua__get_account_by_username(L: *State) i32 {
    const self = (toUserdata(L, 1) orelse {
        L.pushNil();
        return 1;
    });

    L.checkType(2, .String);
    const username = L.toString(2);

    var account: Account = undefined;
    if (!self.db.getAccountByUsername(self.io, username, &account)) {
        L.pushNil();
        return 1;
    }

    const ptr: *Account = L.newUserdata(Account);
    ptr.* = account;
    AccountBinding.newUserdata(L, ptr);

    return 1;
}
