const std = @import("std");
const c = @import("lua.zig").c;

pub const FNFunction = *const fn (state: *State) i32;

const Allocator = std.mem.Allocator;
const LuaState = ?*c.lua_State;
const ArrayWrapper = @import("array_wrapper.zig");

pub const LuaFN = *const fn (LuaState) callconv(.c) c_int;

//fn Malloc(userdata: ?*anyopaque, pAddr: ?*anyopaque, oldSize: usize, newSize: usize) callconv(.c) ?*anyopaque {
//    std.debug.print("u{any} add{any} old{any} new{any}\n", .{ userdata, pAddr, oldSize, newSize });
//    const ptr = userdata orelse return null;
//    const self: *State = @ptrCast(@alignCast(ptr));
//    const allocator = self.allocator;
//
//    // 1. Comportamento 'FREE'
//    if (newSize == 0) {
//        if (pAddr) |addr| {
//            // Conversão segura usando ponteiro C
//            const c_ptr: [*c]u8 = @ptrCast(addr);
//            // Slices criadas a partir de [*c] precisam delimitar o tamanho estrito
//            allocator.free(c_ptr[0..oldSize]);
//        }
//        return null;
//    }
//
//    // 2. Comportamento 'REALLOC'
//    if (pAddr) |addr| {
//        const c_ptr: [*c]u8 = @ptrCast(addr);
//        const oldBuffer = c_ptr[0..oldSize];
//
//        const nPtr = allocator.realloc(oldBuffer, newSize) catch return null;
//        return nPtr.ptr;
//    }
//
//    // 3. Comportamento 'MALLOC'
//    const nPtr = allocator.alloc(u8, newSize) catch return null;
//    @memset(nPtr, 0);
//    return nPtr.ptr;
//}

const alignment = std.mem.Alignment.of(std.c.max_align_t);
const alignsize = alignment.toByteUnits();

fn Malloc(userdata: ?*anyopaque, pAddr: ?*anyopaque, oldSize: usize, newSize: usize) callconv(.c) ?*anyopaque {
    const ptr = userdata orelse return null;
    const self: *State = @ptrCast(@alignCast(ptr));
    const allocator = self.allocator;

    if (pAddr) |addr| {
        const pBuffer: [*]align(alignsize) u8 = @ptrCast(@alignCast(addr));
        const oldBuffer = pBuffer[0..oldSize];
        // realloc do: free and realloc
        return (allocator.realloc(oldBuffer, newSize) catch return null).ptr;
    }

    const new_memory = allocator.alignedAlloc(u8, alignment, newSize) catch return null;
    @memset(new_memory, 0);
    return new_memory.ptr;
}

fn lua_upvalueindex(index: c_int) c_int {
    return c.LUA_GLOBALSINDEX - index;
}

fn wrapCFunc(L: LuaState) callconv(.c) c_int {
    var state = State.wrap(L);
    // the function pointer must be an upvalue
    const pFunc = state.toUserdata(FNFunction, state.upValueIndex(1));
    if (pFunc) |ptr| {
        const func: FNFunction = @ptrCast(@alignCast(ptr));
        return @intCast(func(&state));
    }
    return 0;
}

const logger = std.log.scoped(.lua);
fn printLua(state: *State) i32 {
    const str = state.toString(-1);
    logger.info("lua printf('{s}')", .{str});
    return 0;
}

fn luaPanicCallback(L: LuaState) callconv(.c) c_int {
    const msg = State.wrap(L).toString(-1);

    std.log.err("LUA PANIC: {s}", .{msg});
    return 0; // Isso vai deixar o Lua dar o exit padrão, mas agora você viu o erro.
}

pub const RegValue = union(enum) {
    func: struct {
        func: FNFunction,
        userdata: ?*anyopaque = null,
    },
    int: i64,
    float: f64,
};

pub const Reg = struct {
    name: []const u8,
    value: RegValue,
};

pub const LuaType = enum(c_int) {
    Function = c.LUA_TFUNCTION,
    String = c.LUA_TSTRING,
    Bool = c.LUA_TBOOLEAN,
    Number = c.LUA_TNUMBER,
    Userdata = c.LUA_TUSERDATA,
    LightUserdata = c.LUA_TLIGHTUSERDATA,
    Table = c.LUA_TTABLE,
    Nil = c.LUA_TNIL,
    None = c.LUA_TNONE,
};

