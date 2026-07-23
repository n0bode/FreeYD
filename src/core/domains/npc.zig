// lua code
// ---@class NPC
// ---@field id integer npc id in world server
// ---@field name string mob npc in world
// ---@field current_position Position
// ---@field start_position Position
// ---@field data Mob
const domain = @import("domains.zig");

const Position = domain.Position;
const Mob = domain.Mob;

pub const NPC = extern struct {
    id: u16,
    name: [16]u8,
    current_position: Position,
    start_position: Position,
    mob: *Mob,

    pub fn init(id: i32, name: []const u8, start_position: Position, data: Mob) NPC {
        var npc = NPC{
            .id = id,
            .name = undefined,
            .current_position = start_position,
            .start_position = start_position,
            .data = data,
        };
        @memcpy(npc.name[0..name.len], name[0..]);
        return npc;
    }
};
