const std = @import("std");

const BoundedArray = @import("../utils.zig").BoundedArray;

pub fn RTree(comptime T: anytype, capacity: usize) type {
    return struct {
        pub const FnQueryResult = fn (ptr: *anyopaque, rect: Rect, data: T) void;

        pub const Rect = struct {
            x: i64 = 0,
            y: i64 = 0,
            w: i64 = 0,
            h: i64 = 0,

            pub fn right(self: Rect) i64 {
                return self.x + self.w;
            }

            pub fn top(self: Rect) i64 {
                return self.y + self.h;
            }

            pub fn contains(self: Rect, point: *T) bool {
                return point.x >= self.x and point.x <= self.right() and
                    point.y >= self.y and point.y <= self.top();
            }

            pub fn containsRect(self: Rect, other: *Rect) bool {
                return other.x >= self.x and other.right() <= self.right() and
                    other.y >= self.y and other.top() <= self.top();
            }

            pub fn intersects(self: Rect, other: *Rect) bool {
                return self.x <= other.right() and self.right() >= other.x and
                    self.y <= other.top() and self.top() >= other.y;
            }

            pub fn getArea(self: Rect) i64 {
                return self.w * self.h;
            }

            pub fn unionBounds(self: Rect, other: Rect) Rect {
                const x1 = @min(self.x, other.x);
                const y1 = @min(self.y, other.y);
                const x2 = @max(self.right(), other.right());
                const y2 = @max(self.top(), other.top());
                return Rect{ .x = x1, .y = y1, .w = x2 - x1, .h = y2 - y1 };
            }
        };

        pub const Node = struct {
            bounds: Rect,
            data: ?T = null,
            // must last item
            items: BoundedArray(*Node, capacity),

            pub fn init(bounds: Rect) Node {
                return Node{
                    .bounds = bounds,
                    .items = .init(),
                };
            }

            pub fn insert(self: *Node, allocator: std.mem.Allocator, node: *Node) !void {
                self.bounds = self.bounds.unionBounds(node.bounds);
                if (!self.items.isFull()) {
                    try self.items.push(node);
                    return;
                } else {
                    const div = @divFloor(capacity, 2);
                    const ptrs = try allocator.alloc(Node, div);
                    for (0..div) |si| {
                        const parent = &ptrs[si];

                        const start = (si) * div;
                        const end = if (si == div - 1) capacity else (si + 1) * div;
                        const slice = self.items.items[start..end];

                        parent.* = .init(slice[0].bounds);
                        for (slice) |child| {
                            try parent.insert(allocator, child);
                        }
                    }
                    self.bounds = ptrs[0].bounds;
                    self.items.clear();
                    for (ptrs) |*parent| {
                        try self.insert(allocator, parent);
                    }
                }

                for (self.items.toSlice()) |child| {
                    if (child.bounds.intersects(&node.bounds)) {
                        try child.insert(allocator, node);
                        return;
                    }
                }
                try self.insert(allocator, node);
            }

            fn query(self: *Node, rect: *Rect, ud: *anyopaque, func: FnQueryResult) bool {
                if (!self.bounds.intersects(rect)) {
                    return false;
                }

                if (self.data) |data| {
                    func(ud, rect.*, data);
                    return true;
                }

                var found = false;
                for (self.items.toSlice()) |child| {
                    found = found or child.query(rect, ud, func);
                }
                return found;
            }

            fn print(self: *Node, deep: i32) void {
                if (self.items.len == 0) {
                    std.debug.print("[{d}][{d},{d},{d},{d}]", .{ deep, self.bounds.x, self.bounds.y, self.bounds.w, self.bounds.h });
                    std.debug.print("{any}\n", .{self.data});
                    return;
                }

                for (self.items.toSlice()) |child| {
                    std.debug.print("[{d}]({d},{d},{d},{d})", .{ deep, self.bounds.x, self.bounds.y, self.bounds.w, self.bounds.h });
                    child.print(deep + 1);
                }
            }
        };

        const Self = @This();
        root: ?*Node = null,
        arena: std.heap.ArenaAllocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .arena = std.heap.ArenaAllocator.init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.arena.deinit();
        }

        pub fn insert(self: *Self, rect: Rect, data: T) !void {
            const allocator = self.arena.allocator();
            if (self.root) |root| {
                const node = try allocator.create(Node);
                node.* = .init(rect);
                node.data = data;

                _ = try root.insert(self.arena.allocator(), node);
            } else {
                const ptrs = try allocator.alloc(Node, 2);
                const root = &ptrs[0];
                const child = &ptrs[1];

                root.* = .init(rect);

                child.* = .init(rect);
                child.data = data;

                try root.insert(allocator, child);
                self.root = root;
            }
        }

        pub fn query(self: *Self, rect: Rect, ud: *anyopaque, func: FnQueryResult) bool {
            if (self.root) |root| {
                return root.query(rect, ud, func);
            }
            return false;
        }

        pub fn queryAt(self: *Self, x: i64, y: i64, ud: *anyopaque, func: FnQueryResult) bool {
            var rect = Rect{ .x = x, .y = y, .w = 1, .h = 1 };
            if (self.root) |root| {
                return root.query(&rect, ud, func);
            }
            return false;
        }

        pub fn print(self: *Self) void {
            if (self.root) |root| {
                root.print(0);
            }
        }
    };
}

