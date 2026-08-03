const domain = @import("packet.zig").domains;
const std = @import("std");

pub const Header = @import("packet.zig").Header;
pub const Opcode = @import("packet.zig").Opcode;
const crypto = @import("crypto.zig");

// terms:
// Input = all received from client
// Output = all sent to client
// Data = data communs

pub const OpcodeToClient = enum(u16) {
    charCreated = @intFromEnum(Opcode.CHAR_CREATED),
    charDeleted = @intFromEnum(Opcode.CHAR_DELETED),
    charSpawn = @intFromEnum(Opcode.CHAR_SPAWNED),
    messageText = @intFromEnum(Opcode.TEXTMESSAGE),
    enterAccount = @intFromEnum(Opcode.CHAR_LIST),
};

pub const PacketData = union(OpcodeToClient) {
    charCreated: PacketCharCreateOuput,
    charDeleted: PacketCharDeleteOutput,
    charSpawn: PacketCharSpawnOutput,
    itemCreate: PacketCreateGroundItemOutput,
    messageText: PacketMessageTextOutput,
};

pub const PacketMessageTextOutput = extern struct {
    header: Header,
    text: [96]u8 = [_]u8{0} ** 96,

    pub fn build(text: []const u8) PacketMessageTextOutput {
        var self = PacketMessageTextOutput{};
        @memcpy(self.text[0..text.len], text);
        return self;
    }
};

pub const PacketToClient = struct {
    header: Header,
    data: PacketData,

    pub fn encode(self: *PacketToClient, buffer: []u8) void {
        // set operation code
        self.header.operationCode = @intFromEnum(self.data);
        var bHeader = std.mem.asBytes(&self.header);

        inline for (std.meta.fields(PacketData)) |field| {
            const v = @intFromEnum(@field(PacketData, field.name));
            if (v == @intFromEnum(self.data)) {
                const T = @FieldType(PacketData, field.name);

                const size = @sizeOf(T);
                var bData = std.mem.asBytes(&self.data);
                @memcpy(buffer[@sizeOf(Header)..], bData[0..size]);

                self.header.verifier.size = @sizeOf(Header) + size;
                @memcpy(buffer[0..@sizeOf(Header)], bHeader[0..@sizeOf(Header)]);
                crypto.encrypt(buffer[0..]);
            }
        }
        return;
    }

    pub fn getPacketSize(comptime opcode: OpcodeToClient) usize {
        return @sizeOf(Header) + getPacketNoHeaderSize(opcode);
    }

    fn getPacketNoHeaderSize(comptime opcode: OpcodeToClient) usize {
        const selected = @intFromEnum(opcode);

        inline for (std.meta.fields(PacketData)) |field| {
            const v = @intFromEnum(@field(PacketData, field.name));
            if (v == selected) {
                const T = @FieldType(PacketData, field.name);
                return @sizeOf(T);
            }
        }
        @compileError("invalid erro");
    }
};

test "packet - teste" {
    var packet = PacketToClient{
        .data = .{ .messageText = .build("hello world") },
        .header = .{
            .index = 0,
            .time = 0,
            .operationCode = 100,
        },
    };

    const size = comptime PacketToClient.getPacketSize(.messageText);
    var buffer: [size]u8 = undefined;

    packet.encode(buffer[0..]);
}

