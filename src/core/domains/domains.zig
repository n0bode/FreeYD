pub const CharacterList = @import("char.zig").CharacterList;
pub const Item = @import("item.zig").Item;

pub const Account = struct {
    accountID: u64,
    name: []const u8,
    password: []const u8,
    numericPassword: [6]u4,
    server: u8,
    keys: [16]u8,
    ipAddr: [16]u8,
    gold: i32,
    charInfo: u32,
    charSelected: u64,
    cargo: [128]Item,
    mode: i32,
};
