const std = @import("std");
const domain = @import("domains.zig");

const Stats = domain.Stats;
const Item = domain.Item;
const ResistStats = domain.ResitsStats;

pub const CharacterClass = enum(u8) {
    TK = 0,
    FM = 1,
    BM = 2,
    HT = 3,
};

pub const CharacterSoul = enum(u8) {
    MORTAL = 0,
    GOD = 1,
    CELESTIAL = 2,
    SUBCELESTIAL = 3,
};

pub const Cities = enum(u2) {
    ARMIA = 0,
    CITY1 = 1,
    CITY2 = 2,
    CITY3 = 3,
};

pub const CitizenInfo = packed struct(u8) {
    merchant: u6 = 0,
    city: Cities = .ARMIA,
};

pub const Position = packed struct(u32) {
    x: i16,
    y: i16,
};

pub const EquipmentSlot = enum(u8) {
    face = 0,
    head = 1,
    body = 2,
    pants = 3,
    gloves = 4,
    boots = 5,
    weapon = 6,
    shield = 7,
    unk8 = 8,
    unk9 = 9,
    unk10 = 10,
    unk11 = 11,
    unk12 = 12,
    unk13 = 13,
    mount = 14,
    unk15 = 15,
};

pub const Character = extern struct {
    accountId: u64 = 0,
    slotId: u8 = 0,

    name: [16]u8,
    tab: [26]u8,

    pkLevel: u8 = 255,
    totalKill: u16 = 0,
    currentKill: u8 = 0,

    clan: u8 = 0,
    soul: CharacterSoul = .MORTAL,

    citizenInfo: CitizenInfo,

    guildId: u16 = 0,
    class: CharacterClass,
    guildRole: u8 = 0,
    rsv: u16 = 0,
    quest: u8 = 0,

    gold: i32 = 0,
    exp: u32 = 0,

    position: Position,

    stats: Stats,
    currentStats: Stats,

    equipments: [16]Item,
    carry: [64]Item,

    skillPoints: u16,
    magic: u32,

    attributePoints: u16,
    specialsBonus: u16,
    skillsBonus: u16,

    criticRate: u8,
    saveMana: u8,

    skillBar0: [4]i8,
    skillBar1: [16]i8,
    guildLevel: u8,

    regenHp: i8,
    regenMp: i8,
    attackSpeed: u16,

    resists: ResistStats,

    pub fn empty(class: CharacterClass) Character {
        var self = std.mem.zeroInit(Character, .{
            .class = class,
        });

        self.skillBar0 = [_]i8{-1} ** 4;
        self.skillBar1 = [_]i8{-1} ** 16;

        // in 7.54 FaceID, 1 = TK, 11 = FM, BM = 21, HT = 31
        self.equipments[0].itemID = 1 + @as(u16, @intCast(@intFromEnum(class))) * 10;
        return self;
    }

    pub fn toMob(self: *Character, userId: u16) domain.Mob {
        var mob = domain.Mob{
            .mobId = userId,
            .name = self.name,
            .pkLevel = self.pkLevel,
            .currentKill = self.currentKill,
            .totalKill = self.totalKill,
            .equipments = self.equipments,
            .buffers = [_]domain.Buffer{.{}} ** 16,
            .guildId = self.guildId,
            .stats = self.currentStats,
            .spawnType = 1,
            .tab = self.tab,
        };

        mob.name[12] = 0;
        mob.name[13] = 0;
        return mob;
    }
};
