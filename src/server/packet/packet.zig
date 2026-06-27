const domain = @import("core").domains;

pub const Opcode = struct {
    pub const LOGIN = 0x020D;
    pub const TEXTMESSAGE = 0x0101;
    pub const CHARLIST = 0x010E;
};

pub const Verifier = extern struct {
    size: u16,
    iKeyword: u8,
    checksum: u8,
};

pub const Header = extern struct {
    verifier: Verifier,
    operationCode: u16,
    index: u16,
    time: u32,
};

pub const PacketTextMessage = extern struct {
    header: Header,
    message: [96]u8,
};

pub const PacketLogin = extern struct {
    header: Header,
    username: [16]u8,
    password: [12]u8,
    version: i32,
    none: i32,
    keys: [16]u8,
    ipaddress: [16]u8,
};

pub const PacketCharList = extern struct {
    header: Header,
    characters: domain.CharacterList,
    cargo: [128]domain.Item,
    gold: i32,
    name: [16]u16,
    keys: [16]u16,
    cash: i32,
    // TODO: we need to know what is it
    dorimee: i32,
};

pub const PacketOpcode = enum(u16) {
    unknown,
    login = Opcode.LOGIN,
    textmessage = Opcode.TEXTMESSAGE,

    pub fn parse(code: u16) PacketOpcode {
        return switch (code) {
            Opcode.LOGIN => PacketOpcode.login,
            Opcode.TEXTMESSAGE => PacketOpcode.textmessage,
            else => .unknown,
        };
    }
};

pub const Packet = union(PacketOpcode) {
    unknown: Header,
    login: PacketLogin,
    textmessage: PacketTextMessage,
};
