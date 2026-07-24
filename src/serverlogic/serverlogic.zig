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
                    self.callMobInteract(peer, req.mobId) catch {
                        logger.err("Error calling mob interact", .{});
                    };
                },
                else => {},
            }
        }

        return self.dispatcher.dispatch(self.state, peer, message);
    }

    fn callMobInteract(self: *ServerLogic, peer: *network.Peer, mobId: u32) !void {
        for (self.world.npcs.items) |*npc| {
            if (npc.npc.id == mobId) {
                const L = self.state;
                L.restoreRegistry(npc.fnInteract);
                if (L.isFunction(-1)) {
                    bindings.NPCBinding.newUserdata(L, &npc.npc);
                    bindings.PeerBinding.newUserdata(L, peer);
                    if (!L.pcall(2, 0)) {
                        logger.err("result lua on_interact: {s}", .{L.toString(-1)});
                        return error.LuaError;
                    }
                } else {
                    logger.warn("on_mob_interact is not a function", .{});
                }
                L.pop(1);
                return;
            }
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
            io.sleep(.fromMilliseconds(1000 / 24), .real) catch {
                logger.warn("canceled wait", .{});
                return;
            };
            const serverTime = self.server.getServerTime();

            self.updateNPCs(serverTime);
        }
    }

    fn updateNPCs(self: *ServerLogic, serverTime: u64) void {
        const L = self.state;
        for (self.world.npcs.items) |*npc| {
            L.restoreRegistry(npc.fnUpdate);
            bindings.NPCBinding.newUserdata(L, &npc.npc);
            L.pushInteger(@intCast(serverTime));
            if (!L.pcall(2, 1)) {
                logger.err("NPC({s}).on_update: failed {s}", .{ npc.npc.name, L.toString(-1) });
            }

            if (L.isNil(-1) or (L.isBoolean(-1) and L.toBoolean(-1))) {
                npc.npc.updatedAt = serverTime;
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
