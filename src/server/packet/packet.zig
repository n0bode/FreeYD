const domain = @import("core").domains;
const std = @import("std");

pub const Opcode = enum(u16) {
    LOGIN = 0x020D,
    TEXTMESSAGE = 0x0101,
    PING = 0x03A0,
    PIN = 0x0FDE,
    PIN_FAIL = 0x0FDF,
    CHAR_LIST = 0x010E,
    CHAR_CREATE = 0x020F,
    CHAR_CREATE_FAIL = 0x41D,
    CHAR_CREATED = 0x0110,
    CHAR_DELETE = 0x211,
    CHAR_DELETED = 0x112,
    ENTER_WORLD = 0x213,
    ENTERED_WORLD = 0x114,
    MOVEMENT = 0x366,
    MOVE_ITEM = 0x0376,
    CREATE_ITEM = 0x182,
};

pub const Verifier = extern struct {
    size: u16,
    iKeyword: u8,
    checksum: u8,

    pub const empty: Verifier = .{
        .size = 0,
        .iKeyword = 0,
        .checksum = 0,
    };
};

pub const Header = extern struct {
    verifier: Verifier = .empty,
    operationCode: u16,
    index: u16,
    time: u32,
};

pub const PacketTextMessage = extern struct {
    header: Header,
    message: [96]u8 = [_]u8{0} ** 96,
};

pub const PacketLogin = extern struct {
    header: Header,
    username: [16]u8,
    password: [12]u8,
    version: i32,
    none: i32,
    keys: [16]u8,
    ipaddress: [16]u8,
};

pub const PacketPing = Header;
pub const PacketSignal = Header;

pub const PacketPin = extern struct {
    header: Header,
    numeric: [6]u8,
    _unknown: [10]u8,
};

pub const InfoStats = extern struct {};

pub const CharStatsData = extern struct {
    level: u16,
    defense: i16,
    attack: i16,

    state: packed struct(u16) {
        mechant: u4,
        direction: u4,
        speed: u4,
        pkRate: u4,
    },

    maxHp: u16,
    maxMp: u16,
    currentHp: u16,
    currentMp: u16,

    str: i16,
    int: i16,
    dex: i16,
    con: i16,

    specials: [4]u8,

    pub fn from(s: domain.CharacterStats) CharStatsData {
        return CharStatsData{
            .level = s.level,
            .defense = s.defense,
            .attack = s.attack,
            .state = @bitCast(s.state),
            .maxHp = s.maxHp,
            .maxMp = s.maxMp,
            .currentHp = s.currentHp,
            .currentMp = s.currentMp,
            .str = s.str,
            .int = s.int,
            .dex = s.dex,
            .con = s.con,
            .specials = s.specials,
        };
    }
};

pub const Pair = struct {
    key: u8,
    value: u8,
};

pub const ItemData = extern struct {
    index: u16 = 0,
    effects: [3]u16 = [_]u16{0} ** 3,
};

pub const StorageType = enum(u8) {
    equip = 0,
    inventory = 1,
    cargo = 2,
};

pub const PacketMoveItemInput = extern struct {
    header: Header,
    destStorage: StorageType,
    destSlot: u8,
    sourceStorage: StorageType,
    sourceSlot: u8,
    _0: u32 = 0,
};

pub const PacketCreateItemOutput = extern struct {
    header: Header,
    slotType: u16,
    slot: u16,
    item: ItemData,
};

pub const PacketCharListData = extern struct {
    positionX: [4]i16 = [_]i16{0} ** 4,
    positionY: [4]i16 = [_]i16{0} ** 4,
    name: [4][16]u8,
    stats: [4]CharStatsData,
    equipments: [4][16]ItemData,
    guild: [4]u16,
    gold: [4]i32,
    exp: [4]u32,

    pub fn from(account: domain.Account) PacketCharListData {
        var self = std.mem.zeroInit(PacketCharListData, .{});
        for (account.characters, 0..) |dbChar, iChar| {
            if (dbChar.name[0] == 0) continue;

            self.positionX[iChar] = dbChar.positionX;
            self.positionY[iChar] = dbChar.positionY;
            self.name[iChar] = dbChar.name;
            self.guild[iChar] = dbChar.guildId;
            self.gold[iChar] = dbChar.gold;
            self.exp[iChar] = dbChar.exp;

            self.stats[iChar] = @bitCast(dbChar.stats);

            const equipments = &self.equipments[iChar];
            inline for (dbChar.equipments, 0..) |dbEquip, iEquip| {
                equipments[iEquip] = .{
                    .index = dbEquip.itemID,
                    .effects = dbEquip.effect,
                };
            }
        }
        return self;
    }
};

pub const PacketCharList = extern struct {
    header: Header,

    //hash: [16]i8 = [_]i8{0} ** 16,
    //_dunno: u32 = 0xCCCCCCCC,

    characters: PacketCharListData,
    cargo: [128]ItemData,
    gold: i32,
    name: [16]u8,
    keys: [16]u8,
    cash: i32,
    dunno: i32,
};

pub const PacketCharCreateInput = extern struct {
    header: Header,

    slot: i32,
    name: [16]u8,
    class: domain.CharacterClass,
};

pub const PacketCharCreateOutput = extern struct {
    header: Header,
    characters: PacketCharListData,
};

pub const PacketEnterWorldInput = extern struct {
    header: Header,
    charSlot: i32,
    _dunno: [18]u8 = [_]u8{0} ** 18,
};

