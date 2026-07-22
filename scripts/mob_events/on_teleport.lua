local server = require("server")
local logger = require("logger")
local multicast = require("scripts.utils.multicast").multicast
local rtree = require("rtree")

---@return Rect
local function coord(x, y)
    return { x = x - 4, y = y - 4, w = 8, h = 8 }
end

local teleports = rtree.new {
    [coord(1045, 1725)] = { x = 2118, y = 2101 },
    [coord(2118, 2101)] = { x = 1045, y = 1725 },
    [coord(2457, 2018)] = { x = 1045, y = 1710 },
    [coord(1045, 1710)] = { x = 2457, y = 2018 },
    [coord(1045, 1717)] = { x = 2481, y = 1717 },
    [coord(2481, 1717)] = { x = 1045, y = 1717 },
    [coord(2141, 2069)] = { x = 2597, y = 2125 },
    [coord(3649, 3109)] = { x = 1053, y = 1710 },
    [coord(1053, 1710)] = { x = 3649, y = 3109 },
    [coord(2669, 2157)] = { x = 0147, y = 3788 },
    [coord(2365, 2284)] = { x = 0147, y = 3788 },
    [coord(0147, 3780)] = { x = 0597, y = 3770 },
    [coord(1313, 1900)] = { x = 2368, y = 4070 },
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
        logger:info("teleport from (" .. origin.x .. "," .. origin.y .. ") to (" .. dest.x .. "," .. dest.y .. ")")

        peer:send_command("motion_mob", {
            origin = origin,
            kind = 1,
            speed = 0,
            mob_id = peer.peer_id,
            destination = dest,
        })
        multicast(origin, dest, function(another, mob, location)
            logger:info("send to " .. another.peer_id)

            -- is mine
            if another.peer_id == peer.peer_id then
                return
            end

            if location == 1 then
                logger:info("delete mob to " .. another.peer_id)
                another:send_command("delete_mob", {
                    mob_id = peer.peer_id,
                })
                peer:send_command("delete_mob", {
                    mob_id = another.peer_id,
                })
            end

            if location == 2 then
                another:send_command("spawn_mob", {
                    position = dest,
                    owner_id = peer.peer_id,
                    mob = char.data,
                })

                peer:send_command("spawn_mob", {
                    position = { x = mob.x, y = mob.y },
                    owner_id = another.peer_id,
                    mob = mob.data,
                })
            end
        end)
        world:move_mob(char, dest.x, dest.y)
    end)
end)
