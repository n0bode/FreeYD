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
    ITEM_MOVED = 0x182,
    UPDATE_EQUIPMENTS = 0x36B,
    UPDATE_STATS = 0x336,
    SET_ATTRIBUTE = 0x277,
    MSG_WHISPER = 0x334,
    TELEPORT = 0x290,
    MOB_INTERACT = 0x27B,
    MSG_CHAT = 0x333,
    DROP_ITEM = 0x272,
    CREATE_GROUND_ITEM = 0x26E,
    DELETE_GROUND_ITEM = 0x16F,
    INTERACT_GROUND_ITEM = 0x374,
    //ON_ATTACK = 0x367,
    ON_ATTACK_ONE = 0x39D,
    ON_ATTACK_TWO = 0x39E,
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
// size (12)
pub const Header = extern struct {
    verifier: Verifier = .{},
    // operation code to know packet
    operationCode: u16 = 0,
    // peer index
    index: u16 = 0,
    // time of server
    time: u32 = 0,
};
