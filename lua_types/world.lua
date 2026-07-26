---@meta

---@class SpawnedMob
---@field x integer position x
---@field y integer position x
---@field position Position
---@field data Mob

---@class World
---@field players_count integer number of player current in server
local World = {}

---list all mobs in world
---@param func fun(mob: SpawnedMob)
function World:each_mobs(func) end

---get all mobs within area
---@param area QueryArea
---@param func fun(mob: Mob, position: Position)
function World:each_mobs_in_area(area, func) end

---add spawn new mob in world
---@param mob Mob
---@param x integer
---@param y integer
function World:spawn_mob(mob, x, y) end

---add spawn new item in world
---@param item Item
---@param x integer
---@param y integer
function World:spawn_item(item, x, y) end

---move object in world
---@param id integer
---@param x integer
---@param y integer
---@return boolean
function World:move(id, x, y) end

---get position object in world
---@param id integer
---@return Position?
function World:get_position(id) end

---remove object in the world
---@param id integer
---@return boolean
function World:remove(id) end
