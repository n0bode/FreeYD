---@meta

---@class NPC
---@field id integer npc id in world server
---@field name string mob npc in world
---@field current_position Position
---@field start_position Position
---@field data Mob
local NPC = {}


---@class NPCCreateInfo
---@field name string name in world
---@field position Position start position in world
---@field equipments {EquipmentSlot: Item} list of equipments for npc
---@field on_update fun(npc: NPC) Callback invoked every server tick to update the NPC's state
---@field on_interact fun(npc: NPC, peer: Peer) Callback invoked when a player interacts with the NPC
