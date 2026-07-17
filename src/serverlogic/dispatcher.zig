const std = @import("std");
const logger = std.log.scoped(.Dispatcher);

const serverlogic = @import("serverlogic.zig");
const network = serverlogic.network;
const lua = serverlogic.lua;
const bindings = serverlogic.bindings;

const Allocator = std.mem.Allocator;
const EventMap = std.StringHashMap(i32);
const Opcodes = network.packet.client.OpcodeFromClient;

const nameEventsMap = std.EnumArray(Opcodes, ?[]const u8).init(.{
    // add more packet here
    .unknown = null,
    .ping = null,
    .updateAttribute = null,
    .login = "on_login",
    .pinPassword = "on_pinpassword",
    .createChar = "on_create_char",
    .deleteChar = "on_delete_char",
    .spawnChar = "on_spawn_char",
    .motionMob = "on_motion_mob",
    .moveItem = "on_move_item",
    .chatWhisper = "on_chat_whisper",
});

pub const Dispatcher = struct {
    events: EventMap,

    pub fn init(allocator: Allocator) Dispatcher {
        return .{
            .events = EventMap.init(allocator),
        };
    }

    pub fn deinit(self: Dispatcher) void {
        self.events.deinit();
    }

    pub fn bind(self: *Dispatcher, eventName: []const u8, luaRegId: i32) !void {
        self.events.put(eventName, luaRegId) catch |err| {
            logger.err("failed to bind event: {s}", .{@errorName(err)});
            return err;
        };
    }

    pub fn dispatch(
        self: Dispatcher,
        L: *lua.State,
        peer: *network.Peer,
        packet: ?*network.PacketInput,
    ) bool {
        const message = packet orelse {
            //disconnected
            return self.callEvent("on_disconnected", L, peer, null) or true;
        };

        const eventName = nameEventsMap.get(message.data) orelse {
            return true;
        };

        return self.callEvent(eventName, L, peer, message);
    }

    fn callEvent(
        self: Dispatcher,
        eventName: []const u8,
        L: *lua.State,
        peer: *network.Peer,
        message: ?*network.PacketInput,
    ) bool {
        const funcRegId = self.events.get(eventName) orelse {
            return true;
        };

        L.restoreRegistry(funcRegId);
        if (L.isNil(-1)) {
            return true;
        }

        bindings.PeerBinding.newUserdata(L, peer);
        if (message) |packet| {
            bindings.PacketBinder.newUserdata(L, packet);
        } else {
            L.pushNil();
        }
        if (!L.pcall(2, 1)) {
            logger.err("failed to call event {s}: {s}", .{ eventName, L.toString(-1) });
        }

        if (L.getLuaType(-1) == .Bool)
            return L.toBoolean(-1);
        return true;
    }
};