pub const PositionData = extern struct {
    x: i16,
    y: i16,
};

pub const CharacterData = extern struct {
    name: [16]u8,
    cape: u8,
    info: packed struct(u8) {
        merchant: u6,
        city: u2,
    },
    guildId: u16,
    class: u8,
    buffers: u8,
    gold: i32,
    exp: u32,
    position: PositionData,
    stats: CharStatsData,
    currentStats: CharStatsData,
    equipments: [16]ItemData,
    storage: [64]ItemData,

    _dunno1: i32 = 0,

    status: u16,
    skills: u16,
    master: u16,
    criticRate: u8,
    saveMana: u8,

    skillBar0: [4]u8,
    guildRole: u8,
    _dunno2: u8 = 0,

    regenHp: i8,
    regenMp: i8,
    resists: [4]i8,

    slotId: u16,
    userId: u16,

    drillingRate: u32,
    skillBar1: [16]u8,

    hold: i32,
    tab: [26]u8,
    absorption: u32,

    timestamp: u32,
    attackSpeed: u16,
    drainHp: i32,
    rest: [404]u8 = [_]u8{0} ** 404,

    pub fn from(userId: u16, c: *domain.Character) CharacterData {
        var self = std.mem.zeroInit(CharacterData, .{
            .name = c.name,
            .cape = c.clan,
            .info = c.info,
            .guildId = c.guildId,
            .class = @intFromEnum(c.class),
            .gold = c.gold,
            .exp = c.exp,
            .position = .{ .x = c.positionX, .y = c.positionY },
            .stats = CharStatsData.from(c.stats),
            .currentStats = CharStatsData.from(c.stats),
            .regenHp = c.regenHp,
            .regenMp = c.regenMp,
            .skills = c.skills,
            .criticRate = c.criticRate,
            .saveMana = c.saveMana,
            .skillBar0 = c.skillBar0,
            .guildRole = c.guildRole,
            .resists = c.resists,
            .slotId = c.slotId,
            .userId = userId,
            .skillBar1 = c.skillBar1,
            .attackSpeed = c.attackSpeed,
        });

        inline for (c.equipments, 0..) |dbEquip, idx| {
            const equip = &self.equipments[idx];
            equip.* = @bitCast(dbEquip);
        }

        inline for (c.carry, 0..) |dbEquip, idx| {
            self.storage[idx] = @bitCast(dbEquip);
        }
        return self;
    }
};

pub const PacketEnterWorldOutput = extern struct {
    header: Header,
    position: PositionData,
    character: CharacterData,
};

pub const PacketActionInput = extern struct {
    header: Header,
    position: PositionData,
    speed: i32,
    kind: i32,
    destination: PositionData,
    command: [24]u8,
};

pub const MobData = extern struct {
    entityId: u16,
    name: [12]u8,

    chaos: u8,
    currentKill: u8,
    totalKill: u16,
    items: [16]u16,
    buffers: [16]u16,
    guildId: u16,
    stats: CharStatsData,
    spawn: u16,
    anctCode: [16]u8,
    tab: [26]u8,
    _0: [4]u8,
};

pub const PacketSpawnOutput = extern struct {
    header: Header,
    position: PositionData,
    mob: MobData,
};

pub const OpcodeRecv = enum(u16) {
    unknown,
    login = @intFromEnum(Opcode.LOGIN),
    ping = @intFromEnum(Opcode.PING),
    pin = @intFromEnum(Opcode.PIN),
    charCreate = @intFromEnum(Opcode.CHAR_CREATE),
    charDelete = @intFromEnum(Opcode.CHAR_DELETE),
    enterWorld = @intFromEnum(Opcode.ENTER_WORLD),
    moviment = @intFromEnum(Opcode.MOVEMENT),
    moveItem = @intFromEnum(Opcode.MOVE_ITEM),

    pub fn parse(code: u16) OpcodeRecv {
        inline for (std.enums.values(OpcodeRecv)) |value| {
            if (@intFromEnum(value) == code) {
                return value;
            }
        }
        return .unknown;
    }
};

pub const PacketCharCreated = extern struct {
    header: Header,
    characters: PacketCharListData,
};

pub const PacketCharDeleteInput = extern struct {
    header: Header,
    slot: i32,
    name: [16]u8,
    password: [12]u8,
};

pub const PacketCharDeleteOutput = extern struct {
    header: Header,
    characters: PacketCharListData,
};

pub const PacketOpcode = enum(u16) {
    unknown,
    login = Opcode.LOGIN,
    textmessage = Opcode.TEXTMESSAGE,
    charlist = Opcode.CHAR_LIST,
    ping = Opcode.PING,

    pub fn parse(code: u16) PacketOpcode {
        return switch (code) {
            Opcode.LOGIN => PacketOpcode.login,
            Opcode.TEXTMESSAGE => PacketOpcode.textmessage,
            Opcode.PING => PacketOpcode.ping,
            else => .unknown,
        };
    }
};

pub const Packet = union(OpcodeRecv) {
    unknown: Header,
    login: PacketLogin,
    ping: PacketPing,
    pin: PacketPin,
    charCreate: PacketCharCreateInput,
    charDelete: PacketCharDeleteInput,
    enterWorld: PacketEnterWorldInput,
    moviment: PacketActionInput,
    moveItem: PacketMoveItemInput,
};
