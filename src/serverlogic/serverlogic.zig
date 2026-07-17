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
        try loader.loadScripts(self.arena.allocator(), io, self.state);
    }

    fn bindLuaTypes(self: *ServerLogic) void {
        bindings.AccountBinding.bind(self.state);
        bindings.CharacterBinding.bind(self.state);
        bindings.PacketBinder.bind(self.state);
        bindings.DatabaseBinding.bind(self.state);
        bindings.PeerBinding.bind(self.state);
        bindings.MobBinding.bind(self.state);
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
