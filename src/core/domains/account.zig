const Item = @import("item.zig").Item;
const Character = @import("char.zig").Character;
const std = @import("std");

pub const AccountMode = enum(u8) {
    unset = 0x00,
    offline = 0x01,
    logged = 0x02,
    banned = 0x03,
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
    state: AccountMode = .unset,
    characters: [4]Character,
};
