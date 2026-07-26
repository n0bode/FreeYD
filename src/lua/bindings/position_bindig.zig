const bindings = @import("binding.zig");
const Position = bindings.domain.Position;
const Mapper = @import("utils.zig").MapperStructPtr;

const mapper = Mapper(Position);

pub const PositionBinding = @This();
pub const metatableName = mapper.metatableName;

pub fn bind(L: *bindings.lua.State) void {
    mapper.bind(L);
}

pub fn toUserdataPtr(L: *bindings.lua.State, idx: i32) ?*Position {
    return mapper.toUserdata(L, idx);
}

pub fn toUserdata(L: *bindings.lua.State, idx: i32) ?Position {
    if (L.getLuaType(idx) == .Table) {
        L.pushValue(idx);
        L.getField(-1, "x");
        L.checkType(-1, .Number);
        L.getField(-2, "y");
        L.checkType(-1, .Number);
        const pos = Position{
            .x = L.toInteger(i16, -2),
            .y = L.toInteger(i16, -1),
        };
        L.pop(3);
        return pos;
    }

    L.checkType(idx, .Userdata);
    return (toUserdataPtr(L, idx) orelse {
        return null;
    }).*;
}
