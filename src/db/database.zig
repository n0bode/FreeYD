const Io = @import("std").Io;
const std = @import("std").mem.Allocator;

const domain = @import("core").domains;
pub const Account = domain.Account;
pub const Item = domain.Item;
pub const Character = domain.Character;

//errors
pub const LoginError = error{UsernameNotFound};

// interface
// generate generic inteface to multiples implementations database
// eg postgres, sqlite, etc..
pub const Database = @This();
ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    login: *const fn (*anyopaque, io: Io, username: []const u8, password: []const u8, account: *Account) bool,
    signup: *const fn (*anyopaque, io: Io, username: []const u8, password: []const u8, account: *Account) bool,
    updateAccount: *const fn (*anyopaque, io: Io, account: *Account) bool,
};

// wrapper function
pub fn login(
    self: Database,
    io: Io,
    username: []const u8,
    password: []const u8,
    account: *Account,
) bool {
    return self.vtable.login(self.ptr, io, username, password, account);
}

pub fn signup(
    self: Database,
    io: Io,
    username: []const u8,
    password: []const u8,
    account: *Account,
) bool {
    return self.vtable.signup(self.ptr, io, username, password, account);
}

pub fn updateAccount(
    self: Database,
    io: Io,
    account: *Account,
) bool {
    return self.vtable.updateAccount(self.ptr, io, account);
}

pub fn from(impl: anytype) Database {
    const T = @TypeOf(impl);
    const gen = struct {
        fn login(ptr: *anyopaque, io: Io, username: []const u8, password: []const u8, account: *Account) bool {
            const self = @as(T, @ptrCast(@alignCast(ptr)));
            return self.login(io, username, password, account);
        }
        fn signup(ptr: *anyopaque, io: Io, username: []const u8, password: []const u8, account: *Account) bool {
            const self = @as(T, @ptrCast(@alignCast(ptr)));
            return self.signup(io, username, password, account);
        }
        fn updateAccount(ptr: *anyopaque, io: Io, account: *Account) bool {
            const self = @as(T, @ptrCast(@alignCast(ptr)));
            return self.updateAccount(io, account);
        }
    };
    return .{
        .ptr = impl,
        .vtable = &VTable{
            .login = gen.login,
            .signup = gen.signup,
            .updateAccount = gen.updateAccount,
        },
    };
}
