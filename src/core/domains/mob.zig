const item = @import("item.zig");
const Item = item.Item;

pub const Mob = struct {
    // if user need peerId
    mobId: u16,
    name: [16]u8,
    pkLevel: u8,
    currentKill: u8,
    totalKill: u16,
    equipments: [16]Item,
    buffers: [16]Buffer,
    guildId: u16,
    stats: Stats,
    // check this
    spawnType: u16,
    // dunno
    //anctCode: [16]u8,
    tab: [26]u8,
};

pub const StatsState = packed struct(u16) {
    // question: what is it?
    merchant: u4 = 0,
    // question: what is it?
    direction: u4 = 0,
    // movement speed of character
    movementSpeed: u4 = 0,
    // level of PK
    pkLevel: u4 = 0,
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

pub const Stats = extern struct {
    level: u16 = 1,
    defense: i16 = 10,
    attack: i16 = 50,
    state: StatsState,
    maxHp: u16 = 100,
    maxMp: u16 = 100,
    hp: u16 = 100,
    mp: u16 = 100,
    str: i16 = 0,
    int: i16 = 0,
    dex: i16 = 0,
    con: i16 = 0,
    skills: SkillAttributes,
};

pub const Buffer = extern struct {
    // need verify, 0-255 buffers
    index: u8 = 0,
    time: u8 = 0,
};

pub const ResistStats = extern struct {
    ice: u8,
    fire: u8,
    element: u8,
    lighting: u8,
};
