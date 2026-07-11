const Mapper = @import("utils.zig").LuaMapperStruct;
const domain = @import("binding.zig").domain;
const mapper = Mapper(domain.Character);
const lua = @import("binding.zig").lua;
const std = @import("std");

pub const CharacterBinding = @This();
pub const metatableName = mapper.metatableName;

const CharacterStatsBinding = Mapper(domain.CharacterStats);
const StatsStateBinding = Mapper(domain.StatsState);
const SkillAttributesBinding = Mapper(domain.SkillAttributes);
const ResistStatsBinding = Mapper(domain.ResitsStats);
const CitizenBinding = Mapper(domain.CitizenInfo);
const Cities = Mapper(domain.Cities);

pub fn toUserdata(L: *lua.State, idx: i32) ?*domain.Character {
    return mapper.toUserdata(L, idx);
}

pub fn newUserdata(L: *lua.State, character: *domain.Character) void {
    mapper.newUserdata(L, character);
}

pub fn getMetatable(L: *lua.State) void {
    L.getMetatableByName(metatableName);
}

pub fn bind(L: *lua.State) void {
    mapper.bind(L);
    CharacterStatsBinding.bind(L);
    ResistStatsBinding.bind(L);
    StatsStateBinding.bind(L);
    SkillAttributesBinding.bind(L);
    CitizenBinding.bind(L);
    bindEnums(L);
}

fn bindEnums(L: *lua.State) void {
    // create character state
    L.newTable();
    inline for (std.meta.fields(domain.CharacterClass)) |option| {
        L.pushInteger(option.value);
        L.setField(-2, option.name);
    }
    L.setGlobal("CharacterClass");

    L.newTable();
    inline for (std.meta.fields(domain.CharacterSoul)) |option| {
        L.pushInteger(option.value);
        L.setField(-2, option.name);
    }
    L.setGlobal("CharacterSoul");

    L.newTable();
    inline for (std.meta.fields(domain.Cities)) |option| {
        L.pushInteger(option.value);
        L.setField(-2, option.name);
    }
    L.setGlobal("Cities");
}
