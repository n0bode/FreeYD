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

---@class ContextMob
---@field mob Mob
---@field position Position
---@field start_position Position

---@class NPCCreateInfo
---@field name string name in world
---@field position Position start position in world
---@field tick integer? default:1000 tick interval for update npc state
---@field equipments {EquipmentSlot: Item} list of equipments for npc
---@field on_update fun(ctx: ContextMob) Callback invoked every server tick to update the NPC's state. Return true to continue updating, false to stop.
---@field on_interact fun(npc: NPC, peer: Peer) Callback invoked when a player interacts with the NPC

---@class StatsInfo
---@field level integer? default 1
---@field max_hp integer? default 100
---@field max_mp integer? default 100
---@field attack integer? default 50
---@field defense integer? default 10
---@field str integer? default 0
---@field int integer? default 0
---@field dex integer? default 0
---@field con integer? default 0

---@class EnemyCreateInfo
---@field name string name in world
---@field delay integer? default 0 delay in milliseconds before the first update tick
---@field position Position start position in world
---@field tick integer? default:1000 tick interval for update enemy state
---@field stats StatsInfo? combat stats for the enemy
---@field equipments {EquipmentSlot: Item}? list of equipments for the enemy
---@field on_update fun(ctx: ContextMob) Callback invoked every server tick to update the enemy's state
---@field on_interact fun(enemy: NPC, peer: Peer)? Callback invoked when a player interacts with the enemy
---@field on_death fun(ctx: ContextMob)? Callback invoked when the enemy dies
