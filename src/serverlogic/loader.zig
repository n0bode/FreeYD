const std = @import("std");

const serverlogic = @import("serverlogic.zig");
const lua = serverlogic.lua;
const cwd = std.Io.Dir.cwd();

const Allocator = std.mem.Allocator;

pub fn loadScripts(
    allocator: Allocator,
    io: std.Io,
    L: *lua.State,
) !void {
    var dir = try cwd.openDir(io, "./scripts", .{ .iterate = true });
    defer dir.close(io);

    var walk = try dir.walk(allocator);
    defer walk.deinit();

    var buffer: [2048]u8 = undefined;
    @memset(buffer[0..], 0);

    while (try walk.next(io)) |file| {
        if (file.kind == .file) {
            if (std.mem.endsWith(u8, file.path, ".lua")) {
                const size = try file.dir.realPathFile(io, file.basename, buffer[0..]);
                const path = buffer[0..size];

                std.log.debug("LOADING FILE: {s}", .{path});
                try L.doFile(path);
            }
        }
    }
}
