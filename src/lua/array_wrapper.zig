const State = @import("wrapper.zig").State;
const std = @import("std");

const RawSlice = struct {
    ptr: *anyopaque,
    len: usize,
    sizeOf: usize,
    luaType: Types,
    mtName: []const u8,
};

const Types = enum(u8) {
    int,
    float,
    bool,
    metatable,
    string,
};

fn parseLuaType(comptime T: anytype) Types {
    if (T == u8) {
        return .string;
    }
    return switch (@typeInfo(T)) {
        .int => .int,
        .float => .float,
        .bool => .bool,
        .@"struct" => .metatable,
        .array => |p| if (p.child == u8) {
            return .string;
        } else {
            @compileError("lua type not defined for " ++ @typeName(p.child));
        },
        else => {
            @compileError("lua type not defined for " ++ @typeName(T));
        },
    };
}

pub fn pushArray(comptime T: anytype, array: []T, L: State) void {
    if (T == u8) {
        L.pushString(array);
        return;
    }

    const ptr: *RawSlice = L.newUserdata(RawSlice);
    ptr.* = .{
        .len = array.len,
        .ptr = @ptrCast(array.ptr),
        .sizeOf = @sizeOf(T),
        .luaType = parseLuaType(T),
        .mtName = "mt_" ++ @typeName(T),
    };

    L.getMetatableByName("mt_Array");
    _ = L.setMetatable(-2);
}

pub fn bind(L: *State) void {
    _ = L.newMetatable("mt_Array");
    L.pushFunction(lua__index);
    L.setField(-2, "__index");
    L.pop(1);
}

fn lua__index(L: *State) i32 {
    const raw: *RawSlice = L.toUserdata(RawSlice, 1) orelse {
        L.pushNil();
        return 1;
    };

    const index: usize = @intCast(L.toInteger(2));
    const start = (index * raw.sizeOf);
    const end = start + raw.sizeOf;

    if (index > raw.len) {
        L.pushNil();
        return 1;
    }

    const element: []u8 = @as([*]u8, @ptrCast(raw.ptr))[start..end];
    switch (raw.luaType) {
        .bool => {
            L.pushBool(element[0] != 0);
        },
        .int => {
            if (raw.sizeOf == 2) {
                const v: i16 = std.mem.readInt(i16, element[0..2], .native);
                L.pushInteger(@intCast(v));
            } else if (raw.sizeOf == 4) {
                const v: i32 = std.mem.readInt(i32, element[0..4], .native);
                L.pushInteger(@intCast(v));
            } else if (raw.sizeOf == 8) {
                const v: i64 = std.mem.readInt(i64, element[0..8], .native);
                L.pushInteger(@intCast(v));
            } else {
                // TODO: check all size
                L.pushNil();
            }
        },
        .float => {
            if (raw.sizeOf == 4) {
                const v: u32 = std.mem.readInt(u32, element[0..4], .native);
                // TODO: improve imprecision
                L.pushNumber(@floatCast(@as(f32, @bitCast(v))));
            } else if (raw.sizeOf == 8) {
                const v: u64 = std.mem.readInt(u64, element[0..8], .native);
                L.pushNumber(@bitCast(v));
            } else {
                // TODO: check all size
                L.pushNil();
            }
        },
        .metatable => {
            if (!L.hasMetatable(raw.mtName)) {
                L.pushNil();
                return 1;
            }

            const ptr = L.newUserdata(*anyopaque);
            ptr.* = @ptrCast(element.ptr);
            L.getMetatableByName(raw.mtName);
            _ = L.setMetatable(-2);
        },
        .string => {
            L.pushString(@constCast(element));
        },
    }
    return 1;
}

