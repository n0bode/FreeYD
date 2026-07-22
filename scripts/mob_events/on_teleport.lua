local server = require("server")
local logger = require("logger")
local bit = require("bit")
local math = require("math")
local rtree = require("rtree")

---@return Rect
local function coord(x, y)
    return { x = x - 3, y = y - 3, w = 6, h = 6 }
end

local teleports = rtree.new {
    [coord(1045, 1725)] = { 2118, 2101 },
    [coord(2118, 2101)] = { 1045, 1725 },
    [coord(2457, 2018)] = { 1045, 1710 },
    [coord(1045, 1710)] = { 2457, 2018 },
    [coord(1045, 1717)] = { 2481, 1717 },
    [coord(2481, 1717)] = { 1045, 1717 },
    [coord(2141, 2069)] = { 2597, 2125 },
    [coord(2669, 2157)] = { 147, 3788 },
    [coord(147, 3780)]  = { 597, 3770 },
    [coord(3649, 3109)] = { 1053, 1710 },
    [coord(1053, 1710)] = { 3649, 3109 },
}

teleports:query_at(0, 0, function(value)
    logger:info("x = " .. value[1])
end)

server:on("on_teleport", function(peer, req)
    --logger:info("on_teleport = (" .. peer.peer_id .. ")[" .. tonumber(req.data) .. "]:")

    local char = peer:get_player_mob()
    local origin = { x = char.x, y = char.y };
    local world = server:get_world()

    teleports:query_at(char.x, char.y, function(dest)
        logger:info("teleport from (" .. origin.x .. "," .. origin.y .. ") to (" .. dest[1] .. "," .. dest[2] .. ")")
        world:move_mob(char, dest[2], dest[2])

        world:each_mobs(function(mob)
            local mob_id = mob.data.mob_id
            local is_player = mob_id <= tonumber(os.getenv("MAX_PLAYERS"))

            if is_player then
                local npeer = server:get_peer(mob.data.mob_id)
                if npeer == nil then
                    logger:error("peer not found for mob_id " .. mob.data.mob_id)
                    return
                end

                npeer:send_command("motion_mob", {
                    origin = origin,
                    kind = 1,
                    speed = 0,
                    mob_id = peer.peer_id,
                    destination = { x = dest[1], y = dest[2] },
                })
            end
        end)
    end)
end)
