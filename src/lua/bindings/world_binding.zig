const bindings = @import("binding.zig");
const core = bindings.core;
const std = @import("std");

const World = core.World;
const Point = core.Point;
const Object = core.Object;
const WorldItem = core.domains.WorldItem;
const MobBinding = bindings.MobBinding;

const lua = bindings.lua;
const utils = @import("utils.zig");

const mapper = utils.MapperStructPtr(World);

pub const WorldBinding = @This();
pub const PointBinding = utils.MapperStructPtr(Point);
pub const WorldItemBinding = utils.MapperStructPtr(WorldItem);

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
    mapper.bind(L);
    PointBinding.bind(L);
    WorldItemBinding.bind(L);

    utils.bindFunctions(L, metatableName, &.{
        .{
            .name = "list_items",
            .value = .{
                .func = .{ .func = lua__list_items },
            },
        },
        .{
            .name = "each_mobs",
            .value = .{
                .func = .{ .func = lua__each_mobs },
            },
        },
        .{
            .name = "each_mobs_in_area",
            .value = .{
                .func = .{ .func = lua__each_mobs_in_area },
            },
        },
        .{
            .name = "spawn_mob",
            .value = .{
                .func = .{ .func = lua__spawn_mob },
            },
        },
        .{
            .name = "move",
            .value = .{
                .func = .{ .func = lua__move },
            },
        },
        .{
            .name = "remove",
            .value = .{
                .func = .{ .func = lua__remove },
            },
        },
        .{
            .name = "get_position",
            .value = .{
                .func = .{ .func = lua__get_position },
            },
        },
    });
}

fn lua__list_items(L: *lua.State) i32 {
    _ = L;
    return 0;
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

    self.tree.listInArea(.{
        .x = 0,
        .y = 0,
        .width = 4096,
        .height = 4096,
    }, &ptr, wrap_eachMob);

    L.removeRegistry(ptr.fnIndex);
    return 0;
}

fn lua__spawn_mob(L: *lua.State) i32 {
    const self: *World = mapper.toUserdata(L, 1) orelse {
        L.pushNil();
        return 1;
    };

    const x = L.checkInteger(i16, 2);
    const y = L.checkInteger(i16, 3);

    L.checkType(4, .Userdata);
    const mob = MobBinding.toUserdata(L, 4) orelse {
        L.pushNil();
        return 1;
    };

    _ = self.spawnMob(mob, x, y) catch {
        L.pushBool(false);
        return 1;
    };
    L.pushBool(true);
    return 1;
}

fn lua__move(L: *lua.State) i32 {
    const self: *World = mapper.toUserdata(L, 1) orelse {
        L.pushNil();
        return 1;
    };

    const id = L.checkInteger(u16, 2);
    const x = L.checkInteger(i16, 3);
    const y = L.checkInteger(i16, 4);

    self.move(id, x, y) catch {
        L.pushBool(false);
        return 1;
    };
    L.pushBool(true);
    return 1;
}

fn lua__remove(L: *lua.State) i32 {
    const self: *World = mapper.toUserdata(L, 1) orelse {
        L.pushNil();
        return 1;
    };

    const id = L.checkInteger(u16, 2);

    self.remove(id) catch {
        L.pushBool(false);
        return 1;
    };
    L.pushBool(true);
    return 1;
}

const pFnLua = struct {
    L: *lua.State,
    fnIndex: i32,
};

fn call_eachItem(L: *lua.State, fnIndex: i32, point: *Point, item: *core.domains.WorldItem) void {
    L.restoreRegistry(fnIndex);
    if (!L.isType(-1, .Function)) {
        L.pop(1);
        return;
    }
    WorldItemBinding.newUserdata(L, item);
    PointBinding.newUserdata(L, point);
    if (!L.pcall(2, 0)) {
        std.log.err("failed to call list_items: {s}", .{L.toString(-1)});
        L.pop(1);
        return;
    }
}

fn wrap_eachMob(ptr: *anyopaque, point: *Point) void {
    const self: *pFnLua = @ptrCast(@alignCast(ptr));

    const obj: *Object = @fieldParentPtr("point", point);
    switch (obj.entity) {
        .npc => |npc| call_eachMob(self.L, self.fnIndex, point, npc.mob),
        .mob => |mob| call_eachMob(self.L, self.fnIndex, point, mob),
        .item => |item| call_eachWorldItemInArea(self.L, self.fnIndex, point, item),
    }
}

fn call_eachMob(L: *lua.State, fnIndex: i32, point: *Point, mob: *core.Mob) void {
    L.restoreRegistry(fnIndex);
    if (!L.isType(-1, .Function)) {
        L.pop(1);
        return;
    }

    MobBinding.newUserdata(L, mob);
    PointBinding.newUserdata(L, point);
    L.pushBool(false);
    if (!L.pcall(3, 0)) {
        std.log.err("failed to call eachMob: {s}", .{L.toString(-1)});
        L.pop(1);
        return;
    }
}

fn call_eachWorldItemInArea(L: *lua.State, fnIndex: i32, point: *Point, item: *WorldItem) void {
    L.restoreRegistry(fnIndex);
    if (!L.isType(-1, .Function)) {
        L.pop(1);
        return;
    }

    WorldItemBinding.newUserdata(L, item);
    PointBinding.newUserdata(L, point);
    L.pushBool(true);
    if (!L.pcall(3, 0)) {
        std.log.err("failed to call eachMob (item): {s}", .{L.toString(-1)});
        L.pop(1);
        return;
    }
}

fn lua__each_mobs_in_area(L: *lua.State) i32 {
    const self: *core.World = mapper.toUserdata(L, 1) orelse {
        L.pushNil();
        return 1;
    };

    L.checkType(2, .Table);
    L.getField(2, "x");
    L.checkType(-1, .Number);
    const x = L.checkInteger(i64, -1);
    L.pop(1);

    L.getField(2, "y");
    L.checkType(-1, .Number);
    const y = L.checkInteger(i64, -1);
    L.pop(1);

    L.getField(2, "width");
    L.checkType(-1, .Number);
    const width = L.checkInteger(u64, -1);
    L.pop(1);

    L.getField(2, "height");
    L.checkType(-1, .Number);
    const height = L.checkInteger(u64, -1);
    L.pop(1);

    L.checkType(3, .Function);
    var ptr = pFnLua{
        .L = L,
        .fnIndex = L.saveRegistry(3),
    };

    self.tree.listInArea(.{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
    }, &ptr, wrap_eachMob);

    L.removeRegistry(ptr.fnIndex);
    return 0;
}

fn lua__get_position(L: *lua.State) i32 {
    const self: *core.World = mapper.toUserdata(L, 1) orelse {
        L.pushNil();
        return 1;
    };

    const id = L.checkInteger(u16, 2);
    const point = self.indexes.get(id) orelse {
        L.pushNil();
        return 1;
    };

    L.newTable();
    L.pushInteger(point.point.x);
    L.setField(-2, "x");
    L.pushInteger(point.point.y);
    L.setField(-2, "y");
    return 1;
}
