pub const domains = @import("domains/domains.zig");

// max players nears
pub const WorldTree = @import("utils").QuadTree(20);
// position mob/npc/items in world
pub const Point = WorldTree.Point;

const world = @import("world/world.zig");
pub const World = world.World;
pub const Object = world.Object;

pub const NPC = domains.NPC;
pub const Mob = domains.Mob;
