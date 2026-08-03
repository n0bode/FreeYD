const std = @import("std");

pub const network = @import("network");
pub const lua = @import("lua");
pub const bindings = @import("lua_binding");
pub const core = @import("core");
const loader = @import("loader.zig");

const Database = @import("database").Database;
const Allocator = std.mem.Allocator;
const Dispatcher = @import("dispatcher.zig").Dispatcher;
const ServerBinding = @import("server_binding/server_binding.zig").ServerBinding;
const GroundItem = core.domains.GroundItem;
const Mob = core.Mob;
const Spawned = core.Spawned;

const logger = std.log.scoped(.serverlogic);
pub const ServerLogic = struct {
    arena: std.heap.ArenaAllocator,
    server: *network.Server,
    dispatcher: Dispatcher,
    database: Database,
    state: *lua.State,
    world: core.World,
    maxPlayers: usize,
    group: std.Io.Group,
    lastUpdateTime: u64 = 0,

    pub fn init(
        allocator: Allocator,
        server: *network.Server,
        database: Database,
        maxPlayers: u16,
        maxMobs: u16,
        maxItems: u16,
    ) !ServerLogic {
        return .{
            .arena = .init(allocator),
            .dispatcher = .init(allocator),
            .server = server,
            .database = database,
            .state = try .init(allocator),
            .world = try core.World.init(allocator, maxPlayers, maxMobs, maxItems),
            .maxPlayers = maxPlayers,
            .group = .init,
        };
    }

    pub fn deinit(self: ServerLogic) void {
        self.arena.deinit();
    }

    fn onReceiveMessage(
        self: *ServerLogic,
        peer: *network.Peer,
        message: ?*network.PacketInput,
    ) bool {
        if (message) |input| {
            switch (input.data) {
                .interactionMob => |req| {
                    self.callInteractMob(peer, req.mobId);
                },
                .interactGroundItem => |req| {
                    self.callInteractGroundItem(peer, @intCast(req.itemId));
                },
                .attackOne => |req| {
                    logger.info("peer {d} attack one {any}", .{ peer.peerId, req });
                },
                .login => |req| {
                    logger.info("peer {d} login {any}", .{ peer.peerId, req });
                },
                else => {},
            }
        }
        return self.dispatcher.dispatch(self.state, peer, message);
    }

    fn callInteractGroundItem(self: *ServerLogic, peer: *network.Peer, itemId: u16) void {
        const obj = self.world.get(itemId) catch {
            return;
        };

        switch (obj.entity) {
            .item => |item| {
                execGroundItemInteract(self, item, peer);
            },
            else => logger.warn("itemId {d} is not a GroundItem", .{itemId}),
        }
    }

    fn execGroundItemInteract(self: *ServerLogic, item: *GroundItem, peer: *network.Peer) void {
        const L = self.state;
        L.restoreRegistry(item.onInteract);
        if (!L.isFunction(-1)) {
            logger.warn("GroundItem({d}): interacter is not a function", .{item.itemId});
            L.pop(1);
            return;
        }
        bindings.PeerBinding.newUserdata(L, peer);
        bindings.GroundItemBinding.newUserdata(L, item);
        if (!L.pcall(2, 0)) {
            logger.err("GroundItem({d}): on_interact failed => {s}", .{ item.itemId, L.toString(-1) });
            L.pop(1);
        }
    }

    fn callInteractMob(self: *ServerLogic, peer: *network.Peer, mobId: u16) void {
        const obj = self.world.get(mobId) catch {
            return;
        };

        switch (obj.entity) {
            .mob => |mob| {
                execMobInteract(self, obj, mob, peer);
            },
            else => logger.warn("mobId {d} is not an NPC", .{mobId}),
        }
    }

    fn execMobInteract(self: *ServerLogic, spawned: *Spawned, mob: *Mob, peer: *network.Peer) void {
        const L = self.state;
        if (spawned.onInteract) |onInteract| {
            L.restoreRegistry(onInteract);
            if (!L.isFunction(-1)) {
                logger.warn("NPC({s}): interacter is not a function", .{mob.name});
                L.pop(1);
                return;
            }

            bindings.SpawnedBinding.newUserdata(L, spawned);
            bindings.PeerBinding.newUserdata(L, peer);
            if (!L.pcall(2, 0)) {
                logger.err("Mob({s})[{d}]: on_interact failed => {s}", .{ mob.name, mob.mobId, L.toString(-1) });
                L.pop(1);
            }
        } else {
            logger.warn("NPC({s}): interacter is not set", .{mob.name});
            return;
        }
    }

    pub fn start(self: *ServerLogic, io: std.Io) !void {
        self.bindLuaTypes();
        try loader.loadScripts(self.arena.allocator(), io, self.state);

        try self.server.listen(io);
        self.lastUpdateTime = self.server.getServerTime();
        try self.group.concurrent(io, ServerLogic.loopServer, .{ self, io });
    }

    pub fn cancel(self: *ServerLogic, io: std.Io) void {
        self.server.stop(io);

        self.group.cancel(io);
        self.group.await(io) catch {
            logger.err("failed to wait stop server", .{});
        };
    }

    fn loopServer(self: *ServerLogic, io: std.Io) void {
        const tickRate: i64 = 1000 / 12;
        while (self.server.state == .running) {
            const serverTime = self.server.getServerTime();
            const deltaTime = serverTime - self.lastUpdateTime;
            // 24 per second

            io.sleep(.fromMilliseconds(tickRate), .real) catch {
                logger.warn("canceled wait", .{});
                return;
            };

            self.execMobUpdate(deltaTime);
            self.lastUpdateTime = serverTime;
        }
    }

    fn execMobUpdate(self: *ServerLogic, deltaTime: u64) void {
        const L = self.state;
        const diff = L.getTop();
        if (L.getTop() != 0) {
            logger.err("could not execute, top has: {d}", .{diff});
            L.pop(diff);
            return;
        }

        var iter = self.world.indexes.valueIterator();
        while (iter.next()) |ptr| {
            const npc = ptr.*;
            if (npc.entity != .mob) continue;
            const mob = npc.entity.mob;

            const count = npc.countTick -| deltaTime;
            if (count > 0) {
                npc.countTick = count;
                continue;
            }

            npc.countTick += npc.tick;
            if (npc.onUpdate) |update| {
                L.restoreRegistry(update);
                if (!L.isFunction(-1)) {
                    L.pop(1);
                    logger.warn("NPC({s}): on_update is not a function", .{mob.name});
                    continue;
                }

                bindings.SpawnedBinding.newUserdata(L, npc);
                if (!L.pcall(1, 0)) {
                    logger.err("NPC({s}).on_update: failed {s}", .{ mob.name, L.toString(-1) });
                    L.pop(1);
                    continue;
                }
            }
        }
    }

    fn bindLuaTypes(self: *ServerLogic) void {
        bindings.AccountBinding.bind(self.state);
        bindings.CharacterBinding.bind(self.state);
        bindings.PacketBinder.bind(self.state);
        bindings.DatabaseBinding.bind(self.state);
        bindings.PeerBinding.bind(self.state);
        bindings.MobBinding.bind(self.state);
        bindings.WorldBinding.bind(self.state);
        bindings.RTreeBinding.bind(self.state, self.arena.allocator());
        bindings.NPCBinding.bind(self.state);
        bindings.SpawnedBinding.bind(self.state);
        ServerBinding.bind(self);
    }
};

pub fn onReceiveMessage(
    ptr: *anyopaque,
    peer: *network.Peer,
    message: ?*network.PacketInput,
) bool {
    const self: *ServerLogic = @ptrCast(@alignCast(ptr));
    return self.onReceiveMessage(peer, message);
}
