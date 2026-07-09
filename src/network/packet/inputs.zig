const std = @import("std");
const Header = @import("packet.zig").Header;
const Opcode = @import("packet.zig").Opcode;
const crypto = @import("crypto.zig");

pub const PacketData = union(OpcodeFromClient) {
    unknown,
    ping,
    login: PacketLoginInput,
    pinPassword: PacketPinPasswordInput,
    charCreate: PacketCharCreateInput,
    charDelete: PacketCharDeleteInput,
    enterWorld: PacketEnterWorldInput,
    movement: PacketActionInput,
    moveItem: PacketMoveItemInput,
};

// This a Packet abstract union received from Client
pub const PacketInput = struct {
    header: Header,
    data: PacketData,

    pub fn decode(bMessage: []u8) !PacketInput {
        const header = crypto.descrypt(bMessage) catch {
            return error.DescryptInvalid;
        };

        const opcode: OpcodeFromClient = .parse(header.operationCode);
        inline for (std.meta.fields(PacketData)) |field| {
            if (opcode == @field(PacketData, field.name)) {
                if (field.type == void) {
                    return .{
                        .header = header,
                        .data = @unionInit(PacketData, field.name, {}),
                    };
                }
                return .{
                    .header = header,
                    .data = @unionInit(PacketData, field.name, parsePacket(field.type, bMessage)),
                };
            }
        }

        return .{
            .header = header,
            .data = .unknown,
        };
    }
};

fn parsePacket(comptime T: anytype, bMessage: []u8) T {
    const start = @sizeOf(Header);
    const end = start + @sizeOf(T);
    return @bitCast(bMessage[start..end].*);
}

pub const OpcodeFromClient = enum(u16) {
    unknown,
    ping = @intFromEnum(Opcode.PING),
    login = @intFromEnum(Opcode.LOGIN),
    pinPassword = @intFromEnum(Opcode.PIN),
    charCreate = @intFromEnum(Opcode.CHAR_CREATE),
    charDelete = @intFromEnum(Opcode.CHAR_DELETE),
    enterWorld = @intFromEnum(Opcode.CHAR_SELECT),
    movement = @intFromEnum(Opcode.MOVEMENT),
    moveItem = @intFromEnum(Opcode.ITEM_MOVE),

    // parse a u16 code to a struct union with correct data
    pub fn parse(code: u16) OpcodeFromClient {
        inline for (std.enums.values(OpcodeFromClient)) |value| {
            if (@intFromEnum(value) == code) {
                return value;
            }
        }
        return .unknown;
    }
};

pub const PacketMoveItemInput = extern struct {
    destStorage: u8,
    destSlot: u8,
    sourceStorage: u8,
    sourceSlot: u8,
    _0: u32 = 0,
};

pub const PacketCharCreateInput = extern struct {
    slot: i32,
    name: [16]u8,
    class: u8,
};

pub const PacketEnterWorldInput = extern struct {
    charSlot: i32,
    _dunno: [18]u8 = [_]u8{0} ** 18,
};

pub const PacketPinPasswordInput = extern struct {
    numeric: [6]u8,
    _unknown: [10]u8,
};

pub const PacketActionInput = extern struct {
    position: extern struct {
        x: i16,
        y: i16,
    },
    speed: i32,
    kind: i32,
    destination: extern struct {
        x: i16,
        y: i16,
    },
    command: [24]u8,
};

pub const PacketLoginInput = extern struct {
    username: [16]u8,
    password: [12]u8,
    version: i32,
    none: i32,
    keys: [16]u8,
    ipAddress: [16]u8,
};

pub const PacketCharDeleteInput = extern struct {
    slot: i32,
    name: [16]u8,
    password: [12]u8,
};

const t = std.testing;
test "PacketFromClient.decode - it should success" {
    const data = "dAANQgXzvP35GfT9b2RZb2hSYWLy8fT5wvQY/SpQZ3CTU2ph8uQMAOjzAPz1/YT9Gv+k/Rjq6P2vPuT7qFFEcPjyRPyu8XT9NvEM/GbxPP368fQA6uX0+vTq9Pv48Rj/IOWU/UbxYP368fT9+urc/fLxzP0=";
    var buffer: [116]u8 = undefined;

    const decoder = std.base64.standard.Decoder;
    try decoder.decode(buffer[0..], data);

    const _packet = try PacketInput.decode(buffer[0..]);
    std.debug.print("opcode = {X} \n", .{_packet.header.operationCode});
    switch (_packet.data) {
        else => try t.expect(false),
        .login => |*login| {
            try t.expectEqual(754, login.version);
            try t.expectEqual(@intFromEnum(Opcode.LOGIN), _packet.header.operationCode);
            try t.expectEqualStrings("username", login.username[0..8]);
            try t.expectEqualStrings("password", login.password[0..8]);
        },
    }
}
