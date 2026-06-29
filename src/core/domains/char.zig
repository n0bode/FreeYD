const Item = @import("item.zig").Item;

pub const Character = extern struct {
    name: [16]u8,
    clan: u8,

    merchant: u8,
    guild: u16,
    class: u8,
    rsv: u16,
    quest: u8,

    gold: i32,
    exp: i64,

    positionX: i16,
    positionY: i16,

    stats: CharStat,
    currentStats: CharStat,

    equipaments: [16]Item,
    carry: [16]Item,

    skills: u64,
    magic: u32,

    statsBonus: u16,
    specialsBonus: u16,
    skillsBonus: u16,

    criticRate: u8,
    saveMana: u8,

    skillBar: [4]u8,
    guildLevel: u8,

    regenHp: u16,
    regenMp: u16,

    resists: [4]i8, // fire ice, element
};

pub const CharStat = extern struct {
    level: u16,
    defense: i16,
    attack: i16,

    merchant: u8,
    direction: u8,
    speed: u8,
    chaosRate: u8,

    maxHp: u16,
    maxMp: u16,
    currentHp: u16,
    currentMp: u16,

    str: i16,
    int: i16,
    dex: i16,
    con: i16,

    specials: [4]i16,
};