pub const StatsData = extern struct {
    level: u16,
    defense: i16,
    attack: i16,

    state: packed struct(u16) {
        mobType: u4,
        direction: u4,
        speed: u4,
        pkLevel: u4,
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

    pub fn fromMob(mob: *const domain.Mob) StatsData {
        const s = &mob.stats;
        return StatsData{
            .level = mob.level,
            .defense = s.defense,
            .attack = s.attack,
            .state = .{
                .direction = s.movement.direction,
                .speed = s.movement.speed,
                .mobType = @intCast(mob.kind & 0xF),
                .pkLevel = @intCast(mob.pkLevel & 0xF),
            },
            .maxHp = s.maxHp,
            .maxMp = s.maxMp,
            .currentHp = s.hp,
            .currentMp = s.mp,
            .str = s.str,
            .int = s.int,
            .dex = s.dex,
            .con = s.con,
            .specials = @bitCast(s.skills),
        };
    }

    pub fn fromChar(c: *const domain.Character, s: *const domain.Stats) StatsData {
        return StatsData{
            .level = c.level,
            .defense = s.defense,
            .attack = s.attack,
            .state = .{
                .direction = s.movement.direction,
                .speed = s.movement.speed,
                // always 1 for players
                .mobType = 1,
                .pkLevel = @intCast(c.pkLevel & 0xF),
            },
            .maxHp = s.maxHp,
            .maxMp = s.maxMp,
            .currentHp = s.hp,
            .currentMp = s.mp,
            .str = s.str,
            .int = s.int,
            .dex = s.dex,
            .con = s.con,
            .specials = @bitCast(s.skills),
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

pub const PacketCreateGroundItemOutput = extern struct {
    header: Header,
    position: PositionData,
    itemId: u16,
    item: ItemData,
    rotate: u8,
    state: u8,
};

pub const PacketItemMoveOutput = extern struct {
    header: Header,
    storage: u16,
    slot: u16,
    item: ItemData,
};

pub const PacketCharListData = extern struct {
    positionX: [4]i16 = [_]i16{0} ** 4,
    positionY: [4]i16 = [_]i16{0} ** 4,
    name: [4][16]u8,
    stats: [4]StatsData,
    equipments: [4][16]ItemData,
    guild: [4]u16,
    gold: [4]i32,
    exp: [4]u32,

    pub fn from(account: *domain.Account) PacketCharListData {
        var self = std.mem.zeroInit(PacketCharListData, .{});
        for (0..4) |iChar| {
            if (iChar > account.characters.len) {
                continue;
            }

            const dbChar = account.characters[iChar];
            self.positionX[iChar] = dbChar.position.x;
            self.positionY[iChar] = dbChar.position.y;
            self.name[iChar] = dbChar.name;
            self.guild[iChar] = dbChar.guildId;
            self.gold[iChar] = dbChar.gold;
            self.exp[iChar] = dbChar.exp;

            self.stats[iChar] = .fromChar(&dbChar, &dbChar.stats);
            const equipments = &self.equipments[iChar];
            inline for (0..equipments.len) |iEquip| {
                if (iEquip > (dbChar.equipments.len - 1)) {
                    continue;
                }
                const dbEquip = dbChar.equipments[iEquip];
                equipments[iEquip] = .{
                    .index = dbEquip.itemID,
                    .effects = @bitCast(dbEquip.attributes),
                };
            }
        }
        return self;
    }
};

test "packet - char list" {
    var account = domain.Account{
        .characters = [_]domain.Character{
            domain.Character{
                .name = "char1",
                .positionX = 100,
                .positionY = 200,
                .stats = domain.CharacterStats{
                    .level = 10,
                    .defense = 5,
                    .attack = 15,
                    .state = domain.CharacterState{
                        .merchant = 1,
                        .direction = 2,
                        .speed = 3,
                        .pkRate = 4,
                    },
                    .maxHp = 100,
                    .maxMp = 50,
                    .currentHp = 80,
                    .currentMp = 40,
                    .str = 10,
                    .int = 5,
                    .dex = 7,
                    .con = 8,
                    .specials = [_]u8{ 1, 2, 3, 4 },
                },
                .equipments = [_]domain.Item{
                    domain.Item{ .itemID = 1, .effect = [_]u16{ 10, 20, 30 } },
                },
                .guildId = 1234,
                .gold = 5000,
                .exp = 10000,
            },
        },
        .cargo = [_]domain.Item{
            domain.Item{ .itemID = 2, .effect = [_]u16{ 5, 10, 15 } },
        },
        .gold = 10000,
        .name = "account1",
        .keys = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 },
    };

    const packetData = PacketCharListData.from(&account);
    std.debug.print("PacketCharListData: {any}\n", .{packetData});
}

pub const PacketCharListOutput = extern struct {
    header: Header,

    characters: PacketCharListData,
    cargo: [128]ItemData,
    gold: i32,
    name: [16]u8,
    keys: [16]u8,
    cash: i32,
    dunno: i32,

    pub fn from(account: *domain.Account, opcode: OpcodeToClient) PacketCharListOutput {
        var self = std.mem.zeroInit(PacketCharListOutput, .{
            .header = .{
                .operationCode = @intFromEnum(opcode),
            },
            .characters = PacketCharListData.from(account),
            .gold = account.gold,
            .name = account.name,
            .keys = account.keys,
        });

        for (account.cargo, 0..) |dbItem, idx| {
            self.cargo[idx] = @bitCast(dbItem);
        }
        return self;
    }
};

pub const PacketCharCreateOutput = extern struct {
    header: Header,
    characters: PacketCharListData,
};

pub const PositionData = extern struct {
    x: i16 = 0,
    y: i16 = 0,
};

pub const CharacterData = extern struct {
    name: [12]u8,
    pkLevel: i8,
    currentKill: u8,
    totalKill: u16,
    cape: u8,
    info: u8,
    guildId: u16,
    class: u8,
    buffers: u8 = 0,
    gold: i32,
    exp: u32,
    position: PositionData,
    stats: StatsData,
    currentStats: StatsData,
    equipments: [16]ItemData,
    storage: [64]ItemData,

    _dunno1: i32 = 0,

    status: u16,
    skills: u16,
    master: u16,
    criticRate: u8,
    saveMana: u8,

    skillBar0: [4]i8,
    guildLevel: u8,
    _dunno2: u8 = 0,

    regenHp: i8,
    regenMp: i8,
    resists: [4]u8,

    slotId: u16,
    userId: u16,

    drillingRate: u32,
    skillBar1: [16]i8,

    hold: i32,
    tab: [26]u8,
    absorption: u32,

    timestamp: u32,
    attackSpeed: u16,
    drainHp: i32,
    rest: [404]u8 = [_]u8{0} ** 404,

    pub fn from(userId: u16, c: *const domain.Character) CharacterData {
        var self: CharacterData = std.mem.zeroInit(CharacterData, .{
            .name = c.name[0..12].*,
            .pkLevel = c.pkLevel,
            .totalKill = c.totalKill,
            .currentKill = @as(u8, @intCast(c.currentKill & 0xFF)),
            .cape = c.clan,
            .info = @as(u8, @bitCast(c.citizenInfo)),
            .guildId = c.guildId,
            .class = @intFromEnum(c.class),
            .gold = c.gold,
            .exp = c.exp,
            .position = .{ .x = c.position.x, .y = c.position.y },
            .stats = StatsData.fromChar(c, &c.stats),
            .currentStats = StatsData.fromChar(c, &c.currentStats),
            .regenHp = c.currentStats.regenHp,
            .regenMp = c.currentStats.regenMp,
            .skills = c.skillPoints,
            .criticRate = c.currentStats.criticalRate,
            .saveMana = c.saveMana,
            .skillBar0 = @as([4]i8, c.skillBar[0..4].*),
            .skillBar1 = @as([16]i8, c.skillBar[4..].*),
            .guildLevel = c.guildLevel,
            .resists = @as([4]u8, @bitCast(c.currentStats.resists)),
            .slotId = c.slotId,
            .userId = userId,
            .attackSpeed = c.currentStats.attackSpeed,
            .tab = c.tab,
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

pub const PacketCharSpawnOutput = extern struct {
    header: Header,
    position: PositionData,
    character: CharacterData,
};

pub const MobData = extern struct {
    name: [12]u8,
    pkLevel: i8,
    currentKill: u8,
    totalKill: u16,
    equipments: [16]MobItem,
    buffers: [16]u16,
    guildId: u16,
    stats: StatsData,
    spawn: u16,
    anctCode: [16]u8,
    tab: [26]u8,
    _0: [4]u8 = [_]u8{0} ** 4,

    pub fn from(mob: *domain.Mob) MobData {
        return MobData{
            .name = mob.name[0..12].*,
            .pkLevel = mob.pkLevel,
            .currentKill = @intCast(mob.currentKill & 0xFF),
            .totalKill = mob.totalKill,
            .guildId = mob.guildId,
            .stats = StatsData.fromMob(mob),
            .spawn = mob.spawnType,
            .tab = mob.tab,
            .equipments = @bitCast(mob.equipments),
            .buffers = [_]u16{0} ** 16,
            .anctCode = @bitCast(mob.anctCode),
        };
    }
};

const MobItem = packed struct(u16) {
    level: u4,
    itemId: u12,
};

fn getItem(item: domain.Item) MobItem {
    for (item.attributes) |attr| {
        if (attr.index == 43)
            return .{
                .level = attr.value,
                .itemId = @intCast(item.index & 0xFFF),
            };
        if (attr.index >= 116)
            return .{
                .level = attr.value,
                .itemId = @intCast(item.index & 0xFFF),
            };
    }
    return @bitCast(item.itemID);
}

pub const PacketSpawnOutput = extern struct {
    header: Header,
    position: PositionData,
    ownerId: u16,
    mob: MobData,
};

pub const PacketCharCreateOuput = extern struct {
    characters: PacketCharListData,
};

pub const PacketCharDeleteOutput = extern struct {
    header: Header,
    characters: PacketCharListData,
};

pub const PacketEmpty = extern struct {
    header: Header,
};

pub const PacketUpdateStats = extern struct {
    header: Header,
    stats: StatsData,
    criticRate: u8,
    saveMana: u8,
    buffs: [32]u16,
    guild: u16,
    guildRole: u16,
    resists: [4]u8,
    regenHP: u8,
    regenMP: u8,
    hp: i32,
    mp: i32,
    magic: i32,
    skills: u32,
};

// struct MSG_Action {
//  _MSG;
//
//  short PosX, PosY;
//
//  int Effect; // 0 = walking, 1 = teleporting
//  int Speed;
//
//  char Route[MAX_ROUTE];
//
//  short TargetX, TargetY;
//};
pub const PacketMobMoveOutput = extern struct {
    header: Header,
    origin: PositionData,
    speed: u32,
    kind: u32,
    destination: PositionData,
    route: [24]i8 = [_]i8{0} ** 24,
};

pub const PacketUpdateEquipmentOutput = extern struct {
    header: Header,
    equipments: [16]MobItem,
    anctCode: [16]u8,
};

pub const PacketDropItemOutput = extern struct {
    header: Header,
    sourceType: u32,
    slot: u32,
    rotation: PositionData,
    position: PositionData,
    itemID: u16,
};

pub const PacketDeleteGroundItemOutput = extern struct {
    header: Header,
    itemId: u16,
    dunno: u16,
};

pub const PacketUpdateGroundItemOutput = extern struct {
    header: Header,
    itemId: u32,
    state: u32,
};
