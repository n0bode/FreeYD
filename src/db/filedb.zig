const std = @import("std");
const Account = @import("core").domains.Account;

pub const FileDB = @This();

pub fn login(
    io: std.Io,
    account: *Account,
    username: []const u8,
    password: []const u8,
) bool {
    var buffer: [48]u8 = undefined;
    const path = std.fmt.bufPrint(buffer[0..], "./db/accounts/{s}.db", .{username}) catch {
        return false;
    };

    std.Io.Dir.cwd().createDirPath(io, "./db/accounts") catch {};
    const file = std.Io.Dir.cwd().openFile(io, path, .{ .mode = .read_only }) catch {
        return false;
    };
    defer file.close(io);

    var bAccount = std.mem.asBytes(account);
    var readerStream = file.reader(io, bAccount[0..]);
    const reader = &readerStream.interface;

    _ = reader.take(@sizeOf(Account)) catch {
        return false;
    };
    if (!std.mem.eql(u8, account.password, password)) {
        return false;
    }
    return true;
}
