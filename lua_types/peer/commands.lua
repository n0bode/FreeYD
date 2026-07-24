---@meta
---


---@enum MoveKind
MoveKind = {
    WALK = 0,
    TELEPORT = 1,
}

---@enum MoveDirection
MoveDirection = {
    LEFT = 6,
    RIGTH = 4,
}


---@class CharSpawnCommand
---@field position Position
---@field character Character

---command to create
---@class MobSpawnCommand
---@field position Position
---@field owner_id integer
---@field mob Mob

---@class MobMotionCommand
---@field origin Position
---@field destination Position
---@field kind MoveKind
---@field speed integer (0-15)
---@field mob_id integer
---@field routes? MoveDirection[] optional

---@class MobDeleteCommand
---@field mob_id integer

---@class ItemMoveCommand
---@field storage StorageType
---@field slot integer
---@field mob_id integer
---@field item Item

---@class UpdateEquipmentsCommand
---@field mob Mob

---@enum ChatType
ChatType = {
    NORMAL = 0,
    WHISPER = 1,
    PARTY = 2,
    GLOBAL = 3,
    GUILD = 4,
    SHOUT = 5,
}

---@class ChatMessageCommand
---@field message string
---@field type ChatType
---@field mob_id integer mob id / peer id
