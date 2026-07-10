const Mapper = @import("utils.zig").LuaMapperStruct;
const bindFunctions = @import("utils.zig").bindFunctions;
const lua = @import("binding.zig").lua;
const domain = @import("binding.zig").domain;
const DatabaseBinding = @import("binding.zig").DatabaseBinding;
const std = @import("std");

pub const AccountBinding = @This();

const AccountMapped = Mapper(domain.Account);
pub const metatableName = AccountMapped.metatableName;

pub fn toUserdata(L: *lua.State, idx: i32) ?*domain.Account {
    return AccountMapped.toUserdata(L, idx);
}

pub fn newUserdata(L: *lua.State, account: *domain.Account) void {
    AccountMapped.newUserdata(L, account);
}

pub fn bind(L: *lua.State) void {
    AccountMapped.bind(L);
    bindEnums(L);
    bindFunctions(L, metatableName, &.{
        .{
            .name = "save",
            .value = .{
                .func = .{
                    .func = lua__save,
                },
            },
        },
    });
}

fn bindEnums(L: *lua.State) void {
    // create account state
    L.newTable();
    inline for (std.meta.fields(domain.AccountState)) |option| {
        L.pushInteger(option.value);
        L.setField(-2, option.name);
    }
    L.setGlobal("AccountState");
}

fn lua__save(L: *lua.State) i32 {
    const self: *domain.Account = toUserdata(L, 1) orelse {
        L.pushNil();
        return 1;
    };

    L.checkType(2, .Userdata);
    const DB = DatabaseBinding.toUserdata(L, 2) orelse {
        _ = L.throw("missing database to save");
        return 0;
    };

    L.pushBool(DB.db.updateAccount(DB.io, self));
    return 1;
}
