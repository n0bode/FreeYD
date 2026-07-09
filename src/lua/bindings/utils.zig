const State = @import("binding.zig").lua.State;
const std = @import("std");
const ascii = std.ascii;

const testing = std.testing;

pub fn fromSnakeCase(comptime name: []const u8) []const u8 {
    const count = comptime blk: {
        var acc = 0;
        for (name) |c| {
            if (c == '_')
                acc = acc + 1;
        }
        break :blk acc;
    };

    const result: [name.len - count]u8 = comptime blk: {
        var buffer: [name.len - count]u8 = undefined;
        var i: usize = 0;
        var last: bool = false;
        for (name) |c| {
            if (c == '_') {
                last = true;
            } else {
                if (last) {
                    buffer[i] = ascii.toUpper(c);
                } else {
                    buffer[i] = c;
                }
                i = i + 1;
                last = false;
            }
        }
        break :blk buffer;
    };
    return &result;
}

test "fromSnakeCase" {
    try testing.expectEqualStrings(fromSnakeCase("hello_world"), "helloWorld");
    try testing.expectEqualStrings(fromSnakeCase("foo_bar_baz"), "fooBarBaz");
    try testing.expectEqualStrings(fromSnakeCase("singleword"), "singleword");
    try testing.expectEqualStrings(fromSnakeCase("_leading_underscore"), "LeadingUnderscore");
    try testing.expectEqualStrings(fromSnakeCase("trailing_underscore_"), "trailingUnderscore");
    try testing.expectEqualStrings(fromSnakeCase("multiple__underscores"), "multipleUnderscores");
}

pub fn toSnakeCase(comptime name: []const u8) []const u8 {
    const count = comptime blk: {
        var acc = 0;
        for (name, 0..) |c, i| {
            if (ascii.isUpper(c) and i > 0) {
                acc += 1;
            }
        }
        break :blk acc;
    };

    const result: [count + name.len]u8 = comptime blk: {
        var buffer: [count + name.len]u8 = undefined;
        var i: usize = 0;
        for (name) |c| {
            if (ascii.isUpper(c) and i > 0) {
                buffer[i] = '_';
                buffer[i + 1] = ascii.toLower(c);
                i = i + 1;
            } else {
                buffer[i] = ascii.toLower(c);
            }
            i = i + 1;
        }
        break :blk buffer;
    };
    return &result;
}

test "toSnakeCase" {
    const expect = testing.expectEqualStrings;
    try expect("hello_world", toSnakeCase("HelloWorld"));
    try expect("hello", toSnakeCase("Hello"));
    try expect("hello_world_test", toSnakeCase("HelloWorldTest"));
    try expect("hello_world_test_case", toSnakeCase("HelloWorldTestCase"));
}

pub fn walkGeneratorMTS(comptime T: anytype, L: *State) void {
    if (@typeInfo(T) != .@"struct") return;

    LuaMapperStruct(T).bind(L);
    inline for (std.meta.fields(T)) |field| {
        if (@typeInfo(field.type) == .@"struct")
            walkGeneratorMTS(field.type, L);
    }
}

pub fn LuaMapperStruct(comptime T: anytype) type {
    return struct {
        pub const metatableName = "mt_" ++ @typeName(T);
        pub fn bind(L: *State) void {
            _ = L.newMetatable(metatableName);
            L.pushFunction(lua__index);
            L.setField(-2, "__index");
        }

        pub fn getMetatable(L: *State) void {
            L.getMetatableByName(metatableName);
        }

        pub fn newUserdata(L: *State, userdata: *T) void {
            const ptr = L.newUserdata(*T);
            ptr.* = userdata;
            L.getMetatableByName(metatableName);
            _ = L.setMetatable(-2);
        }

        pub fn toUserdata(L: *State, index: i32) ?*T {
            return (L.toUserdata(*T, index) orelse return null).*;
        }

        fn lua__index(L: *State) i32 {
            const keyName = L.toString(2);

            _ = L.getMetatable(1);
            L.getField(-1, keyName);
            if (L.isNil(-1)) {
                return 1;
            }
            L.pop(2);

            const self = toUserdata(L, 1) orelse {
                L.pushNil();
                return 1;
            };

            inline for (std.meta.fields(T)) |field| {
                const value = @field(self, field.name);
                const snakeName = toSnakeCase(field.name);
                if (field.type == void) continue;
                if (std.mem.eql(u8, keyName, snakeName)) {
                    switch (@typeInfo(field.type)) {
                        // use pointer instead of struct
                        .@"struct" => {
                            const ptr = &@field(self, field.name);
                            L.pushAny(*field.type, ptr);
                        },
                        else => L.pushAny(field.type, value),
                    }
                    return 1;
                }
            }
            L.pushNil();
            return 1;
        }
    };
}

pub fn IndexerField(comptime T: anytype) type {
    return struct {
        pub fn pushValue(self: T, name: []const u8, L: *State) bool {
            inline for (std.meta.fields(T)) |field| {
                const snakeName = toSnakeCase(field.name);
                if (std.mem.eql(u8, snakeName, name)) {
                    if (@typeInfo(field.type) == .@"struct") {
                        const ptr: *field.type = @constCast(&@field(self, field.name));
                        L.pushAny(*field.type, ptr);
                    } else {
                        const value = @field(self, field.name);
                        L.pushAny(field.type, value);
                        return true;
                    }
                }
            }
            return false;
        }
    };
}
