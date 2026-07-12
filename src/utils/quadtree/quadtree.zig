const std = @import("std");
const Allocator = std.mem.Allocator;
const BoundedArray = @import("boundedarray.zig").BoundedArray;

pub fn QuadTree(comptime T: anytype, capacity: comptime_int) type {
    return struct {
        const Self = @This();

        pub const Point = struct {
            x: i64,
            y: i64,
            data: T,
        };

        pub const Rect = struct {
            x: i64 = 0,
            y: i64 = 0,
            width: u64 = 0,
            height: u64 = 0,

            fn left(self: Rect) i64 {
                return self.x;
            }

            fn right(self: Rect) i64 {
                return self.x + @as(i64, @intCast(self.width));
            }

            fn bottom(self: Rect) i64 {
                return self.y;
            }

            fn top(self: Rect) i64 {
                return self.y + @as(i64, @intCast(self.height));
            }

            pub fn contains(self: Rect, point: Point) bool {
                return point.x >= self.left() and point.x <= self.right() and
                    point.y >= self.bottom() and point.y <= self.top();
            }

            pub fn intersects(self: Rect, other: *Rect) bool {
                return other.right() > self.left() and other.left() < self.right() and
                    other.top() > self.bottom() and other.bottom() < self.top();
            }
        };

        pub const Node = struct {
            lt: ?*Node = null,
            rt: ?*Node = null,
            lb: ?*Node = null,
            rb: ?*Node = null,

            bounds: Rect,
            items: BoundedArray(*Point, capacity) = .{},

            pub fn init(rect: Rect) Node {
                return .{ .bounds = rect };
            }

            pub fn isFull(self: Node) bool {
                return self.items.len >= capacity;
            }

            pub fn push(self: *Node, pos: *Point) bool {
                if (!self.bounds.contains(pos.*)) return false;
                self.items.push(pos) catch {
                    return false;
                };

                std.debug.print("Point({d}, {d}), inserted at: ({d},{d})[{d}, {d}]\n", .{ pos.x, pos.y, self.bounds.x, self.bounds.y, self.bounds.width, self.bounds.height });
                return true;
            }
        };

        root: Node,
        arena: std.heap.ArenaAllocator,
        pub fn init(allocator: Allocator, size: u64) Self {
            const bound = Rect{
                .x = 0,
                .y = 0,
                .height = size,
                .width = size,
            };

            return Self{
                .arena = std.heap.ArenaAllocator.init(allocator),
                .root = .init(bound),
            };
        }

        pub fn deinit(self: Self) void {
            self.arena.deinit();
        }

        fn subdivide(self: *Self, node: *Node) !void {
            const allocator = self.arena.allocator();
            const nodes = try allocator.alloc(Node, 4);

            const w2 = node.bounds.width / 2;
            const h2 = node.bounds.height / 2;

            const posL = node.bounds.x;
            const posR = node.bounds.x + @as(i64, @intCast(w2));

            const posB = node.bounds.y;
            const posT = node.bounds.y + @as(i64, @intCast(h2));

            nodes[0] = .init(Rect{
                .x = posL,
                .y = posB,
                .width = w2,
                .height = h2,
            });
            node.lb = &nodes[0];

            nodes[1] = .init(Rect{
                .x = posL,
                .y = posT,
                .width = w2,
                .height = h2,
            });
            node.lt = &nodes[1];

            nodes[2] = .init(Rect{
                .x = posR,
                .y = posB,
                .width = w2,
                .height = h2,
            });
            node.rb = &nodes[2];

            nodes[3] = .init(Rect{
                .x = posR,
                .y = posT,
                .width = w2,
                .height = h2,
            });
            node.rt = &nodes[3];

            while (node.items.pop()) |item| {
                for (nodes) |*subnode| {
                    if (subnode.push(item)) {
                        break;
                    }
                }
            }
        }

        pub fn insert(self: *Self, pos: *Point) !bool {
            var node = &self.root;
            while (node.bounds.contains(pos.*)) {
                if (!node.isFull() and node.lt == null) {
                    return node.push(pos);
                }

                // subidivde
                if (node.isFull() and node.lt == null) {
                    std.debug.print("subdivide\n", .{});
                    try self.subdivide(node);
                    std.debug.print("end subdivide\n", .{});
                }

                const nodes = [_]?*Node{ node.lt, node.rb, node.rt, node.lb };
                for (nodes) |region| {
                    if (region) |subnode| {
                        if (subnode.bounds.contains(pos.*)) {
                            node = subnode;
                            break;
                        }
                    }
                }
            }
            return false;
        }

        const FNEachFound = *const fn (userdata: *anyopaque, point: *Point) void;

        fn searchDeep(self: *Self, rect: *Rect, node: *Node, userdata: *anyopaque, func: FNEachFound) void {
            if (!node.bounds.intersects(rect)) {
                return;
            }

            if (node.items.len > 0) {
                for (0..node.items.len) |iPoint| {
                    const point = (node.items.get(iPoint) catch {
                        continue;
                    }).*;
                    func(userdata, point);
                }
                return;
            }

            if (node.lb) |subnode| {
                self.searchDeep(rect, subnode, userdata, func);
            }

            if (node.lt) |subnode| {
                self.searchDeep(rect, subnode, userdata, func);
            }

            if (node.rb) |subnode| {
                self.searchDeep(rect, subnode, userdata, func);
            }

            if (node.rt) |subnode| {
                self.searchDeep(rect, subnode, userdata, func);
            }
        }

        pub fn listInArea(self: *Self, rect: Rect, userdata: *anyopaque, func: FNEachFound) void {
            // Warn: recusive, need calculate stack usage
            self.searchDeep(@constCast(&rect), &self.root, userdata, func);
        }

        pub fn listInAreaAlloc(self: *Self, allocator: Allocator, rect: Rect) ![]*Point {
            const size = self.countInArea(rect);
            const arr = try allocator.alloc(*Point, size);
            self.listInArea(rect, @ptrCast(arr), fnArrayAlloc);
            return arr;
        }

        pub fn countInArea(self: *Self, rect: Rect) usize {
            var count: usize = 0;
            self.listInArea(rect, &count, fnCountingArea);
            return count;
        }

        fn fnCountingArea(ptr: *anyopaque, _: *Point) void {
            const count: *usize = @ptrCast(@alignCast(ptr));
            count.* = count.* + 1;
        }

        fn fnArrayAlloc(ptr: *anyopaque, p: *Point) void {
            const array: []*Point = @ptrCast(@alignCast(ptr));
            array[array.len - 1] = p;
        }
    };
}

