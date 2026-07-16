pub const c = @import("c");

const wrapper = @import("wrapper.zig");
pub const State = wrapper.State;
pub const Reg = wrapper.Reg;
pub const LuaFN = wrapper.LuaFN;
pub const LuaType = wrapper.LuaType;

const testing = @import("std").testing;
test {
    _ = @import("array_wrapper.zig");
    testing.refAllDecls(@This());
}
