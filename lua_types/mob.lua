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
local Mob = {}

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

---Sets an equipment item in the given slot.
---@param slot EquipmentSlot The equipment slot to set
---@param item Item The item to equip
function Mob:set_equipment(slot, item) end

---Gets the equipment item in the given slot.
---@param slot EquipmentSlot The equipment slot to get
---@return Item?
function Mob:get_equipment(slot) end
