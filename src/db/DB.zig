const core = @import("core");
const domain = core.domains;

pub const DB = @This();

pub const LoginError = error{UsernameNotFound};

pub const filedb = @import("filedb.zig");
