const std = @import("std");
const EnvMap = std.process.Environ.Map;

pub fn getEnv(comptime T: anytype, envs: *EnvMap, name: []const u8, defaultValue: T) T {
    const raw = envs.get(name) orelse {
        return defaultValue;
    };

    if (T == []const u8) {
        return raw;
    }

    return switch (@typeInfo(T)) {
        .int => std.fmt.parseInt(T, raw, 10) catch defaultValue,
        .float => std.fmt.parseFloat(T, raw) catch defaultValue,
        .bool => parseBool(raw),
        else => defaultValue,
    };
}

fn parseBool(raw: []const u8) bool {
    return std.fmt.parseInt(u8, raw, 10) catch {
        const lower = std.ascii.lowerString(raw, raw);
        return std.mem.eql(u8, lower, "true");
    } != 0;
}
