const std = @import("std");
const packet = @import("packet.zig");
const crypto = @import("crypto.zig");

const Packet = packet.Packet;
const Header = packet.Header;

pub const Error = error{
    DescryptInvalid,
    PacketUnknown,
};

fn parsePacket(comptime T: anytype, bMessage: []u8) T {
    return @bitCast(bMessage[0..@sizeOf(T)].*);
}

pub fn decode(bMessage: []u8) Error!Packet {
    const header = crypto.descrypt(bMessage) catch {
        return Error.DescryptInvalid;
    };

    const opcode: packet.OpcodeRecv = .parse(header.operationCode);

    inline for (std.meta.fields(Packet)) |field| {
        if (std.mem.eql(u8, @tagName(opcode), field.name)) {
            return @unionInit(Packet, field.name, parsePacket(field.type, bMessage));
        }
    }
    return .{
        .unknown = parsePacket(Header, bMessage),
    };
}

const t = std.testing;
test "decode - login" {
    const data = "dAANQgXzvP35GfT9b2RZb2hSYWLy8fT5wvQY/SpQZ3CTU2ph8uQMAOjzAPz1/YT9Gv+k/Rjq6P2vPuT7qFFEcPjyRPyu8XT9NvEM/GbxPP368fQA6uX0+vTq9Pv48Rj/IOWU/UbxYP368fT9+urc/fLxzP0=";
    var buffer: [116]u8 = undefined;

    const decoder = std.base64.standard.Decoder;
    try decoder.decode(buffer[0..], data);

    const _packet = try decode(buffer[0..]);
    switch (_packet) {
        else => try t.expect(false),
        .login => |*login| {
            try t.expectEqual(754, login.version);
            try t.expectEqual(packet.Opcode.LOGIN, login.header.operationCode);
            try t.expectEqualStrings("username", login.username[0..8]);
            try t.expectEqualStrings("password", login.password[0..8]);
        },
    }
}
