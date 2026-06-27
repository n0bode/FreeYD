const std = @import("std");

pub fn ParseArgs(comptime T: anytype) type {
    return struct {
        pub const ArgumentHandler = *const fn (*T, []const u8) anyerror!void;

        pub const Argument = struct {
            name: []const u8,
            handler: ArgumentHandler,
        };

        const HashMap = std.StaticStringMap(ArgumentHandler);
        arguments: []const Argument,
        mapArguments: HashMap,

        pub fn init(comptime arguments: []const Argument) @This() {
            const tuple = struct { []const u8, ArgumentHandler };
            const pairs = comptime blk: {
                var temp_pairs: [arguments.len]tuple = undefined;
                for (arguments, 0..) |arg, i| {
                    temp_pairs[i] = .{ arg.name, arg.handler };
                }
                break :blk temp_pairs;
            };

            return .{
                .arguments = arguments,
                .mapArguments = .initComptime(pairs),
            };
        }

        pub fn parse(self: @This(), argsIterator: anytype, parent: *T) !void {
            var iter = argsIterator;
            while (iter.next()) |key| {
                if (hasPrefix(key, "--") and key.len > 2) {
                    const name = key[2..];
                    if (self.mapArguments.get(name)) |handler| {
                        if (iter.next()) |value| {
                            try @call(.auto, handler, .{ parent, value });
                        }
                    }
                }
            }
        }
    };
}

fn hasPrefix(text: []const u8, prefix: []const u8) bool {
    return text.len >= prefix.len and std.mem.eql(u8, text[0..prefix.len], prefix);
}

const expect = std.testing.expectEqualStrings;
test "it should init a new config" {
    const Type = ParseArgs(bool);
    _ = Type.init(&[_]Type.Argument{
        .{ .name = "value1", .handler = undefined },
        .{ .name = "value2", .handler = undefined },
    });
}

test "it should parse" {
    std.testing.log_level = .debug;
    const Context = struct {
        pub fn empty() @This() {
            return .{ .key = "", .hello = "" };
        }
        key: []const u8,
        hello: []const u8,

        fn setKey(self: *@This(), newValue: []const u8) !void {
            self.key = newValue;
        }

        fn setHello(self: *@This(), newValue: []const u8) !void {
            self.hello = newValue;
        }
    };

    const Type = ParseArgs(Context);
    var ctx: Context = .empty();
    var config = Type.init(&[_]Type.Argument{
        .{ .name = "key", .handler = Context.setKey },
        .{ .name = "hello", .handler = Context.setHello },
    });

    const cmdLines =
        \\
        \\--key value
        \\--hello world
        \\nothing to say
    ;

    var iter = std.mem.splitAny(u8, cmdLines, " \n\r");
    try config.parse(&iter, &ctx);

    try expect("value", ctx.key);
    try expect("world", ctx.hello);
}