test "create - array" {
    const It2 = struct {
        val: u32,
    };

    const It = struct { b: bool, child: It2 };
    const Array = struct {
        str: [3]u8,
        bools: [2]bool,
        ints: [3]i32,
        uints: [2]u32,
        floats: [2]f32,
        its: [2]It,
    };

    const arr: Array = .{
        .bools = [_]bool{ true, false },
        .ints = [_]i32{ -10, 0, 10 },
        .its = [_]It{
            .{
                .b = true,
                .child = .{ .val = 99 },
            },
            .{
                .b = false,
                .child = .{ .val = 10 },
            },
        },
        .floats = [_]f32{ -999.99, 999.99 },
        .str = [_]u8{ 'o', 'l', 'a' },
        .uints = [_]u32{ 1952, 1953 },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const L = try State.init(arena.allocator());
    defer L.deinit();

    bind(L);

    const vtable = struct {
        fn print(LL: *State) i32 {
            std.log.debug("{s}", .{LL.toString(1)});
            return 0;
        }

        fn expect(LL: *State) i32 {
            if (LL.getLuaType(1) != LL.getLuaType(2) and LL.getLuaType(1) != .Userdata) {
                _ = LL.throw("not equal");
                return 0;
            }
            switch (LL.getLuaType(1)) {
                .Bool => {
                    std.testing.expectEqual(LL.toBoolean(2), LL.toBoolean(1)) catch |err| {
                        _ = LL.throw(@errorName(err));
                        std.debug.print("nao sao igauis", .{});
                        return 0;
                    };
                },
                .String => {
                    std.testing.expectEqualStrings(LL.toString(2), LL.toString(1)) catch {
                        std.debug.print("nao sao igauis", .{});
                        _ = LL.throw("not equal");
                        return 0;
                    };
                },
                .Number => {
                    std.testing.expectApproxEqAbs(LL.toNumber(2), LL.toNumber(1), 1e-4) catch {
                        std.debug.print("expected({any}, {any})\n", .{ LL.toNumber(1), LL.toNumber(2) });
                        _ = LL.throw("not equal");
                        return 0;
                    };
                },
                else => {
                    std.debug.print("not mapped\n", .{});
                    _ = LL.throw("f");
                },
            }
            return 0;
        }

        fn it__index(LL: *State) i32 {
            const it: *It = (LL.toUserdata(*It, 1) orelse {
                LL.pushNil();
                return 1;
            }).*;

            const field = LL.toString(2);
            if (field[0] == 'b') {
                LL.pushBool(it.b);
            } else if (std.mem.eql(u8, field, "child")) {
                const ptr = LL.newUserdata(*It2);
                ptr.* = &it.child;
                _ = LL.getMetatableByName("mt_" ++ @typeName(It2));
                _ = LL.setMetatable(-2);
            } else {
                LL.pushNil();
            }
            return 1;
        }

        fn it2__index(LL: *State) i32 {
            const it: *It2 = (LL.toUserdata(*It2, 1) orelse {
                LL.pushNil();
                return 1;
            }).*;

            const field = LL.toString(2);
            if (std.mem.eql(u8, field, "val")) {
                LL.pushInteger(it.val);
            } else {
                LL.pushNil();
            }
            return 1;
        }
    };

    // metatable it
    _ = L.newMetatable("mt_" ++ @typeName(It));
    L.pushFunction(vtable.it__index);
    L.setField(-2, "__index");
    L.pop(-1);

    _ = L.newMetatable("mt_" ++ @typeName(It2));
    L.pushFunction(vtable.it2__index);
    L.setField(-2, "__index");
    L.pop(-1);

    L.register("expect", vtable.expect);
    L.register("print", vtable.print);
    inline for (std.meta.fields(Array)) |field| {
        const array = @field(arr, field.name);

        pushArray(std.meta.Child(field.type), @ptrCast(@constCast(array[0..])), L.*);
        L.setGlobal(field.name);
    }

    try L.doString(
        \\expect(bools[0], true)
        \\expect(bools[1], false)
        \\-- ints
        \\expect(ints[0], -10)
        \\expect(ints[1], 0)
        \\expect(ints[2], 10)
        \\-- floats
        \\expect(floats[0], -999.99)
        \\expect(floats[1], 999.99)
        \\-- string
        \\expect(str, "ola")
        \\-- structs
        \\ expect(its[0].b, true)
        \\ expect(its[0].child.val, 99)
    );
}
