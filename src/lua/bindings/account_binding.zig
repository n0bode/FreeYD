const Mapper = @import("utils.zig").MapperStructPtr;
const bindFunctions = @import("utils.zig").bindFunctions;
const lua = @import("binding.zig").lua;
const domain = @import("binding.zig").domain;
const DatabaseBinding = @import("binding.zig").DatabaseBinding;
const CharacterBinding = @import("binding.zig").CharacterBinding;

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
        .{
            .name = "create_character",
            .value = .{
                .func = .{
                    .func = lua__create_character,
                },
            },
        },
        .{
            .name = "get_character",
            .value = .{
                .func = .{
                    .func = lua__get_character,
                },
            },
        },
        .{
            .name = "delete_character",
            .value = .{
                .func = .{
                    .func = lua__delete_character,
                },
            },
        },
        .{
            .name = "get_current_char",
            .value = .{
                .func = .{
                    .func = lua__current_character,
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

fn lua__create_character(L: *lua.State) i32 {
    const self: *domain.Account = toUserdata(L, 1) orelse {
        return L.throw("function must be called with an account instance");
    };

    const name = L.checkString(2);
    const slotId = L.checkInteger(u8, 3);
    const classInt = L.checkInteger(u8, 4);
    const soulInt = L.checkInteger(u8, 5);

    // validations
    if (name.len >= 16) {
        return L.throw("name length is too long");
    }

    if (slotId < 0 or slotId >= 4) {
        return L.throw("slotId must be between 0 and 3");
    }

    const class = std.enums.fromInt(domain.CharacterClass, classInt) orelse {
        return L.throw("class is invalid");
    };

    const soul = std.enums.fromInt(domain.CharacterSoul, soulInt) orelse {
        return L.throw("soul type is invalid");
    };

    if (!L.isNil(6) and L.getLuaType(6) != .Function) {
        return L.throw("builder must a function");
    }

    const char: *domain.Character = &self.characters[@intCast(slotId)];
    CharacterBinding.newUserdata(L, char);

    // setup chars
    char.* = .empty(class);
    char.accountId = self.accountID;
    char.soul = soul;
    char.slotId = slotId;
    @memcpy(char.name[0..name.len], name[0..]);

    if (!L.isNil(6) and L.getLuaType(6) == .Function) {
        L.pushValue(6);
        L.pushValue(-2);
        if (!L.pcall(1, 0)) {
            const msg = L.toString(-1);
            std.log.err("create_character 'builder' returns failed: {s}", .{msg});
            L.pop(1);
            return L.throw("builder returns failed");
        }
    }
    char.currentStats = char.stats;

    L.pushNil();
    return 2;
}

fn lua__get_character(L: *lua.State) i32 {
    const self: *domain.Account = toUserdata(L, 1) orelse {
        return L.throw("function must be called with an account instance");
    };

    const slotId = L.checkInteger(u8, 2);
    if (slotId < 0 or slotId >= 4) {
        return L.throw("slotId must be between 0 and 3");
    }

    const char: *domain.Character = &self.characters[@intCast(slotId)];
    CharacterBinding.newUserdata(L, char);
    L.pushNil();
    return 2;
}

fn lua__current_character(L: *lua.State) i32 {
    const self: *domain.Account = toUserdata(L, 1) orelse {
        return L.throw("function must be called with an account instance");
    };

    const char: *domain.Character = &self.characters[@intCast(self.charSelected)];
    CharacterBinding.newUserdata(L, char);
    L.pushNil();
    return 2;
}

fn lua__delete_character(L: *lua.State) i32 {
    const self: *domain.Account = toUserdata(L, 1) orelse {
        return L.throw("function must be called with an account instance");
    };

    const slotId = L.checkInteger(u8, 2);
    if (slotId < 0 or slotId >= 4) {
        return L.throw("slotId must be between 0 and 3");
    }

    self.characters[@intCast(slotId)] = std.mem.zeroes(domain.Character);
    return 0;
}
