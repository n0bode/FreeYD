const std = @import("std");
pub const bindings = @import("lua_binding");
const ServerBinding = @import("server_binding.zig").ServerBinding;

const Allocator = std.mem.Allocator;
pub const dblib = @import("database");
const Database = dblib.Database;

const domain = @import("core").domain;
pub const network = @import("network");
const responses = network.responses;
const Opcode = network.Opcode;

const cwd = std.Io.Dir.cwd();
const parsers = @import("parsers.zig");

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
        bindings.PacketBinder.bind(L);
        bindings.DatabaseBinding.bind(L);
        bindings.PeerBinding.bind(L);
        bindings.MobBinding.bind(L);
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

                    try self.L.doFile(path);
                }
            }
        }
    }

    pub fn bindEvent(self: *Logic, name: []const u8, fnRegIdx: i32) !void {
        const allocator = self.arena.allocator();
        if (!self.events.contains(name)) {
            const owned_name = try allocator.dupe(u8, name);
            try self.events.put(owned_name, try ListFNReg.initCapacity(self.arena.allocator(), 10));
        }

        if (self.events.getPtr(name)) |events| {
            events.appendAssumeCapacity(fnRegIdx);
        }
    }

    pub fn callEvent(
        self: *Logic,
        name: []const u8,
        peer: *network.Peer,
        packet: ?*network.PacketInput,
    ) bool {
        const L = self.L;

        if (self.events.get(name)) |events| {
            for (events.items) |regId| {
                L.restoreRegistry(regId);

                if (L.isNil(-1)) {
                    std.log.err("script error: function is nil", .{});
                    L.pop(1);
                    return false;
                }

                bindings.PeerBinding.newUserdata(L, peer);
                if (packet) |pack| {
                    bindings.PacketBinder.newUserdata(L, pack);
                } else {
                    L.pushNil();
                }

                if (!L.pcall(2, 1)) {
                    const err = L.toString(-1);
                    std.log.err("script error: {s}", .{err});
                    L.pop(1);
                    return false;
                }

                const result = !L.isNil(-1) and L.toBoolean(-1);
                L.pop(1);

                if (!result) return false;
            }
        }
        return true;
    }

    pub fn onReceivePacket(
        self: *Logic,
        peer: *network.Peer,
        message: ?*network.PacketInput,
    ) bool {
        if (message == null) {
            //disconnected
            _ = self.callEvent("on_disconnected", peer, null);
            return true;
        }

        switch (message.?.data) {
            .login => {
                return self.respondLogin(
                    peer,
                    self.callEvent("on_login", peer, message),
                );
            },
            .pinPassword => {
                return self.respondPin(
                    peer,
                    self.callEvent("on_pinpassword", peer, message),
                );
            },
            .charCreate => {
                return self.respondCharCreate(
                    peer,
                    self.callEvent("on_create_char", peer, message),
                );
            },
            .charDelete => {
                return self.respondCharDelete(
                    peer,
                    self.callEvent("on_delete_char", peer, message),
                );
            },
            .enterWorld => {
                return self.respondEnterWorld(
                    peer,
                    self.callEvent("on_spawn_char", peer, message),
                );
            },
            .updateAttribute => {
                return self.respondUpdateAttribute(
                    peer,
                    self.callEvent("on_update_attributes", peer, message),
                );
            },
            .action => {
                // TODO: how to do send all information to all
                return self.respondAction(
                    peer,
                    self.callEvent("on_mob_action", peer, message),
                );
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
        message: ?*network.PacketInput,
    ) bool {
        const self: *Logic = @ptrCast(@alignCast(ptr));
        return self.onReceivePacket(peer, message);
    }

    // comands
    fn respondLogin(_: *Logic, peer: *network.Peer, result: bool) bool {
        if (result) {
            const Respond = network.responses.PacketCharListOutput;

            var packet: Respond = .from(&peer.account, .enterAccount);
            peer.sendPacket(&packet, true) catch |err| {
                logger.err("failed to send login response: {s}", .{@errorName(err)});
            };
            peer.changeState(.Connected);
            // keep-connection
            return true;
        }
        // close-connection
        return false;
    }

    fn respondPin(_: *Logic, peer: *network.Peer, result: bool) bool {
        if (!result) {
            peer.sendCode(@intFromEnum(Opcode.PIN_FAIL)) catch {
                // close-connection: fail to send code
                return false;
            };
        }
        return true;
    }

    fn respondCharCreate(_: *Logic, peer: *network.Peer, result: bool) bool {
        if (!result) {
            peer.sendCode(@intFromEnum(Opcode.CHAR_CREATE_FAIL)) catch {
                return false;
            };
        } else {
            var pack = responses.PacketCharCreateOutput{
                .header = .{
                    .operationCode = @intFromEnum(Opcode.CHAR_CREATED),
                    .time = std.time.epoch.unix,
                },
                .characters = .from(&peer.account),
            };

            peer.sendPacket(&pack, true) catch {
                return false;
            };
        }
        return true;
    }

    fn respondCharDelete(_: *Logic, peer: *network.Peer, result: bool) bool {
        if (result) {
            var pack = responses.PacketCharDeleteOutput{
                .header = .{
                    .operationCode = @intFromEnum(Opcode.CHAR_DELETED),
                },
                .characters = .from(&peer.account),
            };

            peer.sendPacket(&pack, true) catch {
                return false;
            };
        }
        return true;
    }

    fn respondEnterWorld(_: *Logic, peer: *network.Peer, result: bool) bool {
        if (result) {
            const char = &peer.account.characters[@intCast(peer.account.charSelected)];
            var pack = responses.PacketCharSpawn{
                .header = .{
                    .operationCode = @intFromEnum(Opcode.CHAR_SELECTED),
                },
                .character = .from(@intCast(peer.peerID), char),
                .position = .{
                    .x = char.position.x,
                    .y = char.position.y,
                },
            };

            peer.sendPacket(&pack, true) catch |err| {
                logger.err("failed to send char spawn response: {s}", .{@errorName(err)});
                return false;
            };
            return true;
        }
        return false;
    }

    fn respondUpdateAttribute(_: *Logic, peer: *network.Peer, result: bool) bool {
        _ = peer;
        _ = result;
        return true;
        // TODO: need receive mob id to send stats
        //if (result) {
        //    var pack = responses.PacketUpdateStats{
        //        .header = .{
        //            .operationCode = @intFromEnum(Opcode.UPDATE_STATS),
        //        },
        //        .stats = .fro
        //        .attributes = .from(&peer.account),
        //    };

        //    peer.sendPacket(&pack, true) catch |err| {
        //        logger.err("failed to send set attribute response: {s}", .{@errorName(err)});
        //        return false;
        //    };
        //    return true;
        //}
        //return false;
    }

    fn respondAction(_: *Logic, peer: *network.Peer, result: bool) bool {
        _ = peer;
        _ = result;
        return true;
    }

    pub fn execCommand(self: *Logic, command: []const u8, L: *State) bool {
        if (std.mem.startsWith(u8, command, "spawn_mob")) {
            var packet = parsers.parseToPacketSpawn(L) catch |err| {
                logger.err("failed to parse lua to packet: {any}", .{err});
                return false;
            };

            for (self.server.peers) |pp| {
                if (pp) |peer| {
                    if (peer.state == .Connected) {
                        peer.sendPacket(&packet, true) catch |err| {
                            logger.err("failed to send spawn mob packet: {s}", .{@errorName(err)});
                            continue;
                        };
                    }
                }
            }
            return true;
        }
        return true;
    }
};
