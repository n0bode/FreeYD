pub const lua = @import("lua");
pub const network = @import("network");

pub const core = @import("core");
pub const domain = core.domains;
pub const Database = @import("database").Database;

const Mapper = @import("utils.zig").LuaMapperStruct;

pub const PacketBinder = @import("packet_binding.zig").PacketInputBinding;
pub const PeerBinding = @import("peer/peer_binding.zig").PeerBinding;
pub const DatabaseBinding = @import("database_binding.zig").DatabaseBinding;

pub const AccountBinding = @import("account_binding.zig").AccountBinding;
pub const CharacterBinding = @import("character_binding.zig").CharacterBinding;
pub const MobBinding = @import("mob_binding.zig").MobBinding;
pub const PositionBinding = Mapper(domain.Position);

const testing = @import("std").testing;
test {
    testing.refAllDecls(@This());
}
