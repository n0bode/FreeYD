const std = @import("std");
const zon = std.zon;
const db = @import("database");
const Database = db.Database;
const Account = db.Account;
const CharacterClass = db.CharacterClass;
const Item = db.Item;

const cwd = std.Io.Dir.cwd();

const logger = std.log.scoped(.fileDB);

pub const FileDB = struct {
    path: []const u8,
    rand: std.Random.DefaultPrng,
    writerBuffer: [2048]u8,

    pub fn init(path: []const u8) FileDB {
        return .{
            .path = path,
            .rand = .init(std.time.epoch.unix),
            .writerBuffer = undefined,
        };
    }

    pub fn login(
        self: *FileDB,
        io: std.Io,
        username: []const u8,
        password: []const u8,
        account: *Account,
    ) bool {
        var buffer: [1024]u8 = undefined;
        const path = std.fmt.bufPrint(buffer[0..], "{s}/{s}.db", .{ self.path, username }) catch {
            return false;
        };

        const file = cwd.openFile(io, path, .{ .mode = .read_only }) catch {
            return false;
        };
        defer file.close(io);

        var bAccount = std.mem.asBytes(account);
        var readerA = file.reader(io, bAccount[0..]);
        const reader = &readerA.interface;

        _ = reader.take(@sizeOf(Account)) catch {
            return false;
        };

        const passwordSaved = std.mem.sliceTo(&account.password, 0);
        if (!std.mem.eql(u8, password, passwordSaved)) {
            return false;
        }
        return true;
    }

    pub fn signup(
        self: *FileDB,
        io: std.Io,
        username: []const u8,
        password: []const u8,
        account: *Account,
    ) bool {
        account.* = std.mem.zeroInit(Account, .{
            .accountID = self.rand.random().intRangeAtMost(u64, 1, 2500),
            .state = .NEW_ACCOUNT,
        });

        @memcpy(account.name[0..username.len], username);
        @memcpy(account.password[0..password.len], password);

        return self.persistAccount(io, account, true);
    }

    pub fn updateAccount(
        self: *FileDB,
        io: std.Io,
        account: *Account,
    ) bool {
        return self.persistAccount(io, account, false);
    }

    pub fn getAccountByUsername(
        self: *FileDB,
        io: std.Io,
        username: []const u8,
        account: *Account,
    ) bool {
        var buffer: [1024]u8 = undefined;
        const path = std.fmt.bufPrint(buffer[0..], "{s}/{s}.db", .{ self.path, username }) catch {
            return false;
        };

        const file = cwd.openFile(io, path, .{ .mode = .read_only }) catch {
            return false;
        };
        defer file.close(io);

        var bAccount = std.mem.asBytes(account);
        var readerA = file.reader(io, bAccount[0..]);
        const reader = &readerA.interface;

        _ = reader.take(@sizeOf(Account)) catch {
            return false;
        };

        return true;
    }

    pub fn interface(self: *FileDB) Database {
        return Database.from(self);
    }

    fn persistAccount(self: *FileDB, io: std.Io, account: *Account, exclusive: bool) bool {
        var buffer: [1024]u8 = undefined;
        const username = std.mem.sliceTo(account.name[0..], 0);
        const path = std.fmt.bufPrint(buffer[0..], "{s}/{s}.db", .{ self.path, username }) catch {
            return false;
        };

        cwd.createDirPath(io, self.path) catch {};
        // exclusive creation fails if the account already exists
        const file = cwd.createFile(io, path, .{
            .exclusive = exclusive,
        }) catch |err| {
            logger.err("error to create file: {s}", .{@errorName(err)});
            return false;
        };
        defer file.close(io);

        var writerA = file.writer(io, self.writerBuffer[0..]);
        const writer = &writerA.interface;

        writer.writeStruct(account.*, .little) catch {
            return false;
        };
        writer.flush() catch {};

        return true;
    }
};
