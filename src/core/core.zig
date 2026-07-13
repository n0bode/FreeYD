pub const domains = @import("domains/domains.zig");
const QuadTree = @import("utils").QuadTree;

pub const MobQuadTree = QuadTree(domains.Mob, 10);
