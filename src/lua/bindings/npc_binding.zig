const utils = @import("utils.zig");
const binding = @import("binding.zig");
const domain = binding.domain;
const lua = binding.lua;

const Mapper = utils.MapperStructPtr;
const NPC = domain.NPC;
const SpawnedNPC = binding.core.SpawnedNPC;
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
    utils.bindFunctions(L, metatableName, &.{
        .{
            .name = "get_spawned_mob",
            .value = .{ .func = .{ .func = lua__get_spawned_mob } },
        },
    });
}

fn lua__get_spawned_mob(L: *lua.State) i32 {
    const npc: *NPC = toUserdata(L) orelse {
        L.pushNil();
        return 1;
    };

    const spawned: *SpawnedNPC = @fieldParentPtr("npc", npc);
    binding.SpawnedMobBinding.newUserdata(L, &spawned.spawnedMob);
    return 1;
}
