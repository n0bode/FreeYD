const State = @import("binding.zig").lua.State;
const Reg = @import("binding.zig").lua.Reg;

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
        var last = false;
        for (name, 0..) |c, i| {
            if (ascii.isUpper(c) and i > 0 and !last) {
                last = true;
                acc += 1;
            } else {
                last = ascii.isUpper(c);
            }
        }
        break :blk acc;
    };

    const result: [count + name.len]u8 = comptime blk: {
        var buffer: [count + name.len]u8 = undefined;
        var i: usize = 0;
        var last: bool = false;
        for (name) |c| {
            if (ascii.isUpper(c) and i > 0 and !last) {
                buffer[i] = '_';
                last = true;
                buffer[i + 1] = ascii.toLower(c);
                i = i + 1;
            } else {
                last = ascii.isUpper(c);
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
    try expect("peer_id", toSnakeCase("peerID"));
    try expect("hello_world_test", toSnakeCase("HelloWorldTest"));
    try expect("hello_world_test_case", toSnakeCase("HelloWorldTestCase"));
}

pub fn walkGeneratorMTS(comptime T: anytype, L: *State) void {
    switch (@typeInfo(T)) {
        .@"enum" => |u| {
            const enumType = u.tag_type;
            if (enumType == void) return;
            if (@typeInfo(enumType) != .int) return;

            const name = @typeName(T);
            const lastDot = std.mem.lastIndexOf(u8, name, ".");
            const enumName = if (lastDot) |idx| name[(idx + 1)..] else name;

            L.newTable();
            inline for (std.meta.fields(T)) |field| {
                L.pushInteger(field.value);
                L.setField(-2, field.name);
            }
            L.setGlobal(enumName);
        },
        .@"struct" => {
            MapperStructPtr(T).bind(L);
            inline for (std.meta.fields(T)) |field| {
                switch (@typeInfo(field.type)) {
                    .@"struct" => walkGeneratorMTS(field.type, L),
                    .@"enum" => walkGeneratorMTS(field.type, L),
                    else => {},
                }
            }
        },
        else => {
            return;
        },
    }
}

pub fn EnumMapper(comptime T: anytype) type {
    return struct {
        pub fn bind(L: *State) void {
            switch (@typeInfo(T)) {
                .@"enum" => |u| {
                    const enumType = u.tag_type;
                    if (enumType == void) return;
                    if (@typeInfo(enumType) != .int) return;

                    const name = @typeName(T);
                    const lastDot = std.mem.lastIndexOf(u8, name, ".");
                    const enumName = if (lastDot) |idx| name[(idx + 1)..] else name;

                    L.newTable();
                    inline for (std.meta.fields(T)) |field| {
                        L.pushInteger(field.value);
                        L.setField(-2, field.name);
                    }
                    L.setGlobal(enumName);
                },
                else => {
                    return;
                },
            }
        }
    };
}

pub fn bindFunctions(L: *State, metatableName: []const u8, fns: []const Reg) void {
    L.getMetatableByName(metatableName);
    L.setFuncs(fns);
}

pub fn MapperStructPtr(comptime T: anytype) type {
    return struct {
        pub const metatableName = "mt_" ++ @typeName(T);
        pub const Type = T;
        pub fn bind(L: *State) void {
            _ = L.newMetatable(metatableName);
            L.pushFunction(lua__index);
            L.setField(-2, "__index");
            L.pushFunction(lua__newindex);
            L.setField(-2, "__newindex");
            L.pop(1);
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

        pub fn lua__newindex(L: *State) i32 {
            const self = toUserdata(L, 1) orelse {
                L.pushNil();
                return 1;
            };

            const keyname = L.checkString(2);
            inline for (std.meta.fields(T)) |field| {
                const snakeName = toSnakeCase(field.name);
                if (std.mem.eql(u8, snakeName, keyname)) {
                    switch (@typeInfo(field.type)) {
                        .int => {
                            const value = L.checkInteger(3);
                            @field(self, field.name) = @intCast(value);
                        },
                        .float => {
                            const value = L.checkNumber(3);
                            @field(self, field.name) = @floatCast(value);
                        },
                        .bool => {
                            const value = L.checkBool(3);
                            @field(self, field.name) = value;
                        },
                        .@"enum" => |u| {
                            switch (@typeInfo(u.tag_type)) {
                                .int => {
                                    const value = L.checkInteger(3);
                                    @field(self, field.name) = @enumFromInt(value);
                                },
                                else => {
                                    _ = L.panic("unsupported enum type for field: " ++ field.name);
                                },
                            }
                        },
                        .array => |t| {
                            if (t.child == u8) {
                                const value = L.toString(3);
                                // @field made a copy, need pointer here to modify the original array
                                var ptr = &@field(self, field.name);

                                const min = @min(ptr.len, value.len);
                                const text = value[0..min];

                                @memset(ptr[0..], 0);
                                if (min > 0) {
                                    @memcpy(ptr[0..min], text);
                                }
                            } else {
                                _ = L.panic("unsupported array type for field: " ++ field.name);
                            }
                        },
                        else => {
                            _ = L.panic("unsupported type for field: " ++ field.name);
                        },
                    }
                    return 0;
                }
            }
            _ = L.panic("field no found");
            return 0;
        }

        pub fn lua__index(L: *State) i32 {
            const keyname = L.toString(2);

            _ = L.getMetatable(1);
            L.getField(-1, keyname);
            if (!L.isNil(-1)) {
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
                if (std.mem.eql(u8, keyname, snakeName)) {
                    switch (@typeInfo(field.type)) {
                        // use pointer instead of struct
                        .@"struct" => {
                            const ptr = &@field(self, field.name);
                            L.pushAny(*field.type, ptr);
                        },
                        .array => |arr| {
                            if (arr.child == u8) {
                                L.pushAny(field.type, value);
                            } else {
                                const ptr = &@field(self, field.name);
                                L.pushAny(*field.type, ptr);
                            }
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
        pub fn pushValue(self: *T, name: []const u8, L: *State) bool {
            inline for (std.meta.fields(T)) |field| {
                const snakeName = toSnakeCase(field.name);

                if (std.mem.eql(u8, snakeName, name)) {
                    if (@typeInfo(field.type) == .@"struct") {
                        const ptr: *field.type = &@field(self, field.name);
                        L.pushAny(*field.type, ptr);
                        return true;
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
