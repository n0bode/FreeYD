const core = @import("../core.zig");
const std = @import("std");
const domains = core.domains;

pub const Mob = domains.Mob;
pub const NPC = domains.NPC;
pub const GroundItem = domains.GroundItem;
pub const Point = core.Point;
pub const Position = domains.Position;

pub const EntityType = enum { mob, item };
pub const Entity = union(EntityType) {
    mob: *Mob,
    item: *GroundItem,
};

pub const Spawned = struct {
    point: Point,
    onInteract: ?i32 = null,
    // only works with mobs, not items
    onUpdate: ?i32 = null,
    // only works with mobs, not items
    onDeath: ?i32 = null,
    tick: u32 = 1000,
    countTick: u64 = 1000,
    startPosition: Position,
    // user can, 256 bytes to allocate
    entity: Entity,
};