const testing = std.testing;
test "insert - 1" {
    const RT = RTree(i32, 4);
    const allocator = testing.allocator;

    var tree: RT = .init(allocator);
    defer tree.deinit();

    // |-----------------------------------|
    // |  ---------          -----------   |
    // |  |       |          |         |   |
    // |  |   1    ----------|     3   |   |
    // |  |      x      2              |   |
    // |  |                            |   |
    // |  |----------------------------|   |
    // ------------------------------------
    tree.print();
    std.debug.print("\n", .{});
    try tree.insert(.{ .x = 0, .y = 0, .w = 10, .h = 10 }, 1);
    tree.print();
    std.debug.print("\n", .{});
    try tree.insert(.{ .x = 5, .y = 5, .w = 15, .h = 5 }, 2);
    tree.print();
    std.debug.print("\n", .{});
    try tree.insert(.{ .x = 15, .y = 0, .w = 10, .h = 10 }, 3);
    tree.print();

    const Case = struct {
        expected: []i32,
        count: usize = 0,

        pub fn assert(self: *@This()) !void {
            try testing.expectEqual(self.expected.len, self.count);
        }
    };

    const FNs = struct {
        fn queryResult(ptr: *anyopaque, node: *RT.Node, _: RT.Rect) void {
            const case: *Case = @ptrCast(@alignCast(ptr));

            for (case.expected) |expect| {
                if (node.data) |val| {
                    if (val == expect) {
                        case.count += 1;
                        return;
                    }
                }
            }
            case.count += 1;
        }
    };

    var case1: Case = .{
        .expected = @constCast(&[_]i32{ 1, 2 }),
    };
    tree.query(.{ .x = 7, .y = 5, .w = 2, .h = 2 }, &case1, FNs.queryResult);
    try case1.assert();

    var case2: Case = .{
        .expected = @constCast(&[_]i32{}),
    };
    tree.query(.{ .x = 12, .y = 0, .w = 1, .h = 1 }, &case2, FNs.queryResult);
    try case2.assert();
}

test "insert - clusters" {
    std.debug.print("\n\nTEST 2\n{s}\n", .{"#" ** 100});
    const RT = RTree(i32, 4);
    const allocator = testing.allocator;

    var tree: RT = .init(allocator);
    defer tree.deinit();

    // |-----------------------------------|
    // |  --------------------------       |
    // |  | 4  -----  -----  ----- |       |
    // |  |    | 1 |  | 2 |  | 3 | |       |
    // |  |    -----  -----  ----- |       |
    // |  --------------------------       |
    // |             -----                 |
    // |             | 5 |                 |
    // -------------------------------------
    //
    try tree.insert(.{ .x = 5, .y = 5, .w = 50, .h = 10 }, 4);
    tree.print();
    std.debug.print("$\n", .{});
    try tree.insert(.{ .x = 10, .y = 5, .w = 10, .h = 10 }, 1);
    tree.print();
    std.debug.print("$\n", .{});
    try tree.insert(.{ .x = 25, .y = 5, .w = 10, .h = 10 }, 2);
    tree.print();
    std.debug.print("$\n", .{});
    try tree.insert(.{ .x = 40, .y = 5, .w = 10, .h = 10 }, 3);
    tree.print();
    std.debug.print("$\n", .{});
    try tree.insert(.{ .x = 25, .y = 25, .w = 10, .h = 10 }, 5);

    const Case = struct {
        expected: []i32,
        count: usize = 0,

        pub fn assert(self: *@This()) !void {
            try testing.expectEqual(self.expected.len, self.count);
        }
    };

    const FNs = struct {
        fn queryResult(ptr: *anyopaque, node: *RT.Node, _: RT.Rect) void {
            const case: *Case = @ptrCast(@alignCast(ptr));

            for (case.expected) |expect| {
                if (node.data) |val| {
                    if (val == expect) {
                        case.count += 1;
                        return;
                    }
                }
            }
        }
    };

    tree.print();
    var case1: Case = .{
        .expected = @constCast(&[_]i32{ 1, 2, 5, 4 }),
    };
    tree.query(.{ .x = 10, .y = 0, .w = 35, .h = 100 }, &case1, FNs.queryResult);
    try case1.assert();

    var case2: Case = .{
        .expected = @constCast(&[_]i32{}),
    };
    tree.query(.{ .x = 12, .y = 0, .w = 1, .h = 1 }, &case2, FNs.queryResult);
    try case2.assert();
}
