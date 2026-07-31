const bindings = @import("binding.zig");
const Position = bindings.domain.Position;
const Mapper = @import("utils.zig").MapperStructPtr;

const mapper = Mapper(Position);

pub const PositionBinding = @This();
pub const metatableName = mapper.metatableName;

pub fn bind(L: *bindings.lua.State) void {
    _ = L.newMetatable(metatableName ++ "_CPY");
    L.pushFunction(lua__index);
    L.setField(-2, "__index");

    mapper.bind(L);
}

pub fn newUserdataCopy(L: *bindings.lua.State, pos: *Position) void {
    const ptr = L.newUserdata(Position);
    ptr.* = pos.*;
    L.setMetableByName(metatableName ++ "_CPY");
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

fn lua__index(L: *bindings.lua.State) i32 {
    const self = L.toUserdata(Position, 1) orelse {
        L.pushNil();
        return 1;
    };

    const key = L.toString(2);
    if (key[0] == 'x') {
        L.pushInteger(self.x);
        return 1;
    } else if (key[0] == 'y') {
        L.pushInteger(self.y);
        return 1;
    }
    L.pushNil();
    return 1;
}