test "QuadTree - insert" {
    const allocator = std.testing.allocator_instance.allocator();

    const Q32 = QuadTree(i32, 1);

    var qt = Q32.init(allocator, 100);
    defer qt.deinit();

    var point1 = Q32.Point{ .x = 25, .y = 25, .data = 0 };
    var point2 = Q32.Point{ .x = 75, .y = 25, .data = 1 };
    var point3 = Q32.Point{ .x = 25, .y = 75, .data = 2 };
    var point4 = Q32.Point{ .x = 75, .y = 75, .data = 3 };
    var point5 = Q32.Point{ .x = 90, .y = 90, .data = 4 };

    try std.testing.expect(try qt.insert(&point1));
    try std.testing.expect(try qt.insert(&point2));
    try std.testing.expect(try qt.insert(&point3));
    try std.testing.expect(try qt.insert(&point4));
    try std.testing.expect(try qt.insert(&point5));

    try std.testing.expect(qt.root.lb != null);
    try std.testing.expectEqual(qt.root.lb.?.items.len, 1);

    try std.testing.expect(qt.root.rb != null);
    try std.testing.expect(qt.root.lt != null);

    try std.testing.expect(qt.root.rb != null);
    try std.testing.expect(qt.root.rt.?.lb != null);
    try std.testing.expectEqual(1, qt.root.rt.?.lb.?.items.len);

    try std.testing.expect(qt.root.rt.?.rt != null);
    try std.testing.expectEqual(1, qt.root.rt.?.rt.?.items.len);
}

test "QuadTree - list" {
    const allocator = std.testing.allocator_instance.allocator();

    const Q32 = QuadTree(i32, 1);

    var qt = Q32.init(allocator, 100);
    defer qt.deinit();

    var point1 = Q32.Point{ .x = 25, .y = 25, .data = 0 };
    var point2 = Q32.Point{ .x = 75, .y = 25, .data = 1 };
    var point3 = Q32.Point{ .x = 25, .y = 75, .data = 2 };
    var point4 = Q32.Point{ .x = 75, .y = 75, .data = 3 };
    var point5 = Q32.Point{ .x = 90, .y = 90, .data = 4 };

    try std.testing.expect(try qt.insert(&point1));
    try std.testing.expect(try qt.insert(&point2));
    try std.testing.expect(try qt.insert(&point3));
    try std.testing.expect(try qt.insert(&point4));
    try std.testing.expect(try qt.insert(&point5));

    const Case = struct {
        count: usize = 0,
        area: Q32.Rect,
        expected: []*Q32.Point,

        fn assert(self: *@This()) !void {
            try std.testing.expectEqual(self.expected.len, self.count);
        }
    };

    const FN = struct {
        pub fn case(ptr: *anyopaque, point: *Q32.Point) void {
            var data: *Case = @ptrCast(@alignCast(ptr));
            std.debug.print("found point: {d} {d}\n", .{ point.x, point.y });
            for (data.expected) |expec| {
                if (expec == point) {
                    data.count = data.count + 1;
                }
            }
        }
    };

    var cases = [_]Case{
        // all
        .{
            .area = .{ .x = 0, .y = 0, .width = 100, .height = 100 },
            .expected = @constCast(&[_]*Q32.Point{ &point1, &point2, &point3, &point4, &point5 }),
        },
        // only q4 (q4)
        .{
            .area = .{ .x = 50, .y = 50, .width = 25, .height = 25 },
            .expected = @constCast(&[_]*Q32.Point{&point4}),
        },
        // horizontal capture
        .{
            .area = .{ .x = 0, .y = 0, .width = 74, .height = 25 },
            .expected = @constCast(&[_]*Q32.Point{ &point1, &point2 }),
        },
    };

    for (&cases) |*case| {
        qt.listInArea(case.area, case, FN.case);
        try case.assert();

        try std.testing.expectEqual(case.count, qt.countInArea(case.area));
    }
}
