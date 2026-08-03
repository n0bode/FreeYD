const Item = @import("item.zig").Item;

pub const MobItem = packed struct(u16) {
    itemId: u12 = 0,
    level: u4 = 0,

    pub fn from(item: Item) MobItem {
        const level: u8 = blk: {
            for (item.attributes) |attr| {
                if (attr.index == 43) {
                    if (attr.value < 230) {
                        break :blk @intCast(attr.value % 10);
                    } else if (attr.value < 254) {
                        break :blk @intCast(10 + ((attr.value - 230) / 4));
                    }
                }
            }
            break :blk 0;
        };

        return MobItem{
            .level = @intCast(level & 0xF),
            .itemId = @intCast(item.itemID & 0xFFF),
        };
    }

    pub fn fromMount(item: Item) MobItem {
        // secret numbers?
        if (item.itemID >= 3980 and item.itemID < 3995) {
            return MobItem{
                .itemId = @intCast(item.itemID & 0xFFF),
            };
        }

        // mount is dead
        if (item.attributes[0].value <= 0)
            return .{};

        return .{
            .level = @intCast((item.attributes[1].value / 10) & 0xF),
            .itemId = @intCast(item.itemID & 0xFFF),
        };
    }
};

pub const Mob = struct {
    // if user need peerId
    mobId: u16 = 0,
    name: [16]u8 = [_]u8{0} ** 16,
    // mobtype
    // 0 = ENEMY
    // 1 = INTERACT
    kind: u8 = 0,
    //
    level: u16 = 0,
    // must start with -1
    pkLevel: i8 = -1,
    // current kill count of mob
    currentKill: u16 = 0,
    // total kill count of mob
    totalKill: u16 = 0,
    // item with itemID and level
    equipments: [16]MobItem = [_]MobItem{.{}} ** 16,
    // current buffers/debuffers actived in mob
    buffers: [16]Buffer = [_]Buffer{.{}} ** 16,
    guildId: u16 = 0,
    stats: Stats = .{},
    // check this
    spawnType: u16 = 0,
    // if item is a ancient item
    anctCode: [16]u8 = [_]u8{0} ** 16,
    // text above mob head
    tab: [26]u8 = [_]u8{0} ** 26,
};

pub const SkillAttributes = packed struct(u32) {
    // weapon
    skill0: u8 = 0,
    // class: BM (elemental)
    skill1: u8 = 0,
    // class: BM (evocation)
    skill2: u8 = 0,
    // class: BM (nature)
    skill3: u8 = 0,
};

pub const MovementStats = packed struct(u8) {
    speed: u4 = 1,
    direction: u4 = 0,
};

pub const Stats = extern struct {
    statsId: u16 = 0,
    defense: i16 = 10,
    attack: i16 = 50,
    attackSpeed: u16 = 0,
    magicDamage: u16 = 0,
    movement: MovementStats = .{},
    maxHp: u16 = 100,
    maxMp: u16 = 100,
    regenHp: i8 = 1,
    regenMp: i8 = 1,
    hp: u16 = 100,
    mp: u16 = 100,
    criticalRate: u8 = 0,
    // attributes
    str: i16 = 0,
    int: i16 = 0,
    dex: i16 = 0,
    con: i16 = 0,
    skills: SkillAttributes = .{},
    resists: ResistStats = .{},
};

pub const Buffer = extern struct {
    // need verify, 0-255 buffers
    index: u8 = 0,
    time: u8 = 0,
};

pub const ResistStats = extern struct {
    ice: u8 = 0,
    fire: u8 = 0,
    element: u8 = 0,
    lighting: u8 = 0,
};
