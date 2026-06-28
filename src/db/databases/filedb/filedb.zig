const std = @import("std");
const zon = std.zon;
const db = @import("database");
const Database = db.Database;
const Account = db.Account;
const Item = db.Item;

const cwd = std.Io.Dir.cwd();

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
        var buffer: [1024]u8 = undefined;
        const path = std.fmt.bufPrint(buffer[0..], "{s}/{s}.db", .{ self.path, username }) catch {
            return false;
        };

        cwd.createDirPath(io, self.path) catch {};
        // exclusive creation fails if the account already exists
        const file = cwd.createFile(io, path, .{ .exclusive = true }) catch |err| {
            std.debug.print("erro = {s}\n", .{@errorName(err)});
            return false;
        };
        defer file.close(io);

        account.* = Account{
            .accountID = self.rand.next(),
            .cargo = [_]Item{Item.zero()} ** 128,
            .charInfo = 0,
            .charSelected = 0,
            .gold = 0,
            .ipAddr = [_]u8{0} ** 16,
            .keys = [_]u8{0} ** 16,
            .mode = .unset,
            .name = [_]u8{0} ** 16,
            .password = [_]u8{0} ** 16,
            .pinBits = .empty,
            .server = 0,
        };

        @memcpy(account.name[0..username.len], username);
        @memcpy(account.password[0..password.len], password);

        var writerA = file.writer(io, self.writerBuffer[0..]);
        const writer = &writerA.interface;

        writer.writeStruct(account.*, .native) catch {
            return false;
        };
        writer.flush() catch {};

        return true;
    }

    pub fn interface(self: *FileDB) Database {
        return Database.from(self);
    }
};
