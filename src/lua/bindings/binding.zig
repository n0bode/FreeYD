pub const lua = @import("lua");
pub const network = @import("network");
pub const domain = @import("core").domains;
pub const Database = @import("database").Database;

const Mapper = @import("utils.zig").LuaMapperStruct;

pub const PacketBinder = @import("packet_binding.zig").PacketInputBinding;
pub const PeerBinding = @import("peer_binding.zig").PeerBinding;
pub const DatabaseBinding = @import("database_binding.zig").DatabaseBinding;

pub const AccountBinding = Mapper(domain.Account);
pub const CharacterBinding = Mapper(domain.Character);
pub const ItemBinding = Mapper(domain.Item);

const testing = @import("std").testing;
test {
    testing.refAllDecls(@This());
}
