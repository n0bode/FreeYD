---@meta

---@class SpawnedMob
---@field x integer position x
---@field y integer position x
---@field data Mob

---@class World
---@field players_count integer number of player current in server
local World = {}

---list all mobs in world
---@param func fun(mob: SpawnedMob)
function World:each_mobs(func) end

---get all mobs within area
---@param area QueryArea
---@param func fun(pMob: SpawnedMob)
---@return Mob[]
function World:each_mobs_in_area(area, func) end

---add new mob
---@param mob Mob
---@param x integer
---@param y integer
function World:create_mob(x, y, mob) end

---move mob
---@param mob_spawned SpawnedMob
---@param x integer
---@param y integer
function World:move_mob(mob_spawned, x, y) end
