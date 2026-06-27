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
    const verifier: packet.Verifier = @bitCast(bMessage[0..@sizeOf(packet.Verifier)].*);

    std.debug.print("{d} {d} {d}\n", .{ verifier.size, verifier.iKeyword, verifier.checksum });
    const header = crypto.descrypt(verifier, bMessage) catch {
        return Error.DescryptInvalid;
    };

    const opcode: packet.PacketOpcode = .parse(header.operationCode);
    return switch (opcode) {
        .login => .{
            .login = parsePacket(packet.PacketLogin, bMessage),
        },
        .textmessage => .{
            .textmessage = parsePacket(packet.PacketTextMessage, bMessage),
        },
        .unknown => .{
            .unknown = header,
        },
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

test "decode - text message" {
    const data = "bABkzfvlhP0M8XT8PWOZc3URWGtnaFr9AO3oAMLxMADS8TD79PGU/HLpZPsA8PD9IvBc/brxbP0G7cz9HvH0/fr91Pr66Oj7+uzw/Qz8QPpK8Yz9MPH0/frx9Ptu8eT95vH0/fzxtP3y8WgA";

    var obj: packet.PacketTextMessage = undefined;
    var buffer = std.mem.asBytes(&obj);

    const decoder = std.base64.standard.Decoder;
    try decoder.decode(buffer[0..], data);

    const _packet = decode(buffer[0..]) catch {
        return;
    };

    switch (_packet) {
        else => try t.expect(false),
        .textmessage => |*message| {
            try t.expectEqual(packet.Opcode.TEXTMESSAGE, message.header.operationCode);
            try t.expectEqualStrings("Crazy train", message.message[0..11]);
        },
    }
}
