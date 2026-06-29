const std = @import("std");

pub const Item = extern struct {
    itemID: i16,
    effect: [3]u16,

    pub fn zero() Item {
        return Item{
            .itemID = 0,
            .effect = [_]u16{0} ** 3,
        };
    }
};

pub const IValue = extern struct {
    index: u8,
    value: u8,

    pub fn zero() IValue {
        return .{ .index = 0, .value = 0 };
    }
};
