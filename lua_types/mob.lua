---@meta
---

---@class Mob
---@field mob_id integer
---@field name string
---@field pk_level integer
---@field current_kill integer
---@field total_kill integer
---@field equipments Item[]
---@field buffers Buffer[]
---@field guild_id integer
---@field stats Stats
---@field spawn_type integer
---@field tab string text used in game above the mob head

---@class StatsState
---@field merchant integer
---@field direction integer
---@field movement_speed integer
---@field pk_level integer

---@class Stats
---@field level integer
---@field defense integer
---@field attack integer
---@field state StatsState
---@field max_hp integer
---@field max_mp integer
---@field hp integer
---@field mp integer
---@field str integer
---@field int integer
---@field dex integer
---@field con integer
---@field skills SkillAttributes

---@class Buffer
---@field index integer
---@field time integer

---@class ResistStats
---@field ice integer
---@field fire integer
---@field element integer
---@field lighting integer
