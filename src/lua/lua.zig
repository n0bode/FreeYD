pub const c = @import("c");

pub const State = @import("wrapper.zig").State;
pub const Reg = @import("wrapper.zig").Reg;
pub const LuaFN = @import("wrapper.zig").LuaFN;
pub const LuaType = @import("wrapper.zig").LuaType;

const testing = @import("std").testing;
test {
    _ = @import("array_wrapper.zig");
    testing.refAllDecls(@This());
}
