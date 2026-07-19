const bindings = @import("binding.zig");
const core = bindings.core;
const std = @import("std");

const World = core.World;
const SpawnedMob = core.SpawnedMob;

const SpawnedMobBinding = bindings.SpawnedMobBinding;
const MobBinding = bindings.MobBinding;

const lua = bindings.lua;
const utils = @import("utils.zig");

const mapper = utils.LuaMapperStruct(World);

pub const WorldBinding = @This();

pub const metatableName = mapper.metatableName;

pub fn toUserdata(L: *lua.State, idx: i32) ?*World {
    return mapper.toUserdata(L, idx);
}

pub fn newUserdata(L: *lua.State, mob: *World) void {
    mapper.newUserdata(L, mob);
}

pub fn getMetatable(L: *lua.State) void {
    L.getMetatableByName(mapper.metatableName);
}

pub fn bind(L: *lua.State) void {
    SpawnedMobBinding.bind(L);
    mapper.bind(L);

    utils.bindFunctions(L, metatableName, &.{
        .{
            .name = "each_mobs",
            .value = .{
                .func = .{ .func = lua__each_mobs },
            },
        },
        .{
            .name = "create_mob",
            .value = .{
                .func = .{ .func = lua__create_mob },
            },
        },
        .{
            .name = "move_mob",
            .value = .{
                .func = .{ .func = lua__move_mob },
            },
        },
    });
}

fn lua__each_mobs(L: *lua.State) i32 {
    const self: *core.World = mapper.toUserdata(L, 1) orelse {
        L.pushNil();
        return 1;
    };

    L.checkType(2, .Function);
    var ptr = pFnLua{
        .L = L,
        .fnIndex = L.saveRegistry(2),
    };

    self.mobsInWorld.listInArea(.{
        .x = 0,
        .y = 0,
        .width = 4096,
        .height = 4096,
    }, &ptr, eachMob);

    L.removeRegistry(ptr.fnIndex);
    return 0;
}

fn lua__create_mob(L: *lua.State) i32 {
    const self: *World = mapper.toUserdata(L, 1) orelse {
        L.pushNil();
        return 1;
    };

    const x: i16 = @intCast(L.checkInteger(2));
    const y: i16 = @intCast(L.checkInteger(3));

    L.checkType(4, .Userdata);
    const mob = MobBinding.toUserdata(L, 4) orelse {
        L.pushNil();
        return 1;
    };

    const spawned = self.createMob(x, y, mob) catch {
        L.pushNil();
        return 1;
    };
    SpawnedMobBinding.newUserdata(L, spawned);
    return 1;
}

fn lua__move_mob(L: *lua.State) i32 {
    const self: *World = mapper.toUserdata(L, 1) orelse {
        L.pushNil();
        return 1;
    };

    L.checkType(2, .Userdata);
    const mob = SpawnedMobBinding.toUserdata(L, 2) orelse {
        L.pushNil();
        return 1;
    };

    const x: i16 = @intCast(L.checkInteger(3));
    const y: i16 = @intCast(L.checkInteger(4));

    _ = self.moveMob(x, y, mob) catch {
        L.pushNil();
        return 1;
    };
    return 1;
}

const pFnLua = struct {
    L: *lua.State,
    fnIndex: i32,
};

fn eachMob(ptr: *anyopaque, point: *SpawnedMob) void {
    const self: *pFnLua = @ptrCast(@alignCast(ptr));

    const L = self.L;
    L.restoreRegistry(self.fnIndex);
    SpawnedMobBinding.newUserdata(L, point);
    if (L.isNil(-1)){
        std.log.err("mob is null", .{});
        return;
    }
    if (!L.pcall(1, 0)) {
        std.log.err("failed to call eachMob: {s}", .{L.toString(-1)});
        L.pushNil();
        return;
    }
}
