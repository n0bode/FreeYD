const utils = @import("utils.zig");
const binding = @import("binding.zig");
const domain = binding.domain;
const lua = binding.lua;

const Mapper = utils.MapperStructPtr;
const NPC = domain.NPC;
const Object = binding.core.Object;
const mapper = Mapper(NPC);

pub const metatableName = mapper.metatableName;

pub const NPCBinding = @This();

pub fn toUserdata(L: *lua.State) ?*NPC {
    return mapper.toUserdata(L, 1);
}

pub fn newUserdata(L: *lua.State, npc: *NPC) void {
    mapper.newUserdata(L, npc);
}

pub fn bind(L: *lua.State) void {
    mapper.bind(L);
}
