const Item = @import("item.zig").Item;
const Character = @import("char.zig").Character;
const std = @import("std");

pub const AccountMode = enum(u8) {
    unset = 0x00,
    normal = 0x01,
    banned = 0x02,
};

pub const Account = extern struct {
    accountID: u64,
    name: [16]u8,
    password: [16]u8,
    pinPassword: PinPassword,
    server: u8,
    keys: [16]u8,
    ipAddr: [16]u8,
    gold: i32,
    charInfo: u32,
    charSelected: u64,
    cargo: [128]Item,
    mode: AccountMode = .unset,
    characters: [4]Character,

    pub const PinPassword = extern struct {
        a: u16,
        b: u8,

        pub fn toChars(self: PinPassword, num: []u8) void {
            const upper: u24 = (@as(u24, @intCast(self.a)) << 8) & 0xFFFF00;
            const lower: u24 = @intCast(self.b);

            const pin: u24 = upper + lower;
            inline for (0..6) |i| {
                const p: u8 = @intCast((pin >> ((5 - i) * 4)) & 0xF);
                num[i] = p + '0';
            }
        }

        pub fn fromChar(chars: [6]u8) PinPassword {
            var a: u16 = 0;
            inline for (chars[0..4], 0..) |chr, i| {
                const shift = (3 - i) * 4;
                a = a + (@as(u16, @intCast((chr - '0') & 0xF)) << shift);
            }

            const b = (((chars[4] - '0') & 0xF) << 4) + ((chars[5] - '0') & 0xF);
            return .{
                .a = a,
                .b = b,
            };
        }
    };
};
