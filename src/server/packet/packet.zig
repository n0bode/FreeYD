const domain = @import("core").domains;

pub const Opcode = struct {
    pub const LOGIN = 0x020D;
    pub const TEXTMESSAGE = 0x0101;
    pub const CHARLIST = 0x010E;
    pub const PING = 0x03A0;
    pub const PIN = 0x0FDE;
    pub const PINFAIL = 0x0FDF;
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

pub const PacketPing = Header;
pub const PacketSignal = Header;

pub const PacketPin = extern struct {
    header: Header,
    numeric: [6]u8,
    _unknown: [10]u8,
};

pub const PacketCharList = extern struct {
    header: Header,
    characters: domain.CharacterList,
    cargo: [128]domain.Item,
    gold: i32,
    name: [16]u8,
    keys: [16]u16,
    cash: i32,
    // TODO: we need to know what is it
    dorimee: i32,
};

pub const OpcodeRecv = enum(u16) {
    unknown,
    login = Opcode.LOGIN,
    ping = Opcode.PING,
    pin = Opcode.PIN,

    pub fn parse(code: u16) OpcodeRecv {
        return switch (code) {
            Opcode.LOGIN => .login,
            Opcode.PING => .ping,
            Opcode.PIN => .pin,
            else => .unknown,
        };
    }
};

pub const PacketCharCreate = extern struct {
    header: Header,

    slot: i32,
    name: [16]u8,
    class: i32,
};

pub const PacketOpcode = enum(u16) {
    unknown,
    login = Opcode.LOGIN,
    textmessage = Opcode.TEXTMESSAGE,
    charlist = Opcode.CHARLIST,
    ping = Opcode.PING,

    pub fn parse(code: u16) PacketOpcode {
        return switch (code) {
            Opcode.LOGIN => PacketOpcode.login,
            Opcode.TEXTMESSAGE => PacketOpcode.textmessage,
            Opcode.PING => PacketOpcode.ping,
            else => .unknown,
        };
    }
};

pub const Packet = union(OpcodeRecv) {
    unknown: Header,
    login: PacketLogin,
    ping: PacketPing,
    pin: PacketPin,
};
