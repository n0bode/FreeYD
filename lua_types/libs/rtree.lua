---@meta
---@class RTree
local RTree = {};

--- query values in rtree inside region
---@param x integer
---@param y integer
---@param func fun(value: any)
---@return boolean
function RTree:query_at(x, y, func) end

---@class Rect
---@field x integer
---@field y integer
---@field w integer
---@field h integer

---@alias Pair {[Rect]: any}

---create new rtree structure
---@param values Pair
---@return RTree
function new(values) end

return {
    new = new,
}
