const std = @import("std");
const Allocator = std.mem.Allocator;
const domains = @import("domains/domains.zig");
const MobQuadTree = @import("core.zig").MobQuadTree;

const MobPoint = MobQuadTree.Point;
const Mob = domains.Mob;

pub const World = struct {
    arena: std.heap.ArenaAllocator,

    mobsInWorld: MobQuadTree,
    pub fn init(child_allocator: Allocator) World {
        return World{
            .arena = .init(child_allocator),
            // map size
            .mobsInWorld = MobQuadTree.init(4096),
        };
    }

    pub fn deinit(self: World) void {
        self.mobsInWorld.deinit();
        self.arena.deinit();
    }

    pub fn createMob(self: *World, x: i16, y: i16, mobBase: *Mob) !*MobQuadTree.Point {
        const allocator = self.arena.allocator();

        var point = try allocator.create(MobPoint);
        point.x = @intCast(x);
        point.y = @intCast(y);
        point.data = mobBase.*;

        if (!try self.mobsInWorld.insert(point)) {
            allocator.destroy(point);
            return error.MobOutOfMap;
        }
        return point;
    }

    /// allocate um result array with mob found
    pub fn listMobInAreaAlloc(self: *World, allocator: Allocator, x: i16, y: i16, w: u16, h: u16) ![]*MobQuadTree.Point {
        const rect = MobQuadTree.Rect{
            .x = @intCast(x),
            .y = @intCast(y),
            .width = @intCast(w),
            .height = @intCast(h),
        };
        return self.mobsInWorld.listInAreaAlloc(allocator, rect);
    }
};