fn proxyLog(L: *State, log: fn (comptime []const u8, anytype) void) void {
    switch (L.getLuaType(-1)) {
        .String => {
            const str = L.toString(-1);
            log("{s}", .{str});
        },
        .Number => {
            const num = L.toNumber(-1);
            log("{any}", .{num});
        },
        .Bool => {
            const b = L.toBoolean(-1);
            log("{any}", .{b});
        },
        .Userdata => {
            const ptr = L.toUserdataPtr(-1);
            if (L.getMetatable(-1)) {
                L.getField(-1, "__name");
                const name = L.toString(-1);
                log("({s})#{any}", .{ name, ptr });
            } else {
                log("userdata(#{any})", .{ptr});
            }
        },
        else => {},
    }
}

fn lua__info_logger(L: *State) i32 {
    proxyLog(L, logger.info);
    return 0;
}

fn lua__debug_logger(L: *State) i32 {
    proxyLog(L, logger.debug);
    return 0;
}

fn lua__error_logger(L: *State) i32 {
    proxyLog(L, logger.err);
    return 0;
}

fn lua__warn_logger(L: *State) i32 {
    proxyLog(L, logger.warn);
    return 0;
}

pub const State = struct {
    L: LuaState,
    allocator: Allocator,

    pub fn init(allocator: Allocator) !*State {
        var self = try allocator.create(State);
        self.allocator = allocator;
        //self.L = c.luaL_newstate();
        self.L = c.lua_newstate(Malloc, self);

        c.luaL_openlibs(self.L);
        _ = c.lua_atpanic(self.L, luaPanicCallback);
        self.bindingLogger();
        self.register("print", printLua);
        ArrayWrapper.bind(self);

        return self;
    }

    pub fn pcall(self: State, nArgs: u32, nResults: u32) bool {
        return c.lua_pcall(self.L, @intCast(nArgs), @intCast(nResults), 0) == c.LUA_OK;
    }

    fn bindingLogger(self: *State) void {
        self.newLib("logger", &.{
            .{
                .name = "info",
                .value = .{
                    .func = .{ .func = lua__info_logger },
                },
            },
            .{
                .name = "error",
                .value = .{
                    .func = .{ .func = lua__error_logger },
                },
            },
            .{
                .name = "debug",
                .value = .{
                    .func = .{ .func = lua__debug_logger },
                },
            },
            .{
                .name = "warn",
                .value = .{
                    .func = .{ .func = lua__warn_logger },
                },
            },
        });
    }

    fn wrap(L: LuaState) State {
        return .{
            .allocator = undefined,
            .L = L,
        };
    }

    pub fn deinit(self: *State) void {
        self.allocator.destroy(self);
    }

    pub fn loadFile(self: State, path: []const u8) !void {
        const nPath = try self.allocator.dupeZ(u8, path);
        defer self.allocator.free(nPath);

        if (c.luaL_loadfile(self.L, nPath) != c.LUA_OK) {
            std.log.err("failed to load file ({s}): {s}", .{ path, self.toString(-1) });
            return error.LoadFileError;
        }
    }

    pub fn doFile(self: State, path: []const u8) !void {
        try self.loadFile(path);
        if (!self.pcall(0, 0)) {
            logger.err("lua error: {s}", .{self.toString(-1)});
            return error.DoFile;
        }
    }

    pub fn loadString(self: State, script: []const u8) !void {
        if (c.luaL_loadstring(self.L, script.ptr) != c.LUA_OK) {
            logger.err("lua error: {s}", .{self.toString(-1)});
            return error.LoadString;
        }
    }

    pub fn toUserdataPtr(self: State, idx: i32) ?*anyopaque {
        return c.lua_touserdata(self.L, @intCast(idx));
    }

    pub fn toUserdata(self: State, comptime T: anytype, idx: i32) ?*T {
        return @ptrCast(@alignCast(c.lua_touserdata(self.L, idx)));
    }

    pub fn checkUserdata(self: State, comptime T: anytype, idx: i32, mtName: []const u8) ?*T {
        return @ptrCast(@alignCast(c.luaL_checkudata(self.L, idx, mtName.ptr)));
    }

    pub fn toInteger(self: State, comptime T: anytype, idx: i32) T {
        if (@typeInfo(T) != .int)
            @compileError("checkInteger only supports integer types");
        return @intCast(c.lua_tointeger(self.L, idx));
    }

    pub fn toNumber(self: State, idx: i32) f64 {
        return @floatCast(c.lua_tonumber(self.L, idx));
    }

    pub fn pushBool(self: State, boolean: bool) void {
        return c.lua_pushboolean(self.L, if (boolean) 1 else 0);
    }

    pub fn upValueIndex(self: State, idx: i32) i32 {
        _ = self;
        return c.LUA_GLOBALSINDEX - idx;
    }

    pub fn checkType(self: State, idx: i32, luaType: LuaType) void {
        c.luaL_checktype(self.L, @intCast(idx), @intFromEnum(luaType));
    }

    pub fn next(self: State, idx: i32) bool {
        return c.lua_next(self.L, @intCast(idx)) != 0;
    }

    pub fn newUserdata(self: State, comptime T: anytype) *T {
        return @ptrCast(@alignCast(c.lua_newuserdata(self.L, @sizeOf(T))));
    }

    pub fn toFunction(self: State, idx: i32) ?LuaFN {
        const func = c.lua_tocfunction(self.L, @intCast(idx));
        return @ptrCast(func);
    }

    // save a ref by index on registry
    pub fn saveRegistry(self: State, idx: i32) i32 {
        self.pushValue(idx);
        return @intCast(c.luaL_ref(self.L, c.LUA_REGISTRYINDEX));
    }

    pub fn restoreRegistry(self: State, regId: i32) void {
        c.lua_rawgeti(self.L, c.LUA_REGISTRYINDEX, regId);
    }

    pub fn removeRegistry(self: State, regId: i32) void {
        c.luaL_unref(self.L, c.LUA_REGISTRYINDEX, regId);
    }

    pub fn isType(self: State, idx: i32, luaType: LuaType) bool {
        return self.getLuaType(idx) == luaType;
    }

    pub fn getMetatableByName(self: State, name: []const u8) void {
        self.getField(c.LUA_REGISTRYINDEX, name);
    }

    pub fn getMetatable(self: State, idx: i32) bool {
        return c.lua_getmetatable(self.L, idx) == 1;
    }

    pub fn getMetatableName(self: State, idx: i32) ?[]const u8 {
        if (self.getMetatable(idx)) {
            self.getField(-1, "__name");
            const name = self.toString(-1);
            // remove metatable
            self.pop(1);
            return name;
        }
        return null;
    }

    pub fn hasMetatable(self: State, name: []const u8) bool {
        self.getMetatableByName(name);
        defer self.pop(1);
        return !self.isNil(-1);
    }

    pub fn doString(self: State, script: []const u8) !void {
        try self.loadString(script);
        if (!self.pcall(0, 0)) {
            return error.Pcall;
        }
    }

    pub fn toString(self: State, index: c_int) []const u8 {
        var size: usize = 0;
        const str = c.lua_tolstring(self.L, index, &size);
        return str[0..size];
    }

    pub fn pushString(self: State, str: []const u8) void {
        c.lua_pushlstring(self.L, str.ptr, str.len);
    }

    pub fn pushNil(self: State) void {
        c.lua_pushnil(self.L);
    }

    pub fn pushFunction(self: State, FN: FNFunction) void {
        self.pushLightUserdata(@ptrCast(@constCast(FN)));
        c.lua_pushcclosure(self.L, wrapCFunc, 1);
    }

    pub fn pushClosure(self: State, upValues: i32) void {
        c.lua_pushcclosure(self.L, wrapCFunc, @intCast(upValues));
    }

    pub fn register(self: State, methodName: []const u8, func: FNFunction) void {
        c.lua_pushlightuserdata(self.L, @ptrCast(@constCast(func)));
        self.pushClosure(1);
        self.setGlobal(methodName);
    }

    pub fn addPrint(self: State) void {
        //c.lua_pushlightuserdata(self.L, @ptrCast(@constCast(func)));
        c.lua_pushcclosure(self.L, State.printLua, 0);
        self.setGlobal("printc");
    }

    pub fn pushLightUserdata(self: State, ptr: *anyopaque) void {
        c.lua_pushlightuserdata(self.L, ptr);
    }

    pub fn setField(self: State, idx: i32, name: []const u8) void {
        c.lua_setfield(self.L, @intCast(idx), name.ptr);
    }

    pub fn pushInteger(self: State, int: i64) void {
        c.lua_pushinteger(self.L, @intCast(int));
    }

    pub fn pushNumber(self: State, float: f64) void {
        c.lua_pushnumber(self.L, @floatCast(float));
    }

    pub fn pushAny(self: State, comptime T: anytype, data: T) void {
        switch (@typeInfo(T)) {
            .bool => {
                self.pushBool(data);
            },
            .int => {
                self.pushInteger(@intCast(data));
            },
            .float => {
                self.pushNumber(@floatCast(data));
            },
            .array => |arr| {
                if (arr.child == u8) {
                    self.pushString(std.mem.sliceTo(data[0..], 0));
                } else {
                    ArrayWrapper.pushArray(arr.child, @ptrCast(@constCast(data[0..])), self);
                }
            },
            .@"struct" => {
                const mtName = "mt_" ++ @typeName(T);
                // WATCH: memory descenessary
                if (self.hasMetatable(mtName)) {
                    const ptr = self.newUserdata(T);
                    ptr.* = data;
                    self.getMetatableByName(mtName);
                    _ = self.setMetatable(-2);
                } else {
                    self.pushNil();
                }
            },
            .pointer => |pT| {
                switch (@typeInfo(pT.child)) {
                    .@"struct" => {
                        // more eficient
                        const mtName = "mt_" ++ @typeName(pT.child);
                        if (self.hasMetatable(mtName)) {
                            const ptr = self.newUserdata(T);
                            ptr.* = data;
                            self.getMetatableByName(mtName);
                            self.checkType(-1, .Table);
                            _ = self.setMetatable(-2);
                        } else {
                            self.pushNil();
                        }
                    },
                    // *[N]T: pass the slice pointing to the actual array in memory
                    .array => |arr| {
                        if (arr.child == u8) {
                            self.pushString(std.mem.sliceTo(data[0..], 0));
                        } else {
                            ArrayWrapper.pushArray(arr.child, data[0..], self);
                        }
                    },
                    else => {
                        // recursive
                        self.pushAny(pT.child, data.*);
                    },
                }
            },
            .@"enum" => {
                self.pushInteger(@intFromEnum(data));
            },
            .optional => |opt| {
                if (data == null) self.pushNil();

                switch (@typeInfo(opt.child)) {
                    .@"struct" => {
                        // more eficient
                        const mtName = "mt_" ++ @typeName(opt.child);
                        if (self.hasMetatable(mtName)) {
                            const ptr = self.newUserdata(T);
                            ptr.* = data;
                            self.getMetatableByName(mtName);
                            self.checkType(-1, .Table);
                            _ = self.setMetatable(-2);
                        } else {
                            self.pushNil();
                        }
                    },
                    // *[N]T: pass the slice pointing to the actual array in memory
                    .array => |arr| {
                        if (arr.child == u8) {
                            self.pushString(std.mem.sliceTo(data[0..], 0));
                        } else {
                            ArrayWrapper.pushArray(arr.child, data[0..], self);
                        }
                    },
                    else => {
                        // recursive
                        self.pushAny(opt.child, data.?);
                    },
                }
            },
            else => {
                @compileError("unsupported type: " ++ @typeName(T));
            },
        }
    }

    pub fn setGlobal(self: State, name: []const u8) void {
        c.lua_setfield(self.L, c.LUA_GLOBALSINDEX, name.ptr);
    }

    pub fn panic(self: State, message: []const u8) i32 {
        self.pushString(message);
        return c.lua_error(self.L);
    }

    pub fn throw(self: State, message: []const u8) i32 {
        self.pushNil();
        self.pushString(message);
        return 2;
    }

    pub fn setFuncs(self: State, funcs: []const Reg) void {
        for (funcs) |r| {
            switch (r.value) {
                .func => |f| {
                    self.pushLightUserdata(@ptrCast(@constCast(f.func)));
                    if (f.userdata) |userdata| {
                        self.pushLightUserdata(userdata);
                        self.pushClosure(2);
                    } else {
                        self.pushClosure(1);
                    }
                },
                .int => |i| {
                    self.pushInteger(i);
                },
                .float => |f| {
                    self.pushNumber(f);
                },
            }
            self.setField(-2, r.name);
        }
    }

    pub fn createTable(self: State, nArr: i32, nRec: i32) void {
        c.lua_createtable(self.L, @intCast(nArr), @intCast(nRec));
    }

    pub fn newTable(self: *State) void {
        self.createTable(0, 0);
    }

    pub fn getField(self: State, idx: i32, name: []const u8) void {
        c.lua_getfield(self.L, @intCast(idx), name.ptr);
    }

    pub fn getLuaType(self: State, idx: i32) LuaType {
        const t = c.lua_type(self.L, idx);
        return @enumFromInt(t);
    }

    pub fn isNil(self: State, idx: i32) bool {
        return self.getLuaType(idx) == .Nil;
    }

    pub fn getGlobal(self: State, name: []const u8) void {
        return self.getField(c.LUA_GLOBALSINDEX, name);
    }

    pub fn pushValue(self: State, idx: i32) void {
        c.lua_pushvalue(self.L, @intCast(idx));
    }

    pub fn setTop(self: State, v: i32) void {
        c.lua_settop(self.L, @intCast(v));
    }

    pub fn getTop(self: State) i32 {
        return @intCast(c.lua_gettop(self.L));
    }

    pub fn toBoolean(self: State, idx: i32) bool {
        return c.lua_toboolean(self.L, idx) != 0;
    }

    pub fn pop(self: State, v: i32) void {
        self.setTop(@intCast(-v - 1));
    }

    pub fn newLib(self: State, libName: []const u8, funcs: []const Reg) void {
        self.getGlobal("package");
        self.getField(-1, "loaded");

        self.createTable(@intCast(funcs.len), @intCast(funcs.len));
        self.setFuncs(funcs);
        self.setField(-2, libName);

        self.pop(self.getTop());
    }

    pub fn newMetatable(self: State, tableName: []const u8) i32 {
        return @intCast(c.luaL_newmetatable(self.L, tableName.ptr));
    }

    pub fn setMetableByName(self: State, tableName: []const u8) void {
        c.luaL_setmetatable(self.L, tableName.ptr);
    }

    pub fn setMetatable(self: State, idx: i32) i32 {
        return c.lua_setmetatable(self.L, idx);
    }

    pub fn checkString(self: State, idx: i32) []const u8 {
        var size: usize = 0;
        const text = c.luaL_checklstring(self.L, idx, &size);
        return text[0..size];
    }

    pub fn checkInteger(self: State, comptime T: anytype, idx: i32) T {
        if (@typeInfo(T) != .int)
            @compileError("checkInteger only supports integer types");
        return @intCast(c.luaL_checkinteger(self.L, idx));
    }

    pub fn checkNumber(self: State, comptime T: comptime_float, idx: i32) T {
        if (@typeInfo(T) != .int or @typeInfo(T) != .float)
            @compileError("checkNumber only supports numeric types integer or float");
        return @floatCast(c.luaL_checknumber(self.L, idx));
    }

    pub fn isBoolean(self: State, idx: i32) bool {
        return self.getLuaType(idx) == .Bool;
    }

    pub fn isNumber(self: State, idx: i32) bool {
        return self.getLuaType(idx) == .Number;
    }

    pub fn isString(self: State, idx: i32) bool {
        return self.getLuaType(idx) == .String;
    }

    pub fn isFunction(self: State, idx: i32) bool {
        return self.getLuaType(idx) == .Function;
    }

    pub fn isTable(self: State, idx: i32) bool {
        return self.getLuaType(idx) == .Table;
    }

    pub fn isUserdata(self: State, idx: i32) bool {
        return self.getLuaType(idx) == .Userdata;
    }

    pub fn isLightUserdata(self: State, idx: i32) bool {
        return self.getLuaType(idx) == .LightUserdata;
    }

    pub fn isNone(self: State, idx: i32) bool {
        return self.getLuaType(idx) == .None;
    }
};

//const testing = std.testing;
//test "lua - load script" {
//    const allocator = testing.allocator;
//
//    var state = try State.init(allocator);
//    defer state.deinit();
//
//    const script =
//        \\print("ola mundo")
//    ;
//    try state.loadString(script);
//}
const testing = @import("std").testing;
test {
    testing.refAllDecls(@This());
}
