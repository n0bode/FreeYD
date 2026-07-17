pub const client = @import("inputs.zig");
pub const server = @import("outputs.zig");
pub const encode = @import("crypto.zig").encrypt;

pub const PacketInput = client.PacketInput;
pub const PacketInputData = client.PacketData;

pub const domains = @import("core").domains;

pub const Opcode = enum(u16) {
    TEXTMESSAGE = 0x101,
    LOGIN = 0x020D,
    PING = 0x3A0,
    PIN = 0x0FDE,
    PIN_FAIL = 0x0FDF,
    CHAR_LIST = 0x010E,
    CHAR_CREATE = 0x020F,
    CHAR_CREATE_FAIL = 0x41D,
    CHAR_CREATED = 0x0110,
    CHAR_DELETE = 0x211,
    CHAR_DELETED = 0x112,
    CHAR_SPAWN = 0x213,
    CHAR_SPAWNED = 0x114,
    MOB_MOTION = 0x366,
    MOB_CREATE = 0x364,
    MOB_DELETE = 0x165,
    ITEM_MOVE = 0x0376,
    ITEM_CREATE = 0x182,
    SET_ATTRIBUTE = 0x277,
    UPDATE_STATS = 0x336,
    MSG_WHISPER = 0x334,
};

// important to encrypt and decrypt message from client and to client
// map = message(header(verifier + opcode + id + user) + packet)
pub const Verifier = extern struct {
    // size of message, contains header + packet
    size: u16 = 0,
    // index of word in key array
    iKeyword: u8 = 0,
    // signature of message
    checksum: u8 = 0,
};

// import to know which opcode and packet server must parse
pub const Header = extern struct {
    verifier: Verifier = .{},
    // operation code to know packet
    operationCode: u16 = 0,
    // peer index
    index: u16 = 0,
    // time of server
    time: u32 = 0,
};
