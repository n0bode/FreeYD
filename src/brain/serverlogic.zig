const std = @import("std");
const Allocator = std.mem.Allocator;
const c = @import("c").c;

pub const LuaLogic = struct {
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: Allocator) LuaLogic {
        return .{
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: LuaLogic) void {
        self.deinit();
    }

    pub fn processP
};
