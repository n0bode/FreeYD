---@meta

-- Fields are exposed with the toSnakeCase() conversion applied to the Zig name.
-- Array-type fields are returned as string; int fields as integer.

---@class Header
---@field operationCode integer
---@field time integer
---@field index integer

---Login packet sent by the client (`PacketLoginInput`).
---@class LoginEvent
---@field header        Header header operation from client
---@field username      string  User login (up to 16 chars)
---@field password      string  Plain-text password (up to 12 chars)
---@field version       integer Client version (e.g. 754)
---@field keys          string  Session keys (16 bytes)
---@field ip_address    string  Client IP address (16 bytes)

---Pin-password packet sent by the client (`PacketPinPasswordInput`).
---@class PinPasswordEvent
---@field header    Header header operation from client
---@field numeric   string 6-digit PIN sequence
---@field unk string need

---Request to create a new character.
---@class CharCreateEvent
---@field header    Header header operation from client
---@field slot      integer Chosen slot (0-3)
---@field name      string  Character name (up to 16 chars)
---@field class     integer Class: 0=Tk · 1=FM · 2=BM · 3=HT


---Request to create a delete character.
---@class CharDeleteEvent
---@field header    Header header operation from client
---@field slot      integer Chosen slot (0-3)
---@field name      string  Character name (up to 16 chars)
---@field password  string Password confirmation


---Character selection / enter world packet (`PacketEnterWorldInput`).
---@class CharSpawnEvent
---@field header    Header header operation from client
---@field char_slot integer Selected character slot

---Inventory item move packet (`PacketMoveItemInput`).
---@class ItemMoveEvent
---@field header         Header header operation from client
---@field dest_storage   integer Destination storage
---@field dest_slot      integer Destination slot
---@field source_storage integer Source storage
---@field source_slot    integer Source slot

---@enum AttributeSection
AttributeSection = {
    STATS = 0,
    SKILLS = 1,
    STATS_SKILLS = 2,
}

---Update attribute packet (`PacketUpdateAttributeInput`).
---@class MobUpdateAttributeEvent
---@field header    Header header operation from client
---@field section   AttributeSection
---@field index     integer  index of attribute to update (0-3), ex: 1 - str
---@field peer_id   integer    peer ID of the character to update

---@class MobMotionEvent
---@field header      Header header operation from client
---@field origin      Position current position coordinate
---@field destination Position destination coordinate
---@field speed       integer Movement speed
---@field kind        integer Action type
---@field routes      integer[]  Raw command data (24 bytes)

---@class ChatWhisperEvent
---@field header    Header header operation from client
---@field name      string  Target character name (up to 16 chars)
---@field message   string  Message content (up to 100 chars)

---@class ChatMessageEvent
---@field header Header
---@field message string max 108 characters

---@class TeleportEvent
---@field header Header
---@field data string

---@enum StorageType
StorageType = {
    INVENTORY = 0,
    EQUIPMENT = 1,
    CARGO = 2,
}

---@class MoveItemEvent
---@field header Header
---@field dest_storage StorageType
---@field dest_slot integer
---@field source_storage StorageType
---@field source_slot integer
