const std = @import("std");
pub const bindings = @import("lua_binding");
const ServerBinding = @import("binding.zig").ServerBinding;

const Allocator = std.mem.Allocator;
pub const dblib = @import("database");
const Database = dblib.Database;

const domain = @import("core").domain;
pub const network = @import("network");
const Opcode = network.Opcode;

const cwd = std.Io.Dir.cwd();

pub const lua = @import("lua");
const State = lua.State;

const ListFNReg = std.ArrayList(i32);
const EventMap = std.StringHashMap(ListFNReg);

const logger = std.log.scoped(.serverlogic);

pub const Logic = struct {
    arena: std.heap.ArenaAllocator,
    L: *State,
    db: Database,
    io: std.Io,
    events: EventMap,
    server: *network.Server,

    pub fn init(
        allocator: Allocator,
        io: std.Io,
        database: Database,
    ) !*Logic {
        var self = try allocator.create(Logic);

        self.arena = std.heap.ArenaAllocator.init(allocator);
        self.L = try State.init(self.arena.allocator());

        self.db = database;
        self.events = EventMap.init(allocator);
        self.server = undefined;
        self.io = io;

        self.bindingLua();
        return self;
    }

    fn bindingLua(self: *Logic) void {
        const L = self.L;

        bindings.AccountBinding.bind(L);
        bindings.CharacterBinding.bind(L);
        bindings.ItemBinding.bind(L);
        bindings.PacketBinder.bind(L);
        bindings.DatabaseBinding.bind(L);
        bindings.PeerBinding.bind(L);
        ServerBinding.bind(self);
    }

    pub fn setServer(self: *Logic, server: *network.Server) void {
        self.server = server;
    }

    pub fn loadScripts(self: *Logic, io: std.Io) !void {
        const allocator = self.arena.allocator();

        var dir = try cwd.openDir(io, "./scripts", .{ .iterate = true });
        defer dir.close(io);

        var walk = try dir.walk(allocator);
        defer walk.deinit();

        var buffer = std.mem.zeroes([2048]u8);
        while (try walk.next(io)) |file| {
            if (file.kind == .file) {
                if (std.mem.endsWith(u8, file.path, ".lua")) {
                    const size = try file.dir.realPathFile(io, file.basename, buffer[0..]);
                    const path = buffer[0..size];

                    std.log.debug("Load file lua: {s}", .{path});
                    try self.L.doFile(path);
                }
            }
        }
    }

    pub fn bindEvent(self: *Logic, name: []const u8, fnRegIdx: i32) !void {
        if (!self.events.contains(name)) {
            try self.events.put(name, try ListFNReg.initCapacity(self.arena.allocator(), 10));
        }

        if (self.events.getPtr(name)) |events| {
            events.appendAssumeCapacity(fnRegIdx);
        }
    }

    pub fn callEvent(
        self: *Logic,
        name: []const u8,
        peer: *network.Peer,
        packet: *network.PacketInput,
    ) bool {
        const L = self.L;

        if (self.events.get(name)) |events| {
            for (events.items) |regId| {
                L.restoreRegistry(regId);

                bindings.PeerBinding.newUserdata(L, peer);
                bindings.PacketBinder.newUserdata(L, packet);

                const p = L.getTop();
                if (!L.pcall(2, 1)) {
                    const err = L.toString(-1);
                    std.log.err("script error: {s}", .{err});
                }

                logger.info("getTop: {d} {d}", .{ p, L.getTop() });
                L.checkType(-1, .Bool);
                logger.info("boolen: {any}", .{L.toBoolean(-1)});
                return L.toBoolean(-1);
            }
        }
        return true;
    }

    pub fn onReceivePacket(
        self: *Logic,
        peer: *network.Peer,
        message: *network.PacketInput,
    ) bool {
        switch (message.data) {
            .login => {
                if (!self.callEvent("on_login", peer, message)) {
                    return false;
                }
                self.respondLogin(peer);
            },
            else => {},
        }
        return true;
    }

    pub fn deinit(self: *Logic) void {
        const allocator = self.arena.child_allocator;
        defer self.L.deinit();
        defer allocator.destroy(self);
        defer self.arena.deinit();
    }

    pub fn onReceiveMessage(
        ptr: *anyopaque,
        peer: *network.Peer,
        message: *network.PacketInput,
    ) bool {
        const self: *Logic = @ptrCast(@alignCast(ptr));
        return self.onReceivePacket(peer, message);
    }

    // comands
    fn respondLogin(_: *Logic, peer: *network.Peer) void {
        const Respond = network.responses.PacketCharListOutput;

        var packet: Respond = .from(&peer.account, .enterAccount);

        peer.sendPacket(&packet, true) catch |err| {
            logger.err("failed to send login response: {s}", .{@errorName(err)});
        };
        peer.changeState(.Connected);
    }
};
