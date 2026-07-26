const binding = @import("../binding.zig");
const lua = binding.lua;
const std = @import("std");
// max 4 items per node
const RTree = binding.utils.RTree(i32, 4);

pub const RTreeBinding = @This();

pub const metatableName = "mt_RTreeLua";

const Ctx = struct {
    allocator: std.mem.Allocator,
};

pub fn bind(L: *lua.State, allocator: std.mem.Allocator) void {
    const ptr = allocator.create(Ctx) catch {
        return;
    };
    ptr.* = .{
        .allocator = allocator,
    };

    L.newLib("rtree", &.{
        .{
            .name = "new",
            .value = .{
                .func = .{ .func = lua__new_rtree, .userdata = ptr },
            },
        },
    });

    _ = L.newMetatable(metatableName);
    L.pushValue(-1); // metatable
    L.setField(-2, "__index"); // metatable.__index = metatable
    L.setFuncs(&.{
        .{
            .name = "insert",
            .value = .{
                .func = .{ .func = lua__rtree_insert },
            },
        },
        .{
            .name = "remove",
            .value = .{
                .func = .{ .func = lua__rtree_insert },
            },
        },
        .{
            .name = "query_at",
            .value = .{
                .func = .{ .func = lua__rtree_query_at },
            },
        },
    });
}

fn toRect(L: *lua.State, idx: i32) RTree.Rect {
    L.checkType(idx, .Table);

    L.getField(idx, "x");
    const x = L.checkInteger(i64, -1);
    L.pop(1);

    L.getField(idx, "y");
    const y = L.checkInteger(i64, -1);
    L.pop(1);

    L.getField(idx, "w");
    const w = L.checkInteger(i64, -1);
    L.pop(1);

    L.getField(idx, "h");
    const h = L.checkInteger(i64, -1);
    L.pop(1);
    return .{ .x = x, .y = y, .w = w, .h = h };
}

fn lua__new_rtree(L: *lua.State) i32 {
    const ctx: *Ctx = L.toUserdata(Ctx, L.upValueIndex(2)) orelse {
        return L.panic("failed to new rtree");
    };

    var tree: RTree = .init(ctx.allocator);
    if (!L.isNil(1)) {
        L.checkType(1, .Table);
        L.pushNil();
        while (L.next(1)) {
            // value -1
            // key -2
            //
            const top = L.getTop();
            const rect = toRect(L, top - 1);
            const value = L.saveRegistry(-1);
            tree.insert(rect, value) catch {
                return L.panic("failed to new rtree");
            };
            L.pop(1);
        }
    }

    const ptr: *RTree = L.newUserdata(RTree);
    ptr.* = tree;
    L.getMetatableByName(metatableName);
    _ = L.setMetatable(-2);

    return 1;
}

fn lua__rtree_insert(L: *lua.State) i32 {
    const qt: *RTree = L.toUserdata(RTree, 1) orelse {
        L.pushNil();
        return 1;
    };

    const x = L.checkInteger(i64, 2);
    const y = L.checkInteger(i64, 3);
    const w = L.checkInteger(i64, 4);
    const h = L.checkInteger(i64, 5);

    L.pushValue(4);
    const reg = L.saveRegistry(-1);

    qt.insert(.{ .x = x, .y = y, .w = w, .h = h }, reg) catch {
        return L.throw("failed to insert");
    };

    return 0;
}

fn lua__rtree_query_at(L: *lua.State) i32 {
    const qt: *RTree = L.toUserdata(RTree, 1) orelse {
        return L.panic("must be method");
    };

    const x = L.checkInteger(i64, 2);
    const y = L.checkInteger(i64, 3);
    L.pushValue(4);
    L.pushBool(qt.queryAt(@intCast(x), @intCast(y), L, fn_query_at));
    return 1;
}

fn fn_query_at(ptr: *anyopaque, _: RTree.Rect, data: i32) void {
    const L: *lua.State = @ptrCast(@alignCast(ptr));

    L.restoreRegistry(data);
    if (!L.pcall(1, 0)) {
        std.log.err("err: {s}", .{L.toString(-1)});
        _ = L.panic("failed to call function");
    }
}
