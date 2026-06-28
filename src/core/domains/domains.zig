pub const CharacterList = @import("char.zig").CharacterList;
pub const Item = @import("item.zig").Item;

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

    pub const PinPassword = extern struct {
        a: u16,
        b: u8,

        pub const empty = PinPassword{
            .a = 0,
            .b = 0,
        };

        pub fn toChars(self: PinPassword, num: *[6]u8) void {
            const upper: u24 = @intCast(self.a);
            const lower: u24 = @intCast(self.b);

            const pin: u24 = (upper << 8) + lower;
            inline for (0..6) |i| {
                num[i] = @intCast(pin << ((5 - i) * 4) & 0x0F);
            }
        }

        pub fn fromChar(chars: [6]u8) PinPassword {
            var a: u16 = 0;
            inline for (chars[0..4], 0..) |chr, i| {
                const shift = (3 - i) * 4;
                a = a + (@as(u16, @intCast(chr & 0xF)) << shift);
            }

            return .{
                .a = a,
                .b = (chars[4] & 0xF << 4) + (chars[5] & 0xF),
            };
        }
    };
};
