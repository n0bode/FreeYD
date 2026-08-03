const std = @import("std");
const domain = @import("domains.zig");

const Stats = domain.Stats;
const Item = domain.Item;
const StorageType = domain.StorageType;
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

pub const Position = extern struct {
    x: i16 = 0,
    y: i16 = 0,
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
    cape = 15,
};

pub const Character = extern struct {
    characterId: u32 = 0,
    accountId: u64 = 0,
    slotId: u8 = 0,

    level: u16 = 0,
    name: [16]u8 = [_]u8{0} ** 16,
    tab: [26]u8 = [_]u8{0} ** 26,

    pkLevel: i8 = -1,
    totalKill: u16 = 0,
    currentKill: u16 = 0,

    clan: u8 = 0,
    soul: CharacterSoul = .MORTAL,
    citizenInfo: CitizenInfo = .{},
    guildId: u16 = 0,
    guildLevel: u8 = 0,
    class: CharacterClass,
    rsv: u16 = 0,
    quest: u8 = 0,
    gold: i32 = 0,
    exp: u32 = 0,
    position: Position = .{},
    stats: Stats = .{},
    currentStats: Stats = .{},
    equipments: [16]Item,
    carry: [64]Item,
    skillPoints: u16,
    attributePoints: u16,
    specialsBonus: u16,
    skillsBonus: u16,
    saveMana: u8,
    skillBar: [20]i8,

    pub fn empty(class: CharacterClass) Character {
        var self = std.mem.zeroInit(Character, .{
            .class = class,
        });

        self.skillBar = [_]i8{-1} ** 20;
        // in 7.54 FaceID, 1 = TK, 11 = FM, BM = 21, HT = 31
        if (self.soul == .MORTAL) {
            self.equipments[0].itemID = 1 + @as(u16, @intCast(@intFromEnum(class))) * 10;
        } else {
            self.equipments[0].itemID = 41 + @intFromEnum(class);
        }
        return self;
    }

    pub fn toMob(self: *Character) domain.Mob {
        var mob = domain.Mob{
            .mobId = 0,
            .name = self.name,
            .pkLevel = self.pkLevel,
            .currentKill = self.currentKill,
            .totalKill = self.totalKill,
            .equipments = [_]domain.MobItem{.{}} ** 16,
            .buffers = [_]domain.Buffer{.{}} ** 16,
            .anctCode = [_]u8{0} ** 16,
            .guildId = self.guildId,
            .stats = self.currentStats,
            .spawnType = 1,
            .tab = self.tab,
        };

        for (self.equipments, 0..) |item, i| {
            if (i != @intFromEnum(EquipmentSlot.mount)) {
                mob.equipments[i] = .from(item);
            } else {
                mob.equipments[i] = .fromMount(item);
            }

            for (item.attributes) |attr| {
                if (attr.index == 43 and attr.value > 230) {
                    mob.anctCode[i] = switch (@as(u2, @intCast(attr.value & 3))) {
                        0 => 0x30,
                        1 => 0x40,
                        2 => 0x10,
                        3 => 0x20,
                    };
                }
            }
        }

        mob.name[12] = 0;
        mob.name[13] = 0;
        return mob;
    }

    pub fn getItem(self: *Character, storage: StorageType, slot: u8) ?Item {
        return switch (storage) {
            .INVENTORY => self.carry[slot],
            .EQUIPMENT => self.equipments[slot],
            else => null,
        };
    }

    pub fn getSlot(self: *Character, storage: StorageType, slot: u8) ?*Item {
        return switch (storage) {
            .INVENTORY => &self.carry[slot],
            .EQUIPMENT => &self.equipments[slot],
            else => null,
        };
    }

    pub fn swapItems(
        self: *Character,
        destStorage: StorageType,
        destSlot: u8,
        srcStorage: StorageType,
        srcSlot: u8,
    ) bool {
        const destItem = self.getSlot(destStorage, destSlot) orelse return false;
        const srcItem = self.getSlot(srcStorage, srcSlot) orelse return false;

        const temp = destItem.*;
        destItem.* = srcItem.*;
        srcItem.* = temp;
        return true;
    }

    pub fn findEmptyInventorySlot(self: *Character) ?u8 {
        for (self.carry, 0..) |slot, i| {
            if (slot.itemID == 0) {
                return @intCast(i);
            }
        }
        return null;
    }

    pub fn addItemOnEmptySlot(self: *Character, item: Item) i16 {
        const slot = self.findEmptyInventorySlot() orelse return -1;
        self.carry[slot] = item;
        return slot;
    }
};
