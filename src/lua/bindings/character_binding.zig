const Mapper = @import("utils.zig").MapperStructPtr;
const bindFunctions = @import("utils.zig").bindFunctions;
const EnumMapper = @import("utils.zig").EnumMapper;
const domain = @import("binding.zig").domain;
const mapper = Mapper(domain.Character);
const lua = @import("binding.zig").lua;
const std = @import("std");

pub const CharacterBinding = @This();
pub const metatableName = mapper.metatableName;

const StatsBinding = Mapper(domain.Stats);
const StatsStateBinding = Mapper(domain.StatsState);
const SkillAttributesBinding = Mapper(domain.SkillAttributes);
const ResistStatsBinding = Mapper(domain.ResitsStats);
const CitizenBinding = Mapper(domain.CitizenInfo);
const ItemBinding = @import("item_binding.zig").ItemBinding;
const MobBinding = @import("mob_binding.zig").MobBinding;
const PositionBinding = @import("binding.zig").PositionBinding;

const Item = domain.Item;

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
                .func = .{ .func = lua__set_equipment },
            },
        },
        .{
            .name = "get_equipment",
            .value = .{
                .func = .{ .func = lua__get_equipment },
            },
        },
        .{
            .name = "to_mob",
            .value = .{
                .func = .{ .func = lua__to_mob },
            },
        },
        .{
            .name = "swap_items",
            .value = .{
                .func = .{ .func = lua__swap_items },
            },
        },
        .{
            .name = "get_item",
            .value = .{
                .func = .{ .func = lua__get_item },
            },
        },
        .{
            .name = "add_item_on_empty",
            .value = .{
                .func = .{ .func = lua__add_item_on_empty },
            },
        },
    });

    bindEnums(L);
    StatsBinding.bind(L);
    ResistStatsBinding.bind(L);
    StatsStateBinding.bind(L);
    SkillAttributesBinding.bind(L);
    CitizenBinding.bind(L);
    ItemBinding.bind(L);
    PositionBinding.bind(L);
}

fn bindEnums(L: *lua.State) void {
    EnumMapper(domain.CharacterClass).bind(L);
    EnumMapper(domain.CharacterSoul).bind(L);
    EnumMapper(domain.Cities).bind(L);
    EnumMapper(domain.EquipmentSlot).bind(L);
    EnumMapper(domain.StorageType).bind(L);
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

fn lua__to_mob(L: *lua.State) i32 {
    const self: *domain.Character = mapper.toUserdata(L, 1) orelse {
        L.pushNil();
        return 1;
    };

    const mob = self.toMob();
    //heap memory
    const ptr = L.newUserdata(domain.Mob);
    ptr.* = mob;
    MobBinding.newUserdata(L, ptr);
    return 1;
}

fn lua__swap_items(L: *lua.State) i32 {
    const self: *domain.Character = mapper.toUserdata(L, 1) orelse {
        L.pushString("must be a character instance");
        return 1;
    };

    const destStorage = std.enums.fromInt(domain.StorageType, L.checkInteger(2)) orelse {
        L.pushString("dest storage invalid");
        return 1;
    };
    const destSlot = L.checkInteger(3);

    const srcStorage = std.enums.fromInt(domain.StorageType, L.checkInteger(4)) orelse {
        L.pushString("src storage invalid");
        return 1;
    };
    const srcSlot = L.checkInteger(5);

    L.pushBool(self.swapItems(destStorage, @intCast(destSlot & 0xFF), srcStorage, @intCast(srcSlot & 0xFF)));
    return 1;
}

fn lua__get_item(L: *lua.State) i32 {
    const self: *domain.Character = mapper.toUserdata(L, 1) orelse {
        L.pushString("must be a character instance");
        return 1;
    };

    const storage = std.enums.fromInt(domain.StorageType, L.checkInteger(2)) orelse {
        L.pushString("dest storage invalid");
        return 1;
    };
    const slot = L.checkInteger(3);

    if (self.getItem(storage, @intCast(slot & 0xFF))) |item| {
        const ptr = L.newUserdata(domain.Item);
        ptr.* = item;

        ItemBinding.newUserdata(L, ptr);
        return 1;
    }

    L.pushNil();
    return 1;
}

fn lua__add_item_on_empty(L: *lua.State) i32 {
    const self: *domain.Character = mapper.toUserdata(L, 1) orelse {
        L.pushString("must be a character instance");
        return 1;
    };

    const item = ItemBinding.toUserdata(L, 2) orelse {
        L.pushString("item must be item instance");
        return 1;
    };

    L.pushInteger(@intCast(self.addItemOnEmptySlot(item.*)));
    return 1;
}
