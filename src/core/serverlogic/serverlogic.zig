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

    pub fn deinit(self: *Logic) void {
        const allocator = self.arena.child_allocator;
        defer self.L.deinit();
        defer allocator.destroy(self);
        defer self.arena.deinit();
    }


    // comands
    fn respondLogin(_: *Logic, peer: *network.Peer, result: bool) bool {
        if (result) {
            const Respond = network.responses.PacketCharListOutput;

            var packet: Respond = .from(&peer.account, .enterAccount);
            peer.sendPacket(&packet) catch |err| {
                logger.err("failed to send login response: {s}", .{@errorName(err)});
            };
            // keep-connection
            return true;
        }
        // close-connection
        return false;
    }

    fn respondPin(_: *Logic, peer: *network.Peer, result: bool) bool {
        if (!result) {
            peer.sendCode(@intFromEnum(Opcode.PIN_FAIL)) catch {
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

            peer.sendPacket(&pack) catch {
                return false;
            };
        }
        return true;
    }

    fn respondEnterWorld(_: *Logic, peer: *network.Peer, result: bool) bool {
        _ = peer;
        _ = result;
        return true;
        // if (result) {
        //     const char = &peer.account.characters[@intCast(peer.account.charSelected)];
        //     var pack = responses.PacketCharSpawn{
        //         .header = .{
        //             .operationCode = @intFromEnum(Opcode.CHAR_SELECTED),
        //         },
        //         .character = .from(@intCast(peer.peerID), char),
        //         .position = .{
        //             .x = char.position.x,
        //             .y = char.position.y,
        //         },
        //     };

        //     peer.sendPacket(&pack, true) catch |err| {
        //         logger.err("failed to send char spawn response: {s}", .{@errorName(err)});
        //         return false;
        //     };
        //     return true;
        // }
        // return false;
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

    pub fn execCommand(self: *Logic, command: []const u8, L: *State) !void {
        for (self.server.peers) |pp| {
            if (pp) |peer| {
                if (peer.state == .Playing) {
                    _ = bindings.PeerCommands.dispatch(peer, command, L);
                }
            }
        }
    }
};
