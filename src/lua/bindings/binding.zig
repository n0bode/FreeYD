pub const lua = @import("lua");
pub const network = @import("network");
pub const utils = @import("utils");

pub const core = @import("core");
pub const domain = core.domains;
pub const Database = @import("database").Database;

pub const Mapper = @import("utils.zig").MapperStructPtr;

pub const PacketBinder = @import("packet_binding.zig").PacketInputBinding;
pub const PeerBinding = @import("peer/peer_binding.zig").PeerBinding;
pub const DatabaseBinding = @import("database_binding.zig").DatabaseBinding;

pub const AccountBinding = @import("account_binding.zig").AccountBinding;
pub const CharacterBinding = @import("character_binding.zig").CharacterBinding;
pub const MobBinding = @import("mob_binding.zig").MobBinding;
pub const PositionBinding = @import("position_bindig.zig").PositionBinding;
pub const SpawnedMobBinding = Mapper(core.SpawnedMob);
pub const WorldBinding = @import("world_binding.zig").WorldBinding;
pub const RTreeBinding = @import("libs/rtree_binding.zig").RTreeBinding;
pub const ItemBinding = @import("item_binding.zig").ItemBinding;
pub const NPCBinding = Mapper(domain.NPC);

const testing = @import("std").testing;
test {
    testing.refAllDecls(@This());
}
