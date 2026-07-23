pub const domains = @import("domains/domains.zig");
const QuadTree = @import("utils").QuadTree;

pub const MobQuadTree = QuadTree(*domains.Mob, 10);
pub const World = @import("world.zig").World;
pub const SpawnedMob = @import("world.zig").SpawnedMob;
pub const SpawnedNPC = @import("world.zig").SpawnedNPC;
