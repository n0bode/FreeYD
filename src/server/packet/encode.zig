const Packet = @import("packet.zig").Packet;
const Header = @import("packet.zig").Header;
const PacketData = @import("packet.zig").PacketData;
const encrypt = @import("crypto.zig").encrypt;
const std = @import("std");

pub const Error = error{
    InvalidEncrypt,
};

pub fn sizeOf(comptime T: anytype) comptime_int {
    return @sizeOf(T) + @sizeOf(Header);
}

pub fn encode(comptime T: anytype, packet: *T) ![]u8 {
    var buffer = std.mem.asBytes(packet);

    std.log.info("headerSize= {d}", .{buffer.len});

    _ = encrypt(buffer[0..]);
    return buffer;
}
