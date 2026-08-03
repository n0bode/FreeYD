const Item = @import("item.zig").Item;
const Character = @import("char.zig").Character;
const std = @import("std");

pub const AccountState = enum(u8) {
    NEW_ACCOUNT = 0b00,
    OFFLINE = 0b001,
    LOGGED = 0b010,
    BANNED = 0b011,
    PLAYING = 0b110,
};

pub const Account = extern struct {
    accountID: u64,
    name: [16:0]u8,
    password: [16:0]u8,
    pinPassword: [6]u8,
    server: u8,
    keys: [16]u8,
    ipAddr: [16]u8,
    gold: i32,
    charInfo: u32,
    charSelected: i8,
    cargo: [128]Item,
    state: AccountState = .NEW_ACCOUNT,
    characters: [4]Character,
    email: [128]u8,
};
