local server = require("server")

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

---@param src  {x: integer, y: integer}
---@param dest  {x: integer, y: integer}
---@param func fun(peer: Peer, mob: SpawnedMob, location: integer)
local function multicast(src, dest, func)
    local multicast_area = tonumber(os.getenv("MULTICAST_AREA"))
    local max_players = tonumber(os.getenv("MAX_PLAYERS"))

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
    map:each_mobs_in_area(r_total, function(spawned_mob)
        local mob = spawned_mob.data
        local mob_id = mob.mob_id

        local mob_pos = { x = spawned_mob.x, y = spawned_mob.y }
        local is_player = mob_id <= max_players

        if is_player then
            local another_peer = server:get_peer(mob.mob_id)
            if another_peer then
                local location = location_id(r_dest, r_src, mob_pos)
                -- outside of both areas, no need to send
                if location == 3 then
                    return
                end
                func(another_peer, spawned_mob, location)
            end
        end
    end)
end

return {
    multicast = multicast
}
