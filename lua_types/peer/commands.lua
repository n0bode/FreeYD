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
