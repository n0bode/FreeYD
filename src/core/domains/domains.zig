pub const CharacterList = @import("char.zig").CharacterList;
pub const Item = @import("item.zig").Item;

pub const Account = extern struct {
    accountID: u64,
    name: [16]u8,
    password: [16]u8,
    numericPassword: [6]u8,
    server: u8,
    keys: [16]u8,
    ipAddr: [16]u8,
    gold: i32,
    charInfo: u32,
    charSelected: u64,
    cargo: [128]Item,
    mode: i32,
};
