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
    message: [96]u8,
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

pub const PacketCharStatsData = extern struct {
    level: u16,
    defense: i16,
    attack: i16,

    merchant: u8,
    direction: u8,
    speed: u8,
    chaosRate: u8,

    max_hp: u16,
    max_mp: u16,
    current_hp: u16,
    current_mp: u16,

    str: i16,
    int: i16,
    dex: i16,
    con: i16,

    specials: [4]i16,
};

pub const Pair = struct {
    key: u8,
    value: u8,
};

pub const PacketItemData = extern struct {
    index: i16 = 0,
    effects: [3]u16 = [_]u16{0} ** 3,
};

pub const PacketCharListData = extern struct {
    positionX: [4]i16 = [_]i16{0} ** 4,
    positionY: [4]i16 = [_]i16{0} ** 4,
    name: [4][16]u8,
    stats: [4]PacketCharStatsData,
    equipments: [4][16]PacketItemData,
    guild: [4]u16,
    gold: [4]i32,
    exp: [4]i64,

    pub fn from(account: domain.Account) PacketCharListData {
        var self = std.mem.zeroInit(PacketCharListData, .{});
        for (account.characters, 0..) |dbChar, iChar| {
            if (dbChar.name[0] == 0) continue;

            self.positionX[iChar] = dbChar.positionX;
            self.positionY[iChar] = dbChar.positionY;
            self.name[iChar] = dbChar.name;
            self.guild[iChar] = dbChar.guild;
            self.gold[iChar] = dbChar.gold;
            self.exp[iChar] = dbChar.exp;

            self.stats[iChar] = @bitCast(dbChar.stats);

            const equipments = &self.equipments[iChar];
            inline for (dbChar.equipaments, 0..) |dbEquip, iEquip| {
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

    hash: [16]i8,
    _dunno: i32,

    characters: PacketCharListData,
    cargo: [128]PacketItemData,
    gold: i32,
    name: [16]u8,
    keys: [12]u8,
};

pub const PacketCharCreate = extern struct {
    pub const ClassEnum = enum(i32) {
        Tk = 0,
        FM = 1,
        BM = 2,
        HT = 3,
    };

    header: Header,

    slot: i32,
    name: [16]u8,
    class: ClassEnum,
};

pub const OpcodeRecv = enum(u16) {
    unknown,
    login = @intFromEnum(Opcode.LOGIN),
    ping = @intFromEnum(Opcode.PING),
    pin = @intFromEnum(Opcode.PIN),
    charCreate = @intFromEnum(Opcode.CHAR_CREATE),

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
    charCreate: PacketCharCreate,
};
