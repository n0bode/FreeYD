---@meta

---@class NPC
---@field id integer npc id in world server
---@field name string mob npc in world
---@field current_position Position
---@field start_position Position
---@field updated_at integer last update time in server
---@field mob Mob
local NPC = {}

---get spawned mob from npc
---@return SpawnedMob
function NPC:get_spawned_mob() end

---@class NPCCreateInfo
---@field name string name in world
---@field position Position start position in world
---@field equipments {EquipmentSlot: Item} list of equipments for npc
---@field on_update fun(npc: NPC, time: integer): boolean? Callback invoked every server tick to update the NPC's state. Return true to continue updating, false to stop.
---@field on_interact fun(npc: NPC, peer: Peer) Callback invoked when a player interacts with the NPC
