const core = @import("../core.zig");
const domains = core.domains;

pub const Mob = domains.Mob;
pub const NPC = domains.NPC;
pub const Item = domains.Item;
pub const Point = core.Point;

pub const EntityType = enum { mob, npc, item };
pub const Entity = union(EntityType) {
    mob: *Mob,
    npc: *NPC,
    item: *Item,
};

pub const Object = struct {
    point: Point,
    entity: Entity,
};
