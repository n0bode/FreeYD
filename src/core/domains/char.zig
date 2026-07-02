const Item = @import("item.zig").Item;
const std = @import("std");

pub const Class = enum(u8) {
    Tk = 0,
    FM = 1,
    BM = 2,
    HT = 3,
};

pub const Character = extern struct {
    accountId: u16,
    slotId: u16,

    name: [16]u8,
    clan: u8,

    info: packed struct(u8) {
        merchant: u6,
        city: u2,
    },

    guildId: u16,
    class: Class,
    guildRole: u8,
    rsv: u16,
    quest: u8,

    gold: i32,
    exp: u32,

    positionX: i16,
    positionY: i16,

    stats: Stats,
    currentStats: Stats,

    equipments: [16]Item,
    carry: [64]Item,

    skills: u16,
    magic: u32,

    statsBonus: u16,
    specialsBonus: u16,
    skillsBonus: u16,

    criticRate: u8,
    saveMana: u8,

    skillBar0: [4]u8,
    skillBar1: [16]u8,
    guildLevel: u8,

    regenHp: i8,
    regenMp: i8,
    attackSpeed: u16,

    resists: [4]i8, // fire ice, element
    pub fn fromClass(class: Class) Character {
        var defaults = switch (class) {
            .BM => std.mem.zeroInit(Character, .{
                .clan = 0xF8,
                .class = Class.BM,
                .gold = 20000,
                .guildRole = 0x1E,
                .positionX = 2096,
                .positionY = 2096,
                .stats = .{
                    .level = 0,
                    .defense = 4,
                    .attack = 5,
                    .maxHp = 55,
                    .maxMp = 70,
                    .currentHp = 55,
                    .currentMp = 6,
                    .str = 6,
                    .int = 9,
                    .dex = 5,
                    .con = 0,
                },
                .currentStats = .{
                    .specials = [4]u8{ 21, 0, 43, 0 },
                },
            }),
            .FM => std.mem.zeroInit(Character, .{
                .class = Class.FM,
                .gold = 20000,
                .positionX = 2096,
                .positionY = 2096,
                .stats = .{
                    .level = 0,
                    .defense = 4,
                    .attack = 5,
                    .maxHp = 55,
                    .maxMp = 60,
                    .currentHp = 65,
                    .currentMp = 5,
                    .str = 8,
                    .int = 5,
                    .dex = 5,
                    .con = 0,
                },
                .currentStats = .{
                    .specials = [4]u8{ 11, 0, 43, 0 },
                },
            }),
            else => std.mem.zeroInit(Character, .{}),
        };

        // in 7.54 FaceID, 1 = TK, 11 = FM, BM = 21, HT = 31
        defaults.equipments[0].itemID = 1 + @as(u16, @intCast(@intFromEnum(class))) * 10;
        defaults.equipments[5].itemID = 1430;
        return defaults;
    }
};

pub const Stats = extern struct {
    level: u16 = 10,
    defense: i16 = 3,
    attack: i16 = 2,

    state: packed struct(u16) {
        merchant: u4,
        direction: u4,
        speed: u4,
        pkRate: u4,
    },

    maxHp: u16 = 100,
    maxMp: u16 = 100,
    currentHp: u16 = 100,
    currentMp: u16 = 100,

    str: i16 = 5,
    int: i16 = 5,
    dex: i16 = 5,
    con: i16 = 5,

    specials: [4]u8 = [_]u8{0} ** 4,
};
