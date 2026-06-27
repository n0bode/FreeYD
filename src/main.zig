const std = @import("std");
const buiiltin = @import("builtin");
const posix = std.posix;
const Init = std.process.Init;

const Server = @import("server/server.zig").Server;
const ParseArgs = @import("parsearg/parsearg.zig").ParseArgs;

var running = std.atomic.Value(bool).init(true);

const isWindows = buiiltin.os.tag == .windows;

fn handleSignal(sig: posix.SIG) callconv(.c) void {
    _ = sig;
    std.debug.print("ok", .{});
    running.store(false, .release);
}

fn captureSignal() void {
    if (!isWindows) {
        var sigConfig: posix.Sigaction = .{
            .handler = .{ .handler = handleSignal },
            .mask = undefined,
            .flags = 0,
        };

        posix.sigaction(.INT, &sigConfig, null);
        posix.sigaction(.TERM, &sigConfig, null);
    }
    // TODO: signal for WINDOWS
}

const WrapConfig = struct {
    config: Server.ServerConfig,

    fn init() WrapConfig {
        return .{
            .config = .default(),
        };
    }

    fn setPort(self: *WrapConfig, newValue: []const u8) !void {
        self.config.port = std.fmt.parseInt(u16, newValue, 10) catch |err| {
            std.log.err("PORT is invalid, must be a number", .{});
            return err;
        };
    }

    fn setHost(self: *WrapConfig, newValue: []const u8) !void {
        self.config.host = newValue;
    }
};

const ParserConfig = ParseArgs(WrapConfig);

pub fn main(init: Init) !void {
    var config: WrapConfig = .init();
    const args: ParserConfig = .init(&[_]ParserConfig.Argument{
        .{
            .name = "host",
            .handler = WrapConfig.setHost,
        },
        .{
            .name = "port",
            .handler = WrapConfig.setPort,
        },
    });

    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();

    const allocator = arena.allocator();

    try args.parse(init.minimal.args.iterate(), &config);
    captureSignal();

    var server: Server = try Server.init(allocator, config.config);
    try server.run(init.io);

    std.debug.print("running server on {s}:{d}\n", .{ config.config.host, config.config.port });
    const delay = std.Io.Duration.fromMilliseconds(10 * 3);
    std.debug.print(">> Ctrl+C: to kill server\n", .{});
    while (running.load(.monotonic)) {
        try init.io.sleep(delay, .awake);
    }

    std.debug.print("shutting...\n", .{});
    server.stop(init.io);
}
