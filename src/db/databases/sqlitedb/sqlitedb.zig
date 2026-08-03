const std = @import("std");
const db = @import("database");
const c = @import("c");

const Database = db.Database;
const Account = db.Account;

const CharacterClass = db.CharacterClass;
const Character = db.Character;
const Item = db.Item;
const Allocator = std.mem.Allocator;
const Stats = db.Stats;

const cwd = std.Io.Dir.cwd();

const logger = std.log.scoped(.sqlite3);

fn callback(_: ?*anyopaque, argc: c_int, argv: [*c][*c]u8, values: [*c][*c]u8) callconv(.c) c_int {
    for (argv[0..@as(usize, @intCast(argc))], 0..) |arg, i| {
        const value = values[i];
        logger.err("colName: {s}, colValue: {s}", .{ arg, value });
    }
    return 0;
}

const Sqlite3 = ?*c.sqlite3;

pub const SqliteDB = struct {
    filename: []const u8,
    conn: Sqlite3 = undefined,
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: Allocator, path: []const u8) !SqliteDB {
        var self = SqliteDB{
            .filename = path,
            .arena = std.heap.ArenaAllocator.init(allocator),
        };

        //TODO: replace allocator default with a custom allocator
        // if not exists, create one
        const flags = c.SQLITE_OPEN_CREATE | c.SQLITE_OPEN_READWRITE;
        if (c.sqlite3_open_v2(path[0..].ptr, @ptrCast(&self.conn), flags, null) != c.SQLITE_OK) {
            logger.err("error to open sqlite3 database: {s}", .{c.sqlite3_errmsg(@ptrCast(&self.conn))});
            return error.DatabaseOpenFailed;
        }
        return self;
    }

    fn execMigrations(self: *SqliteDB) !void {
        const conn = self.conn;

        const stmt =
            \\
            \\CREATE TABLE IF NOT EXISTS account (
            \\     account_id INTEGER PRIMARY KEY,
            \\     username VARCHAR(32) NOT NULL,
            \\     password VARCHAR(32) NOT NULL,
            \\     email VARCHAR(128) NOT NULL,
            \\     pin_password VARCHAR(6) NOT NULL,
            \\     last_login DATETIME,
            \\     gold INTEGER DEFAULT 0,
            \\     state INTEGER DEFAULT 0,
            \\     cargo VARCHAR NOT NULL,
            \\     created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            \\     updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            \\     deleted_at DATETIME DEFAULT NULL
            \\);
            \\
            \\
            \\CREATE UNIQUE INDEX IF NOT EXISTS unique_account_username
            \\ON account (username)
            \\WHERE deleted_at IS NULL;
            \\
            \\CREATE TABLE IF NOT EXISTS character (
            \\     character_id INTEGER PRIMARY KEY,
            \\     account_id INTEGER NOT NULL,
            \\     slot_id INTEGER NOT NULL,
            \\     name VARCHAR(16) NOT NULL,
            \\     tab varchar(26) DEFAULT NULL,
            \\     class INTEGER DEFAULT 0,
            \\     level INTEGER DEFAULT 0,
            \\     total_kills INTEGER DEFAULT 0,
            \\     current_kills INTEGER DEFAULT 0,
            \\     pk_level INTEGER DEFAULT -1,
            \\     clan INTEGER DEFAULT 0,
            \\     guild_id INTEGER DEFAULT NULL,
            \\     guild_level INTEGER DEFAULT 0,
            \\     gold INTEGER DEFAULT 0,
            \\     experience INTEGER DEFAULT 0,
            \\     skill_points INTEGER DEFAULT 0,
            \\     magic INTEGER DEFAULT 0,
            \\     position_x INTEGER DEFAULT 2112,
            \\     position_y INTEGER DEFAULT 2042,
            \\     soul INTEGER DEFAULT 0,
            \\     citizen_info INTEGER DEFAULT 0,
            \\     quest INTEGER DEFAULT 0,
            \\     attribute_points INTEGER DEFAULT 0,
            \\     specials_bonus INTEGER DEFAULT 0,
            \\     skills_bonus INTEGER DEFAULT 0,
            \\     critic_rate INTEGER DEFAULT 0,
            \\     save_mana INTEGER DEFAULT 0,
            \\     skill_bar BLOB NOT NULL,
            \\     inventory BLOB NOT NULL,
            \\     equipments BLOB NOT NULL,
            \\     created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            \\     updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            \\     deleted_at DATETIME DEFAULT NULL,
            \\     FOREIGN KEY (account_id) REFERENCES account(account_id)
            \\);
            \\
            \\CREATE UNIQUE INDEX IF NOT EXISTS unique_character_slot
            \\ON character (account_id, slot_id)
            \\WHERE deleted_at IS NULL;
            \\
            \\
            \\CREATE TABLE IF NOT EXISTS character_stats (
            \\    character_id INTEGER NOT NULL,
            \\    kind INTEGER NOT NULL DEFAULT 0,
            \\    level TINYINT NOT NULL DEFAULT 0,
            \\    defense TINYINT NOT NULL DEFAULT 0,
            \\    movement_speed TINYINT NOT NULL DEFAULT 1,
            \\    movement_direction TINYINT NOT NULL DEFAULT 0,
            \\    attack TINYINT NOT NULL DEFAULT 0,
            \\    max_hp INTEGER NOT NULL DEFAULT 100,
            \\    max_mp INTEGER NOT NULL DEFAULT 100,
            \\    hp INTEGER NOT NULL DEFAULT 100,
            \\    mp INTEGER NOT NULL DEFAULT 100,
            \\    regen_mp INTEGER NOT NULL DEFAULT 100,
            \\    regen_hp INTEGER NOT NULL DEFAULT 100,
            \\    str TINYINT NOT NULL DEFAULT 0,
            \\    int TINYINT NOT NULL DEFAULT 0,
            \\    dex TINYINT NOT NULL DEFAULT 0,
            \\    con TINYINT NOT NULL DEFAULT 0,
            \\    skill_0 TINYINT NOT NULL DEFAULT 0,
            \\    skill_1 TINYINT NOT NULL DEFAULT 0,
            \\    skill_2 TINYINT NOT NULL DEFAULT 0,
            \\    skill_3 TINYINT NOT NULL DEFAULT 0,
            \\    PRIMARY KEY (character_id, kind),
            \\    FOREIGN KEY (character_id) REFERENCES character(character_id)
            \\);
            \\
        ;

        var msg: [*c]u8 = null;
        const result = c.sqlite3_exec(conn, stmt, callback, self, &msg);
        if (result != c.SQLITE_OK) {
            if (msg != null) {
                logger.err("exec fail: {s}", .{msg});
                c.sqlite3_free(msg);
            } else {
                logger.err("exec fail: {s}", .{c.sqlite3_errmsg(@ptrCast(conn))});
            }
            return error.DatabaseAccountTableCreationFailed;
        }
    }

    fn marshal(allocator: Allocator, data: anytype) ![]u8 {
        return try std.json.Stringify.valueAlloc(allocator, data, .{});
    }

    fn unmarshal(comptime T: anytype, allocator: Allocator, buffer: []const u8, data: *T) !void {
        const parsed = try std.json.parseFromSlice(T, allocator, buffer, .{});
        defer parsed.deinit();
        data.* = parsed.value;
    }

    fn readMarshal(self: *SqliteDB, comptime T: anytype, dest: *T, stmt: ?*c.sqlite3_stmt, col: c_int) !void {
        const ptr = c.sqlite3_column_blob(stmt, col);
        const len: usize = @intCast(c.sqlite3_column_bytes(stmt, col));

        const blob = @as([*]u8, @ptrCast(@constCast(ptr)))[0..len];
        try unmarshal(T, self.arena.allocator(), @ptrCast(blob), dest);
    }

    const ItemTuple = struct {
        u8,
        u16,
        [3]struct { u8, u8 },
    };

    // buf must outlive any use of the returned slice (avoids dangling stack pointer).
    fn compactItems(items: []Item, buf: []ItemTuple) []ItemTuple {
        var count: usize = 0;
        for (items, 0..) |item, index| {
            if (item.itemID != 0) {
                buf[count] = .{
                    @intCast(index),
                    item.itemID,
                    .{
                        .{
                            item.attributes[0].index,
                            item.attributes[0].value,
                        },
                        .{
                            item.attributes[1].index,
                            item.attributes[1].value,
                        },
                        .{
                            item.attributes[2].index,
                            item.attributes[2].value,
                        },
                    },
                };
                count += 1;
            }
        }
        return buf[0..count];
    }

    fn bindMarshal(comptime T: anytype, allocator: Allocator, stmt: ?*c.sqlite3_stmt, col: c_int, data: *T) ![]u8 {
        const buffer = try marshal(allocator, data.*);

        logger.info("{s}", .{buffer});
        if (c.sqlite3_bind_text(stmt, col, buffer.ptr, @intCast(buffer.len), null) != c.SQLITE_OK) {
            return error.DatabaseBindFailed;
        }
        return buffer;
    }

    fn getAccount(self: *SqliteDB, io: std.Io, accountId: u64, account: *Account) !void {
        const query =
            \\SELECT
            \\  account_id,
            \\  username,
            \\  password,
            \\  email,
            \\  pin_password,
            \\  gold,
            \\  state,
            \\  cargo
            \\FROM account
            \\WHERE account_id = ? AND deleted_at IS NULL
            \\LIMIT 1
        ;

        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v3(self.conn, query, query.len, 0, &stmt, null) != c.SQLITE_OK) {
            logger.err("getAccount prepare: {s}", .{c.sqlite3_errmsg(self.conn)});
            return;
        }
        defer _ = c.sqlite3_finalize(stmt);

        if (c.sqlite3_bind_int(stmt, 1, @intCast(accountId)) != c.SQLITE_OK) {
            logger.err("getAccount bind: {s}", .{c.sqlite3_errmsg(self.conn)});
            return;
        }

        try io.checkCancel();
        if (c.sqlite3_step(stmt) != c.SQLITE_ROW) return;

        // Zero first so all fields start clean, then populate from DB.
        account.* = std.mem.zeroes(Account);
        account.accountID = @intCast(c.sqlite3_column_int64(stmt, 0));
        account.gold = c.sqlite3_column_int(stmt, 5);
        account.state = @enumFromInt(c.sqlite3_column_int(stmt, 6));

        const name = std.mem.span(c.sqlite3_column_text(stmt, 1));
        const password = std.mem.span(c.sqlite3_column_text(stmt, 2));
        const email = std.mem.span(c.sqlite3_column_text(stmt, 3));
        const pinPassword = std.mem.span(c.sqlite3_column_text(stmt, 4));
        @memcpy(account.name[0..name.len], name);
        @memcpy(account.password[0..password.len], password);
        @memcpy(account.email[0..email.len], email);
        @memcpy(account.pinPassword[0..pinPassword.len], pinPassword);

        // col 7 = cargo stored as compact ItemTuple JSON
        self.readItemsFromBlob(128, &account.cargo, stmt, 7);

        try self.getListCharacter(io, account);
    }

    fn getListCharacter(self: *SqliteDB, io: std.Io, account: *Account) !void {
        const query =
            \\SELECT
            \\  character_id,
            \\  slot_id,
            \\  name,
            \\  class,
            \\  level,
            \\  pk_level,
            \\  total_kills,
            \\  current_kills,
            \\  clan,
            \\  guild_id,
            \\  gold,
            \\  experience,
            \\  skill_points,
            \\  position_x,
            \\  position_y,
            \\  soul,
            \\  citizen_info,
            \\  quest,
            \\  attribute_points,
            \\  specials_bonus,
            \\  skills_bonus,
            \\  save_mana,
            \\  skill_bar,
            \\  guild_level,
            \\  tab,
            \\  inventory,
            \\  equipments
            \\FROM character
            \\WHERE account_id = ? AND deleted_at IS NULL
        ;

        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v3(self.conn, query, query.len, 0, &stmt, null) != c.SQLITE_OK) {
            logger.err("getListCharacter prepare: {s}", .{c.sqlite3_errmsg(self.conn)});
            return;
        }
        defer _ = c.sqlite3_finalize(stmt);

        if (c.sqlite3_bind_int64(stmt, 1, @intCast(account.accountID)) != c.SQLITE_OK) {
            logger.err("getListCharacter bind: {s}", .{c.sqlite3_errmsg(self.conn)});
            return;
        }

        account.characters = std.mem.zeroes(@TypeOf(account.characters));
        try io.checkCancel();
        while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            try io.checkCancel();
            const slot: u8 = @intCast(c.sqlite3_column_int(stmt, 1));
            if (slot >= account.characters.len) continue;

            var char = &account.characters[slot];
            char.characterId = @intCast(c.sqlite3_column_int64(stmt, 0));
            char.accountId = account.accountID;
            char.slotId = slot;

            const charName = std.mem.span(c.sqlite3_column_text(stmt, 2));
            @memcpy(char.name[0..charName.len], charName);

            char.class = @enumFromInt(c.sqlite3_column_int(stmt, 3));
            char.level = @intCast(c.sqlite3_column_int(stmt, 4));
            char.pkLevel = @intCast(c.sqlite3_column_int(stmt, 5));
            char.totalKill = @intCast(c.sqlite3_column_int(stmt, 6));
            char.currentKill = @intCast(c.sqlite3_column_int(stmt, 7));
            char.clan = @intCast(c.sqlite3_column_int(stmt, 8));
            char.guildId = @intCast(c.sqlite3_column_int(stmt, 9));
            char.gold = c.sqlite3_column_int(stmt, 10);
            char.exp = @intCast(c.sqlite3_column_int64(stmt, 11));
            char.skillPoints = @intCast(c.sqlite3_column_int(stmt, 12));
            char.position = .{
                .x = @intCast(c.sqlite3_column_int(stmt, 13)),
                .y = @intCast(c.sqlite3_column_int(stmt, 14)),
            };
            char.soul = @enumFromInt(c.sqlite3_column_int(stmt, 15));
            char.citizenInfo = @bitCast(@as(u8, @intCast(c.sqlite3_column_int(stmt, 16))));
            char.quest = @intCast(c.sqlite3_column_int(stmt, 17));
            char.attributePoints = @intCast(c.sqlite3_column_int(stmt, 18));
            char.specialsBonus = @intCast(c.sqlite3_column_int(stmt, 19));
            char.skillsBonus = @intCast(c.sqlite3_column_int(stmt, 20));
            char.saveMana = @intCast(c.sqlite3_column_int(stmt, 21));
            readBlob([20]i8, &char.skillBar, stmt, 22);
            char.guildLevel = @intCast(c.sqlite3_column_int(stmt, 23));
            const tab = std.mem.span(c.sqlite3_column_text(stmt, 24));
            @memcpy(char.tab[0..tab.len], tab[0..]);

            self.readItemsFromBlob(64, &char.carry, stmt, 25);
            self.readItemsFromBlob(16, &char.equipments, stmt, 26);

            try self.getCharacterStats(io, char, 0, &char.stats);
            try self.getCharacterStats(io, char, 1, &char.currentStats);
        }
    }

    fn getCharacterStats(self: *SqliteDB, io: std.Io, character: *Character, kind: u2, stats: *Stats) !void {
        const query =
            \\SELECT
            \\  cs.defense,
            \\  cs.attack,
            \\  cs.movement_speed,
            \\  cs.movement_direction,
            \\  cs.max_hp,
            \\  cs.max_mp,
            \\  cs.hp,
            \\  cs.mp,
            \\  cs.regen_hp,
            \\  cs.regen_mp,
            \\  cs.str,
            \\  cs.int,
            \\  cs.dex,
            \\  cs.con,
            \\  cs.skill_0,
            \\  cs.skill_1,
            \\  cs.skill_2,
            \\  cs.skill_3
            \\FROM
            \\  character_stats cs
            \\WHERE
            \\  cs.character_id = ? AND cs.kind = ?
        ;

        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v3(self.conn, query, query.len, 0, &stmt, null) != c.SQLITE_OK) {
            logger.err("getCharacterStats prepare: {s}", .{c.sqlite3_errmsg(self.conn)});
            return;
        }
        defer _ = c.sqlite3_finalize(stmt);

        try bindInt(stmt, 1, character.characterId);
        try bindInt(stmt, 2, kind);

        try io.checkCancel();
        while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            try io.checkCancel();

            stats.* = .{
                .statsId = @intCast(c.sqlite3_column_int(stmt, 1)),
                .defense = @intCast(c.sqlite3_column_int(stmt, 2)),
                .attack = @intCast(c.sqlite3_column_int(stmt, 3)),
                .movement = .{
                    .speed = @intCast(c.sqlite3_column_int(stmt, 4)),
                    .direction = @intCast(c.sqlite3_column_int(stmt, 5)),
                },
                .maxHp = @intCast(c.sqlite3_column_int(stmt, 6)),
                .maxMp = @intCast(c.sqlite3_column_int(stmt, 7)),
                .hp = @intCast(c.sqlite3_column_int(stmt, 8)),
                .mp = @intCast(c.sqlite3_column_int(stmt, 9)),
                .regenHp = @intCast(c.sqlite3_column_int(stmt, 10)),
                .regenMp = @intCast(c.sqlite3_column_int(stmt, 11)),
                .str = @intCast(c.sqlite3_column_int(stmt, 12)),
                .int = @intCast(c.sqlite3_column_int(stmt, 13)),
                .dex = @intCast(c.sqlite3_column_int(stmt, 14)),
                .con = @intCast(c.sqlite3_column_int(stmt, 15)),
                .skills = .{
                    .skill0 = @intCast(c.sqlite3_column_int(stmt, 16)),
                    .skill1 = @intCast(c.sqlite3_column_int(stmt, 17)),
                    .skill2 = @intCast(c.sqlite3_column_int(stmt, 18)),
                    .skill3 = @intCast(c.sqlite3_column_int(stmt, 19)),
                },
            };
        }
    }

    fn readBlob(comptime T: type, dest: *T, stmt: ?*c.sqlite3_stmt, col: c_int) void {
        const blob = c.sqlite3_column_blob(stmt, col);
        const len = c.sqlite3_column_bytes(stmt, col);
        if (blob != null and len >= @sizeOf(T)) {
            const ptr: *const T = @ptrCast(@alignCast(blob));
            dest.* = ptr.*;
        }
    }

    fn readBlobBytes(dest: anytype, stmt: ?*c.sqlite3_stmt, col: c_int) void {
        const blob = c.sqlite3_column_blob(stmt, col);
        const len = c.sqlite3_column_bytes(stmt, col);
        if (blob != null and len >= dest.len) {
            const ptr: [*]const u8 = @ptrCast(blob);
            @memcpy(dest, ptr[0..dest.len]);
        }
    }

    fn readItemAttributes(item: *Item, stmt: ?*c.sqlite3_stmt, col: c_int) void {
        const blob = c.sqlite3_column_blob(stmt, col);
        const blobLen = c.sqlite3_column_bytes(stmt, col);
        const attrSize = @sizeOf(@TypeOf(item.attributes));
        if (blob != null and blobLen >= attrSize) {
            const ptr: *const @TypeOf(item.attributes) = @ptrCast(@alignCast(blob));
            item.attributes = ptr.*;
        }
    }

    fn readItemsFromBlob(self: *SqliteDB, comptime S: comptime_int, dest: *[S]Item, stmt: ?*c.sqlite3_stmt, col: c_int) void {
        const ptr = c.sqlite3_column_blob(stmt, col);
        const blobLen = c.sqlite3_column_bytes(stmt, col);
        if (ptr == null or blobLen == 0) {
            dest.* = std.mem.zeroes([S]Item);
            return;
        }
        const blob: []const u8 = @as([*]const u8, @ptrCast(ptr))[0..@intCast(blobLen)];
        const allocator = self.arena.allocator();

        const parsed = std.json.parseFromSlice([]const ItemTuple, allocator, blob, .{}) catch {
            dest.* = std.mem.zeroes([S]Item);
            return;
        };
        defer parsed.deinit();

        dest.* = std.mem.zeroes([S]Item);
        for (parsed.value) |tuple| {
            const slot = tuple.@"0";
            if (slot >= S) continue;
            dest[slot].itemID = tuple.@"1";
            const attrs = tuple.@"2";
            dest[slot].attributes[0] = .{ .index = attrs[0].@"0", .value = attrs[0].@"1" };
            dest[slot].attributes[1] = .{ .index = attrs[1].@"0", .value = attrs[1].@"1" };
            dest[slot].attributes[2] = .{ .index = attrs[2].@"0", .value = attrs[2].@"1" };
        }
    }

    pub fn login(
        self: *SqliteDB,
        io: std.Io,
        username: []const u8,
        password: []const u8,
        account: *Account,
    ) bool {
        self.execMigrations() catch {
            return false;
        };

        const query =
            \\SELECT
            \\  account_id
            \\FROM
            \\  account a
            \\WHERE
            \\  a.username = ? AND a.password = ? AND deleted_at IS NULL
            \\LIMIT 1;
        ;

        var stmt: ?*c.sqlite3_stmt = null;
        const result = c.sqlite3_prepare_v3(self.conn, query, query.len, 0, &stmt, null);
        if (result != c.SQLITE_OK) {
            logger.err("fail to execute login: {s}", .{c.sqlite3_errmsg(self.conn)});
            return false;
        }
        defer _ = c.sqlite3_finalize(stmt);

        if (c.sqlite3_bind_text(stmt, 1, username.ptr, @intCast(username.len), null) != c.SQLITE_OK) {
            logger.err("fail to bind username: {s}", .{c.sqlite3_errmsg(self.conn)});
            return false;
        }

        if (c.sqlite3_bind_text(stmt, 2, password.ptr, @intCast(password.len), null) != c.SQLITE_OK) {
            logger.err("fail to bind password: {s}", .{c.sqlite3_errmsg(self.conn)});
            return false;
        }

        io.checkCancel() catch {
            return false;
        };

        if (c.sqlite3_step(stmt) != c.SQLITE_ROW) {
            return false;
        }

        const accountId: u64 = @intCast(c.sqlite3_column_int64(stmt, 0));
        self.getAccount(io, accountId, account) catch {
            return false;
        };
        return true;
    }

    pub fn signup(
        self: *SqliteDB,
        io: std.Io,
        username: []const u8,
        password: []const u8,
        account: *Account,
    ) bool {
        self.execMigrations() catch return false;
        io.checkCancel() catch return false;

        const query =
            \\INSERT INTO
            \\  account (
            \\      username,
            \\      password,
            \\      email,
            \\      pin_password,
            \\      cargo
            \\  )
            \\VALUES (?, ?, '', '', ?)
        ;

        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v3(self.conn, query, query.len, 0, &stmt, null) != c.SQLITE_OK) {
            logger.err("signup prepare: {s}", .{c.sqlite3_errmsg(self.conn)});
            return false;
        }
        defer _ = c.sqlite3_finalize(stmt);

        if (c.sqlite3_bind_text(stmt, 1, username.ptr, @intCast(username.len), null) != c.SQLITE_OK) {
            logger.err("signup bind username: {s}", .{c.sqlite3_errmsg(self.conn)});
            return false;
        }

        if (c.sqlite3_bind_text(stmt, 2, password.ptr, @intCast(password.len), null) != c.SQLITE_OK) {
            logger.err("signup bind password: {s}", .{c.sqlite3_errmsg(self.conn)});
            return false;
        }

        const allocator = self.arena.allocator();
        var cargoBuf: [128]ItemTuple = undefined;
        var cargoCompacted = compactItems(&account.cargo, &cargoBuf);
        const cargo = bindMarshal(@TypeOf(cargoCompacted), allocator, stmt, 3, &cargoCompacted) catch {
            logger.err("signup bind cargo: {s}", .{c.sqlite3_errmsg(self.conn)});
            return false;
        };
        defer allocator.free(cargo);

        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
            logger.err("signup step: {s}", .{c.sqlite3_errmsg(self.conn)});
            return false;
        }

        account.* = std.mem.zeroes(Account);
        account.accountID = @intCast(c.sqlite3_last_insert_rowid(self.conn));
        account.state = .NEW_ACCOUNT;
        @memcpy(account.name[0..username.len], username);
        @memcpy(account.password[0..password.len], password);
        return true;
    }

    pub fn updateAccount(
        self: *SqliteDB,
        io: std.Io,
        account: *Account,
    ) bool {
        io.checkCancel() catch return false;

        if (!self.updateAccountFields(account)) return false;

        return true;
    }

    fn updateAccountFields(self: *SqliteDB, account: *Account) bool {
        const query =
            \\UPDATE
            \\  account
            \\SET
            \\  gold         = ?,
            \\  state        = ?,
            \\  pin_password = ?,
            \\  cargo        = ?,
            \\  updated_at   = CURRENT_TIMESTAMP
            \\WHERE
            \\  account_id = ?
        ;

        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v3(self.conn, query, query.len, 0, &stmt, null) != c.SQLITE_OK) {
            logger.err("updateAccountFields prepare: {s}", .{c.sqlite3_errmsg(self.conn)});
            return false;
        }
        defer _ = c.sqlite3_finalize(stmt);

        const allocator = self.arena.allocator();
        var stackCargo: [128]ItemTuple = undefined;
        var cargo = compactItems(&account.cargo, &stackCargo);
        const cargoJson = bindMarshal(@TypeOf(cargo), allocator, stmt, 4, &cargo) catch {
            logger.err("updateAccountFields bind cargo: {s}", .{c.sqlite3_errmsg(self.conn)});
            return false;
        };
        defer allocator.free(cargoJson);

        if (c.sqlite3_bind_int(stmt, 1, account.gold) != c.SQLITE_OK) return false;
        if (c.sqlite3_bind_int(stmt, 2, @intFromEnum(account.state)) != c.SQLITE_OK) return false;
        if (c.sqlite3_bind_text(stmt, 3, account.pinPassword[0..], account.pinPassword.len, null) != c.SQLITE_OK) return false;
        if (c.sqlite3_bind_int64(stmt, 5, @intCast(account.accountID)) != c.SQLITE_OK) return false;

        return c.sqlite3_step(stmt) == c.SQLITE_DONE;
    }

    fn upsertCharacter(self: *SqliteDB, account: *Account, slot: u8) !void {
        const char = &account.characters[slot];
        const name = std.mem.sliceTo(char.name[0..], 0);
        const allocator = self.arena.allocator();

        const query =
            \\INSERT INTO character
            \\  (
            \\  account_id,
            \\  slot_id,
            \\  name,
            \\  class,
            \\  level,
            \\  pk_level,
            \\  total_kills,
            \\  current_kills,
            \\  clan,
            \\  guild_id,
            \\  gold,
            \\  experience,
            \\  skill_points,
            \\  position_x,
            \\  position_y,
            \\  soul,
            \\  citizen_info,
            \\  quest,
            \\  attribute_points,
            \\  specials_bonus,
            \\  skills_bonus,
            \\  save_mana,
            \\  skill_bar,
            \\  guild_level,
            \\  tab,
            \\  inventory,
            \\  equipments
            \\)
            \\VALUES
            \\(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            \\ON CONFLICT (account_id, slot_id) WHERE deleted_at IS NULL
            \\DO UPDATE
            \\SET
            \\  class = excluded.class,
            \\  level = excluded.level,
            \\  pk_level = excluded.pk_level,
            \\  total_kills = excluded.total_kills,
            \\  current_kills = excluded.current_kills,
            \\  clan = excluded.clan,
            \\  guild_id = excluded.guild_id,
            \\  gold = excluded.gold,
            \\  experience = excluded.experience,
            \\  skill_points = excluded.skill_points,
            \\  position_x = excluded.position_x,
            \\  position_y = excluded.position_y,
            \\  soul = excluded.soul,
            \\  citizen_info = excluded.citizen_info,
            \\  quest = excluded.quest,
            \\  attribute_points = excluded.attribute_points,
            \\  specials_bonus = excluded.specials_bonus,
            \\  skills_bonus = excluded.skills_bonus,
            \\  save_mana = excluded.save_mana,
            \\  skill_bar = excluded.skill_bar,
            \\  guild_level = excluded.guild_level,
            \\  tab = excluded.tab,
            \\  inventory = excluded.inventory,
            \\  equipments = excluded.equipments
        ;

        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v3(self.conn, query, query.len, 0, &stmt, null) != c.SQLITE_OK) {
            logger.err("updateCharacterFields insert prepare: {s}", .{c.sqlite3_errmsg(self.conn)});
            return;
        }
        defer _ = c.sqlite3_finalize(stmt);

        if (c.sqlite3_bind_int64(stmt, 1, @intCast(account.accountID)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 2, @intCast(slot)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_text(stmt, 3, name.ptr, @intCast(name.len), null) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 4, @intFromEnum(char.class)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 5, @intCast(char.level)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 6, @intCast(char.pkLevel)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 7, @intCast(char.totalKill)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 8, @intCast(char.currentKill)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 9, @intCast(char.clan)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 10, @intCast(char.guildId)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 11, char.gold) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int64(stmt, 12, @intCast(char.exp)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 13, @intCast(char.skillPoints)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 14, @intCast(char.position.x)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 15, @intCast(char.position.y)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 16, @intFromEnum(char.soul)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 17, @as(u8, @bitCast(char.citizenInfo))) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 18, @intCast(char.quest)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 19, @intCast(char.attributePoints)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 20, @intCast(char.specialsBonus)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 21, @intCast(char.skillsBonus)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 22, @intCast(char.saveMana)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_blob(stmt, 23, &char.skillBar, @sizeOf(@TypeOf(char.skillBar)), null) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_int(stmt, 24, @intCast(char.guildLevel)) != c.SQLITE_OK) return;
        if (c.sqlite3_bind_text(stmt, 25, char.tab[0..], char.tab.len, null) != c.SQLITE_OK) return;

        var stackInventory: [64]ItemTuple = undefined;
        var inventory = compactItems(&char.carry, &stackInventory);
        const inventoryJson = bindMarshal([]ItemTuple, allocator, stmt, 26, &inventory) catch return;
        defer allocator.free(inventoryJson);

        var stackEquipments: [16]ItemTuple = undefined;
        var equipments = compactItems(&char.equipments, &stackEquipments);
        const equipmentJson = bindMarshal([]ItemTuple, allocator, stmt, 27, &equipments) catch return;
        defer allocator.free(equipmentJson);

        if (c.sqlite3_step(stmt) == c.SQLITE_DONE) {
            try self.upsertCharacterStats(account, slot);
        } else {
            logger.err("updateCharacterFields insert step: {s}", .{c.sqlite3_errmsg(self.conn)});
        }
    }

    fn bindInt(stmt: ?*c.sqlite3_stmt, idx: i32, value: anytype) !void {
        const T = @TypeOf(value);
        switch (@typeInfo(T)) {
            .int => |int| {
                const result = blk: {
                    if (int.bits <= 32)
                        break :blk c.sqlite3_bind_int(stmt, @intCast(idx), @intCast(value));
                    c.sqlite3_bind_int64(stmt, @intCast(idx), @intCast(value));
                };
                if (result != c.SQLITE_OK) {
                    logger.err("sqlite3: fail to bind int", .{});
                    return error.BindIntFail;
                }
            },
            else => @compileError("bind expected a integer found '" ++ @typeName(T) ++ "'"),
        }
    }

    // Upsert a single character_stats row identified by stats.statsId.
    // On INSERT the new stats_id is written back into stats.statsId.
    fn upsertStats(self: *SqliteDB, charId: u32, kind: u2, stats: *Stats) !void {
        const q =
            \\INSERT INTO
            \\  character_stats
            \\(
            \\  character_id,
            \\  kind,
            \\  defense,
            \\  attack,
            \\  movement_speed,
            \\  movement_direction,
            \\  max_hp,
            \\  max_mp,
            \\  hp,
            \\  mp,
            \\  regen_hp,
            \\  regen_mp,
            \\  str,
            \\  int,
            \\  dex,
            \\  con,
            \\  skill_0,
            \\  skill_1,
            \\  skill_2,
            \\  skill_3
            \\)
            \\VALUES
            \\ (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            \\ON CONFLICT (character_id, kind)
            \\DO UPDATE SET
            \\  defense    = excluded.defense,
            \\  attack     = excluded.attack,
            \\  movement_speed = excluded.movement_speed,
            \\  movement_direction = excluded.movement_direction,
            \\  max_hp     = excluded.max_hp,
            \\  max_mp     = excluded.max_mp,
            \\  hp         = excluded.hp,
            \\  mp         = excluded.mp,
            \\  regen_hp   = excluded.regen_hp,
            \\  regen_mp   = excluded.regen_mp,
            \\  str        = excluded.str,
            \\  int        = excluded.int,
            \\  dex        = excluded.dex,
            \\  con        = excluded.con,
            \\  skill_0    = excluded.skill_0,
            \\  skill_1    = excluded.skill_1,
            \\  skill_2    = excluded.skill_2,
            \\  skill_3    = excluded.skill_3
        ;

        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v3(self.conn, q, q.len, 0, &stmt, null) != c.SQLITE_OK) {
            logger.err("fail to prepare: {s}", .{c.sqlite3_errmsg(self.conn)});
            return error.DatabasePrepareFailed;
        }

        defer _ = c.sqlite3_finalize(stmt);
        try bindInt(stmt, 1, charId);
        try bindInt(stmt, 2, kind);
        try bindInt(stmt, 3, stats.defense);
        try bindInt(stmt, 4, stats.attack);
        try bindInt(stmt, 5, stats.movement.speed);
        try bindInt(stmt, 6, stats.movement.direction);
        try bindInt(stmt, 7, stats.maxHp);
        try bindInt(stmt, 8, stats.maxMp);
        try bindInt(stmt, 9, stats.hp);
        try bindInt(stmt, 10, stats.mp);
        try bindInt(stmt, 11, stats.regenHp);
        try bindInt(stmt, 12, stats.regenMp);
        try bindInt(stmt, 13, stats.str);
        try bindInt(stmt, 14, stats.int);
        try bindInt(stmt, 15, stats.dex);
        try bindInt(stmt, 16, stats.con);
        try bindInt(stmt, 17, stats.skills.skill0);
        try bindInt(stmt, 18, stats.skills.skill1);
        try bindInt(stmt, 19, stats.skills.skill2);
        try bindInt(stmt, 20, stats.skills.skill3);

        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
            logger.err("upsertStats: {s}", .{c.sqlite3_errmsg(self.conn)});
            return error.DatabaseUpsertStatsFailed;
        }
    }

    // Upsert both stats and currentStats for the given character slot.
    // After inserting new rows, character.stats_id / current_stats_id are updated.
    fn upsertCharacterStats(self: *SqliteDB, account: *Account, slot: u8) !void {
        const char = &account.characters[slot];
        try self.upsertStats(char.characterId, 0, &char.stats);
        try self.upsertStats(char.characterId, 1, &char.currentStats);
    }

    pub fn getAccountByUsername(
        self: *SqliteDB,
        io: std.Io,
        username: []const u8,
        account: *Account,
    ) bool {
        self.execMigrations() catch {
            return false;
        };

        const query =
            \\SELECT
            \\  account_id
            \\FROM
            \\  account a
            \\WHERE
            \\  a.username = ?
            \\LIMIT 1;
        ;

        var stmt: ?*c.sqlite3_stmt = null;
        const result = c.sqlite3_prepare_v3(self.conn, query, query.len, 0, &stmt, null);
        if (result != c.SQLITE_OK) {
            logger.err("fail to execute login: {s}", .{c.sqlite3_errmsg(self.conn)});
            return false;
        }
        defer _ = c.sqlite3_finalize(stmt);

        if (c.sqlite3_bind_text(stmt, 1, username.ptr, @intCast(username.len), null) != c.SQLITE_OK) {
            logger.err("fail to bind username: {s}", .{c.sqlite3_errmsg(self.conn)});
            return false;
        }

        io.checkCancel() catch {
            return false;
        };

        if (c.sqlite3_step(stmt) != c.SQLITE_ROW) {
            return false;
        }

        const accountId: u64 = @intCast(c.sqlite3_column_int64(stmt, 0));
        self.getAccount(io, accountId, account) catch {
            return false;
        };
        return true;
    }

    pub fn interface(self: *SqliteDB) Database {
        return Database.from(self);
    }

    pub fn saveCharacter(self: *SqliteDB, io: std.Io, account: *Account, character: *Character) bool {
        io.checkCancel() catch return false;

        self.upsertCharacter(account, character.slotId) catch {
            return false;
        };
        return true;
    }
};
