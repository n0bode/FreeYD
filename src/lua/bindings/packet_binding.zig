const lua = @import("binding.zig").lua;
const network = @import("binding.zig").network;
const std = @import("std");
const utils = @import("utils.zig");

const Indexer = utils.IndexerField;
const walkGeneratorMTS = utils.walkGeneratorMTS;

const PacketInput = network.PacketInput;
const packets = network.packet.client;

pub const PacketInputBinding = @This();
pub const HeaderBinding = utils.MapperStructPtr(network.Header);

pub fn getMetatableName() []const u8 {
    return "mt_" ++ @typeName(PacketInput);
}

pub fn getMetatable(L: *lua.State) void {
    return L.getMetatableByName(getMetatableName());
}

pub fn newUserdata(L: *lua.State, input: *PacketInput) void {
    const ptr = L.newUserdata(*PacketInput);
    ptr.* = input;
    getMetatable(L);
    _ = L.setMetatable(-2);
}

pub fn toUserdata(L: *lua.State, index: i32) ?*PacketInput {
    return (L.toUserdata(*PacketInput, index) orelse return null).*;
}

pub fn bind(L: *lua.State) void {
    const mtName = getMetatableName();
    _ = L.newMetatable(mtName);
    L.pushFunction(lua__index);
    L.setField(-2, "__index");
    L.pop(1);

    HeaderBinding.bind(L);
    inline for (std.meta.fields(packets.PacketData)) |packetType| {
        walkGeneratorMTS(packetType.type, L);
    }
}

fn lua__index(L: *lua.State) i32 {
    const keyName = L.checkString(2);

    // check if key is a function in metatable
    _ = L.getMetatable(1);
    L.getField(-1, keyName);
    if (!L.isNil(-1)) {
        L.pop(1);
        return 1;
    }
    L.pop(2);

    // access fields
    const self = toUserdata(L, 1) orelse {
        L.pushNil();
        return 1;
    };

    // add header
    if (std.mem.eql(u8, keyName, "header")) {
        HeaderBinding.newUserdata(L, &self.header);
        return 1;
    }

    inline for (std.meta.fields(packets.PacketData)) |field| {
        if (field.type == void) continue;
        const enumCurrent = @field(packets.PacketData, field.name);
        if (enumCurrent == self.data) {
            const data = &@field(self.data, field.name);
            if (Indexer(field.type).pushValue(data, keyName, L)) {
                return 1;
            } else {
                // dont need run all for
                L.pushNil();
                return 1;
            }
        }
    }
    L.pushNil();
    return 1;
}

test "bind - test" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var packet = PacketInput{
        .header = .{},
        .data = .{
            .login = .{
                .ipAddress = [_]u8{ 192, 168, 1, 1 } ++ [_]u8{0} ** 12,
                .keys = [_]u8{0} ** 16,
                .none = 0,
                .password = [_]u8{0} ** 12,
                .username = [_]u8{0} ** 16,
                .version = 753,
            },
        },
    };

    const username = "teste";
    const password = "senha";

    @memcpy(packet.data.login.username[0..username.len], username[0..]);
    @memcpy(packet.data.login.password[0..password.len], password[0..]);

    const L = try lua.State.init(arena.allocator());
    bind(L);

    const vtable = struct {
        fn _expect(LL: *lua.State) i32 {
            const result = LL.toString(1);
            const expect = LL.toString(2);
            std.testing.expectEqualStrings(expect, result) catch |err| {
                std.debug.print("failed, expected = {any}, result = {any}", .{ expect, result });
                _ = LL.throw(@errorName(err));
                return 0;
            };
            LL.pushNil();
            return 1;
        }
    };
    L.pushFunction(vtable._expect);
    L.setGlobal("expect");

    newUserdata(L, &packet);
    L.setGlobal("packet");

    try L.doString("expect(packet.password, 'senha')");
    try L.doString("expect(packet.username, 'teste')");
    try L.doString("expect(packet.version, 753)");
}
