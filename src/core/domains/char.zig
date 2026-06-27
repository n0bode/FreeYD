const Item = @import("item.zig").Item;

pub const CharStat = extern struct {
    level: u16,
    defense: i16,
    attack: i16,

    merchant: u4,
    direction: u4,
    speed: u4,
    chaosRate: u4,

    max_hp: u16,
    max_mp: u16,
    current_hp: u16,
    current_mp: u16,

    strength: i16,
    intelligence: i16,
    dexterity: i16,
    constitution: i16,

    w_master: u8,
    f_master: u8,
    s_master: u8,
    t_master: u8,
};

pub const CharacterList = extern struct {
    positionX: [4]i16,
    positionY: [4]i16,
    name: [4][16]u8,
    stats: [4]CharStat,
    inventory: [4][16]Item,
    guild: [4]u16,
    gold: [4]i32,
    exp: [4]u32,
};
