const Item = @import("item.zig").Item;
const std = @import("std");

pub const Class = enum(u8) {
    TK = 0,
    FM = 1,
    BM = 2,
    HT = 3,
};

pub const Soul = enum(u8) {
    MORTAL = 0,
    GOD = 1,
    CELESTIAL = 2,
    SUBCELESTIAL = 3,
};

pub const Character = extern struct {
    accountId: u64 = 0,
    slotId: u8 = 0,

    name: [16]u8,
    clan: u8 = 0,
    soul: Soul = .MORTAL,

    info: packed struct(u8) {
        merchant: u6 = 0,
        // armia
        city: u2 = 1,
    },

    guildId: u16 = 0,
    class: Class,
    guildRole: u8 = 0,
    rsv: u16 = 0,
    quest: u8 = 0,

    gold: i32 = 0,
    exp: u32 = 0,

    positionX: i16 = 0,
    positionY: i16 = 0,

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

    resists: packed struct(u32) {
        ice: u8,
        fire: u8,
        element: u8,
        lighting: u8,
    },

    pub fn empty(class: Class) Character {
        var self = std.mem.zeroInit(Character, .{
            .class = class,
            // born in train field
            .positionX = 2096,
            .positionY = 2096,
        });

        // in 7.54 FaceID, 1 = TK, 11 = FM, BM = 21, HT = 31
        self.equipments[0].itemID = 1 + @as(u16, @intCast(@intFromEnum(class))) * 10;
        return self;
    }
};

pub const Stats = extern struct {
    level: u16 = 1,
    defense: i16 = 10,
    attack: i16 = 50,

    state: packed struct(u16) {
        // question: what is it?
        merchant: u4 = 0,
        // question: what is it?
        direction: u4 = 0,
        // movement speed of character
        movementSpeed: u4 = 0,
        // level of PK
        pkLevel: u4 = 0,
    },

    maxHp: u16 = 100,
    maxMp: u16 = 100,
    currentHp: u16 = 100,
    currentMp: u16 = 100,

    str: i16 = 0,
    int: i16 = 0,
    dex: i16 = 0,
    con: i16 = 0,

    specials: packed struct(u32) {
        // weapon
        skill0: u8 = 0,
        // class: BM (elemental)
        skill1: u8 = 0,
        // class: BM (evocation)
        skill2: u8 = 0,
        // class: BM (nature)
        skill3: u8 = 0,
    },
};
