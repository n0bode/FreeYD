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

---@class CharacterSpawnCommand
---@field position Position
---@field character Character
CharacterSpawn = {}

---command to create
---@class MobSpawnCommand
---@field position Position
---@field owner_id integer
---@field mob Mob
MobSpawn = {}

---@class MobMoveCommand
---@field origin Position
---@field destination Position
---@field kind MoveKind
---@field speed integer (0-15)
---@field mob_id integer
---@field routes? MoveDirection[] optional
MobMove = {}
