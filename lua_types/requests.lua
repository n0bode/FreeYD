---@meta

-- Fields are exposed with the toSnakeCase() conversion applied to the Zig name.
-- Array-type fields are returned as string; int fields as integer.

---Login packet sent by the client (`PacketLoginInput`).
---@class LoginRequest
---@field username   string  User login (up to 16 chars)
---@field password   string  Plain-text password (up to 12 chars)
---@field version    integer Client version (e.g. 754)
---@field keys       string  Session keys (16 bytes)
---@field ip_address  string  Client IP address (16 bytes)

---Pin-password packet sent by the client (`PacketPinPasswordInput`).
---@class PinPasswordRequest
---@field numeric string 6-digit PIN sequence

---Request to create a new character.
---@class CreateCharRequest
---@field slot  integer Chosen slot (0-3)
---@field name  string  Character name (up to 16 chars)
---@field class integer Class: 0=Tk · 1=FM · 2=BM · 3=HT


---Request to create a delete character.
---@class DeleteCharRequest
---@field slot  integer Chosen slot (0-3)
---@field name  string  Character name (up to 16 chars)
---@field password string Password confirmation


---Character selection / enter world packet (`PacketEnterWorldInput`).
---@class EnterWorldRequest
---@field char_slot integer Selected character slot

---Movement/action packet (`PacketActionInput`).
---@class ActionRequest
---@field speed   integer Movement speed
---@field kind    integer Action type
---@field command string  Raw command data (24 bytes)

---Inventory item move packet (`PacketMoveItemInput`).
---@class MoveItemRequest
---@field dest_storage   integer Destination storage
---@field dest_slot      integer Destination slot
---@field source_storage integer Source storage
---@field source_slot    integer Source slot

---Character deletion packet (`PacketCharDeleteInput`).
---@class CharDeleteRequest
---@field slot     integer Slot of the character to delete
---@field name     string  Name for confirmation (up to 16 chars)
---@field password string  Password for confirmation (up to 12 chars)

---@enum AttributeSection
AttributeSection = {
    STATS = 0,
    SKILLS = 1,
    STATS_SKILLS = 2,
}

---Update attribute packet (`PacketUpdateAttributeInput`).
---@class UpdateAttributeRequest
---@field section  AttributeSection
---@field index     integer  index of attribute to update (0-3), ex: 1 - str
---@field peer_id integer    peer ID of the character to update

---@class MobActionRequest
---@field position    Position current position coordinate
---@field destination Position destination coordinate
---@field speed       integer Movement speed
---@field kind        integer Action type
---@field command     string  Raw command data (24 bytes)
