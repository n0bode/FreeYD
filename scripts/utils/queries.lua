local server = require("server")
local logger = require("logger")

local function contains(area, point)
    return point.x >= area.x and point.x <= area.x + area.width and
        point.y >= area.y and point.y <= area.y + area.height
end

local function union_area(area1, area2)
    local x1 = math.min(area1.x, area2.x)
    local y1 = math.min(area1.y, area2.y)
    local x2 = math.max(area1.x + area1.width, area2.x + area2.width)
    local y2 = math.max(area1.y + area1.height, area2.y + area2.height)

    return {
        x = x1,
        y = y1,
        width = x2 - x1,
        height = y2 - y1,
    }
end

local function location_id(dest, src, point)
    local inside_dest = contains(dest, point)
    local inside_src = contains(src, point)

    if inside_dest and inside_src then
        return 0
    elseif not inside_dest and inside_src then
        return 1
    elseif inside_dest and not inside_src then
        return 2
    else
        return 3
    end
end

---@class PlayerMobResult
---@field peer Peer
---@field mob Mob

---@class MobResult
---@field mob Mob

---@class GroundItemResult
---@field item ItemWorld

---@enum QueryResultType
local QueryResultType = {
    MOB = 1,
    PLAYER_MOB = 2,
    ITEM = 3,
}

---@class QueryResult
---@field type QueryResultType
---@field position Position
---@field location integer
---@field result MobResult|PlayerMobResult|GroundItemResult
local QueryResult = {}

---@param src  {x: integer, y: integer}
---@param dest  {x: integer, y: integer}
---@param func fun(result: QueryResult)
---@param filter? fun(result: QueryResult): boolean
local function query_areas(src, dest, filter, func)
    local multicast_area = tonumber(os.getenv("MULTICAST_AREA"))

    local r_src = {
        x = src.x - multicast_area / 2,
        y = src.y - multicast_area / 2,
        width = multicast_area,
        height = multicast_area,
    }

    local r_dest = {
        x = dest.x - multicast_area / 2,
        y = dest.y - multicast_area / 2,
        width = multicast_area,
        height = multicast_area,
    }

    local r_total = union_area(r_src, r_dest)
    local map = server:get_world()
    map:each_world_in_area(r_total, function(entity, position, type)
        local location = location_id(r_dest, r_src, position)
        -- outside of both areas, no need to send
        if location == 3 then
            return
        end

        local result = {
            location = location,
            position = position,
        }

        if type == 1 then
            result["type"] = QueryResultType.ITEM
            result["result"] = {
                item = entity,
            }
        else
            if is_player(entity.mob_id) then
                result["type"] = QueryResultType.PLAYER_MOB
                result["result"] = {
                    mob = entity,
                    peer = server:get_peer(entity.mob_id)
                }
            else
                result["type"] = QueryResultType.MOB
                result["result"] = {
                    mob = entity,
                }
            end
        end

        if (not filter) or filter(result) then
            func(result)
        end
    end)
end

---@param src  {x: integer, y: integer}
---@param func fun(result: QueryResult)
---@param filter? fun(result: QueryResult): boolean
local function query_area(src, filter, func)
    query_areas(src, src, filter, func)
end

---@param origin  {x: integer, y: integer}
---@param dest  {x: integer, y: integer}
---@param callback fun(result: QueryResult, is_dest: boolean)
local function query_teleport(origin, dest, callback)
    -- area origin, must delete mob from another player
    query_area(origin, nil, function(result)
        callback(result, false)
    end)

    query_area(dest, nil, function(result)
        callback(result, true)
    end)
end


---@param src  {x: integer, y: integer}
---@param func fun(player: PlayerMobResult, position: Position)
local function players_in_area(src, func)
    query_area(src, function(result)
        return result.type == QueryResultType.PLAYER_MOB
    end, function(result)
        func(result.result, result.position)
    end)
end

---@param src  {x: integer, y: integer}
---@param dest  {x: integer, y: integer}
---@param func fun(player: PlayerMobResult, position: Position, location: integer)
local function players_in_areas(src, dest, func)
    query_areas(src, dest, function(result)
        return result.type == QueryResultType.PLAYER_MOB
    end, function(result)
        func(result.result, result.position, result.location)
    end)
end

return {
    in_areas = query_areas,
    in_area = query_area,
    players_in_area = players_in_area,
    players_in_areas = players_in_areas,
    teleport = query_teleport,
    QueryResultType = QueryResultType,
    QueryResult = QueryResult,
}
