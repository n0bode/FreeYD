const std = @import("std");
const utils = @import("utils.zig");
const bindings = @import("binding.zig");
const lua = bindings.lua;

const Spawned = bindings.core.Spawned;
const Position = bindings.domain.Position;

const mapper = utils.MapperStructPtr(Spawned);
pub const SpawnedBinding = @This();

pub const metatableName = mapper.metatableName;

pub fn toUserdata(L: *lua.State, idx: i32) ?*Spawned {
    return (L.toUserdata(*Spawned, idx) orelse {
        return null;
    }).*;
}

pub fn newUserdata(L: *lua.State, spawned: *Spawned) void {
    const ptr = L.newUserdata(*Spawned);
    ptr.* = spawned;
    _ = L.getMetatableByName(metatableName);
    _ = L.setMetatable(-2);
}

pub fn bind(L: *lua.State) void {
    _ = L.newMetatable(metatableName);
    L.pushFunction(lua__index);
    L.setField(-2, "__index");
}

const vtable = std.StaticStringMap(lua.Function).initComptime(.{
    .{ "mob", lua__mob },
    .{ "position", lua__position },
    .{ "start_position", lua__start_position },
});

fn lua__index(L: *lua.State) i32 {
    const key = L.toString(2);
    const func = vtable.get(key) orelse {
        L.pushNil();
        return 1;
    };
    return func(L);
}

fn lua__position(L: *lua.State) i32 {
    const self = toUserdata(L, 1) orelse {
        L.pushNil();
        return 1;
    };

    var pos: Position = .{
        .x = @intCast(self.point.x & 0xFFF),
        .y = @intCast(self.point.y & 0xFFF),
    };
    bindings.PositionBinding.newUserdataCopy(L, &pos);
    return 1;
}

fn lua__start_position(L: *lua.State) i32 {
    const self = toUserdata(L, 1) orelse {
        L.pushNil();
        return 1;
    };
    bindings.PositionBinding.newUserdataCopy(L, &self.startPosition);
    return 1;
}

fn lua__mob(L: *lua.State) i32 {
    const self = toUserdata(L, 1) orelse {
        L.pushNil();
        return 1;
    };

    std.log.info("mob_id = {d}", .{self.tick});
    if (self.entity == .mob) {
        bindings.MobBinding.newUserdata(L, self.entity.mob);
        return 1;
    }
    L.pushNil();
    return 1;
}
