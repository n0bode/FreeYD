const Mapper = @import("utils.zig").LuaMapperStruct;
const bindFunctions = @import("utils.zig").bindFunctions;
const EnumMapper = @import("utils.zig").EnumMapper;
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
const PositionBinding = Mapper(domain.Position);
const ItemBinding = @import("item_binding.zig").ItemBinding;

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
    bindFunctions(L, metatableName, &.{
        .{
            .name = "set_equipment",
            .value = .{
                .func = .{
                    .func = lua__set_equipment,
                },
            },
        },
        .{
            .name = "get_equipment",
            .value = .{
                .func = .{
                    .func = lua__get_equipment,
                },
            },
        },
    });

    bindEnums(L);
    CharacterStatsBinding.bind(L);
    ResistStatsBinding.bind(L);
    StatsStateBinding.bind(L);
    SkillAttributesBinding.bind(L);
    CitizenBinding.bind(L);
    PositionBinding.bind(L);
    ItemBinding.bind(L);
}

fn bindEnums(L: *lua.State) void {
    EnumMapper(domain.CharacterClass).bind(L);
    EnumMapper(domain.CharacterSoul).bind(L);
    EnumMapper(domain.Cities).bind(L);
    EnumMapper(domain.EquipmentSlot).bind(L);
}

fn lua__set_equipment(L: *lua.State) i32 {
    const self: *domain.Character = mapper.toUserdata(L, 1) orelse {
        L.pushString("must be a character instance");
        return 1;
    };

    const slot = L.checkInteger(2);
    _ = std.enums.fromInt(domain.EquipmentSlot, slot) orelse {
        L.pushString("slot invalid");
        return 1;
    };

    const item = ItemBinding.toUserdata(L, 3) orelse {
        L.pushString("item must be item instance");
        return 1;
    };

    self.equipments[@intCast(slot)] = item.*;
    L.pushNil();
    return 1;
}

fn lua__get_equipment(L: *lua.State) i32 {
    const self: *domain.Character = mapper.toUserdata(L, 1) orelse {
        L.pushString("must be a character instance");
        return 1;
    };

    const slot = L.checkInteger(2);
    _ = std.enums.fromInt(domain.EquipmentSlot, slot) orelse {
        L.pushString("slot invalid");
        return 1;
    };

    const item = self.equipments[@intCast(slot)];
    if (item.itemID == 0) {
        L.pushNil();
    } else {
        ItemBinding.newUserdata(L, &self.equipments[@intCast(slot)]);
    }
    return 1;
}
