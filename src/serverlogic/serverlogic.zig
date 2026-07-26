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

    pub fn init(
        allocator: Allocator,
        server: *network.Server,
        database: Database,
        L: *lua.State,
        maxPlayers: usize,
    ) !ServerLogic {
        return .{
            .arena = .init(allocator),
            .dispatcher = .init(allocator),
            .server = server,
            .database = database,
            .state = L,
            .world = try core.World.init(allocator, maxPlayers),
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
                    self.callInteract(peer, req.mobId);
                },
                else => {},
            }
        }
        return self.dispatcher.dispatch(self.state, peer, message);
    }

    fn callInteract(self: *ServerLogic, peer: *network.Peer, mobId: u16) void {
        const obj = self.world.get(mobId) catch {
            return;
        };

        switch (obj.entity) {
            .npc => |npc| {
                execNPCInteract(self, npc, peer);
            },
            else => logger.warn("mobId {d} is not an NPC", .{mobId}),
        }
    }

    fn execNPCInteract(self: *ServerLogic, npc: *core.NPC, peer: *network.Peer) void {
        const L = self.state;
        L.restoreRegistry(npc.regOnInteract);
        if (!L.isFunction(-1)) {
            logger.warn("NPC({s}): interacter is not a function", .{npc.name});
            L.pop(1);
            return;
        }
        bindings.NPCBinding.newUserdata(L, npc);
        bindings.PeerBinding.newUserdata(L, peer);
        if (!L.pcall(2, 0)) {
            logger.err("NPC({s}): on_interact failed => {s}", .{ npc.name, L.toString(-1) });
            L.pop(1);
        }
    }

    pub fn start(self: *ServerLogic, io: std.Io) !void {
        self.bindLuaTypes();
        try loader.loadScripts(self.arena.allocator(), io, self.state);

        try self.server.listen(io);
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
        while (self.server.state == .running) {
            // 24 per second
            io.sleep(.fromMilliseconds(1000), .real) catch {
                logger.warn("canceled wait", .{});
                return;
            };
            const serverTime = self.server.getServerTime();

            self.execNPCUpdate(serverTime);
        }
    }

    fn execNPCUpdate(self: *ServerLogic, serverTime: u64) void {
        const L = self.state;
        std.debug.assert(L.getTop() == 0);
        for (self.world.npcs.items) |*npc| {
            L.restoreRegistry(npc.regOnUpdate);
            if (!L.isFunction(-1)) {
                L.pop(1);
                logger.warn("NPC({s}): on_update is not a function", .{npc.name});
                continue;
            }

            bindings.NPCBinding.newUserdata(L, npc);
            L.pushInteger(@intCast(serverTime));
            if (!L.pcall(2, 1)) {
                logger.err("NPC({s}).on_update: failed {s}", .{ npc.name, L.toString(-1) });
                L.pop(1);
                continue;
            }

            if (L.isNil(-1) or (L.isBoolean(-1) and L.toBoolean(-1))) {
                npc.updatedAt = serverTime;
            }
            L.pop(1);
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
