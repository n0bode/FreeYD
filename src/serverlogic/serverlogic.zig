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

    pub fn init(
        allocator: Allocator,
        server: *network.Server,
        database: Database,
        L: *lua.State,
    ) ServerLogic {
        return .{
            .arena = .init(allocator),
            .dispatcher = .init(allocator),
            .server = server,
            .database = database,
            .state = L,
            .world = .init(allocator),
        };
    }

    fn createMobs(self: *ServerLogic) void {
        var mobTrainer = std.mem.zeroInit(core.domains.Mob, .{
            .mobId = 1001,
        });

        const name = "Mamador";
        @memcpy(mobTrainer.name[0..name.len], name[0..]);
        mobTrainer.equipments[0] = .{
            .itemId = 60,
        };
        mobTrainer.equipments[1] = .{
            .itemId = 130,
        };
        mobTrainer.equipments[2] = .{
            .itemId = 126,
        };
        mobTrainer.equipments[3] = .{
            .itemId = 127,
        };
        mobTrainer.equipments[4] = .{
            .itemId = 128,
        };
        mobTrainer.equipments[5] = .{
            .itemId = 129,
        };
        mobTrainer.equipments[6] = .{
            .itemId = 986,
        };

        _ = self.world.createMob(2124, 2042, &mobTrainer) catch {
            logger.err("failed to create mob", .{});
            return;
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
        return self.dispatcher.dispatch(self.state, peer, message);
    }

    pub fn loadScripts(self: *ServerLogic, io: std.Io) !void {
        self.bindLuaTypes();
        self.createMobs();
        try loader.loadScripts(self.arena.allocator(), io, self.state);
    }

    fn bindLuaTypes(self: *ServerLogic) void {
        bindings.AccountBinding.bind(self.state);
        bindings.CharacterBinding.bind(self.state);
        bindings.PacketBinder.bind(self.state);
        bindings.DatabaseBinding.bind(self.state);
        bindings.PeerBinding.bind(self.state);
        bindings.MobBinding.bind(self.state);
        bindings.WorldBinding.bind(self.state);
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
