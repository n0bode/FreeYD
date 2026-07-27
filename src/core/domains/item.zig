const std = @import("std");
const Position = @import("domains.zig").Position;

pub const ItemAttribute = extern struct {
    // 43 = quality item +0 +1 +2 ...
    index: u8 = 0,
    value: u8 = 0,
};

pub const Item = extern struct {
    itemID: u16 = 0,
    attributes: [3]ItemAttribute = [_]ItemAttribute{.{}} ** 3,
};

pub const GroundItem = extern struct {
    itemId: u16,
    item: Item,
    position: Position,
    rotation: u8,
    state: u8,
};

pub const StorageType = enum(u8) {
    EQUIPMENT = 0,
    INVENTORY = 1,
    CARGO = 2,
};
