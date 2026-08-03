const std = @import("std");
const buiiltin = @import("builtin");
const posix = std.posix;
const Init = std.process.Init;

const ParseEnv = @import("utils").EnvParse;
const PacketFromClient = @import("network").packet.PacketFromClient;
const Server = @import("network").Server;
const Peer = @import("network").Peer;

const ParseArgs = @import("utils").ParseArgs;
//const FileDB = @import("filedb").FileDB;
const SQLiteDB = @import("sqlitedb").SqliteDB;
const Account = @import("core").domains.Account;
const serverlogic = @import("serverlogic");
const ServerLogic = serverlogic.ServerLogic;
const lua = @import("lua");

var running = std.atomic.Value(bool).init(true);

const logger = std.log.scoped(.main);

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

        // INTERRUPT
        posix.sigaction(.INT, &sigConfig, null);

        // SIGTERM
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

    // setup signal system
    try args.parse(init.minimal.args.iterate(), &config);
    captureSignal();

    const MAX_PLAYERS = ParseEnv.getEnv(u16, init.environ_map, "MAX_PLAYERS", 1000);
    const MAX_MOBS = ParseEnv.getEnv(u16, init.environ_map, "MAX_MOBS", 10_000);
    const MAX_ITEMS = ParseEnv.getEnv(u16, init.environ_map, "MAX_ITEMS", 1000);

    var arena = std.heap.ArenaAllocator.init(init.gpa);
    const allocator = arena.allocator();
    defer arena.deinit();

    var database = try SQLiteDB.init(allocator, "db/freeyd.db");
    const interface = database.interface();
    var account: Account = std.mem.zeroes(Account);
    _ = interface.signup(init.io, "root", "senha", &account);
    _ = interface.login(init.io, "root", "senha", &account);

    var server: Server = try Server.init(allocator, config.config);

    var serverLogic = try ServerLogic.init(
        allocator,
        &server,
        database.interface(),
        MAX_PLAYERS,
        MAX_MOBS,
        MAX_ITEMS,
    );

    defer serverLogic.deinit();

    server.setOnReceivePeerMessage(serverlogic.onReceiveMessage, &serverLogic);
    logger.info("running server on {s}:{d}\n", .{ config.config.host, config.config.port });
    try serverLogic.start(init.io);

    std.debug.print(">> Ctrl+C: to kill server\n", .{});
    while (running.load(.monotonic)) {
        try init.io.sleep(.fromMilliseconds(10), .awake);
    }
    std.debug.print("shutting...\n", .{});
    serverLogic.cancel(init.io);
    logger.info("server shutdowned", .{});
}
