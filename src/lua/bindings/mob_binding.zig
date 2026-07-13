const bindings = @import("binding.zig");
const utils = @import("utils.zig");

const domain = bindings.domain;
const mapper = utils.LuaMapperStruct(domain.Mob);

pub const MobBinding = @This();

pub const metatableName = mapper.metatableName;

pub fn toUserdata(L: *bindings.lua.State, idx: i32) ?*domain.Mob {
    return mapper.toUserdata(L, idx);
}

pub fn newUserdata(L: *bindings.lua.State, mob: *domain.Mob) void {
    mapper.newUserdata(L, mob);
}

pub fn getMetatable(L: *bindings.lua.State) void {
    L.getMetatableByName(mapper.metatableName);
}

pub fn bind(L: *bindings.lua.State) void {
    mapper.bind(L);
}
