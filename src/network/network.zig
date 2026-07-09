pub const Peer = @import("peer.zig").Peer;
pub const Server = @import("server.zig").Server;
pub const Opcode = packet.Opcode;

pub const packet = @import("packet/packet.zig");
pub const PacketInput = packet.client.PacketInput;

pub const responses = packet.server;
