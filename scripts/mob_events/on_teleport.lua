local server = require("server")
local logger = require("logger")
local bit = require("bit")
local math = require("math")

local function coord(x, y)
    return bit.bor(bit.lshift(math.floor(x / 5), 16), math.floor(y / 5))
end

local teleports = {
    [coord(1045, 1725)] = { 2118, 2101 },
    [coord(2118, 2101)] = { 1045, 1725 },
    [coord(2457, 2018)] = { 1045, 1710 },
    [coord(1045, 1710)] = { 2457, 2018 },
    [coord(1045, 1717)] = { 2481, 1717 },
    [coord(2481, 1717)] = { 1045, 1717 },
}

server:on("on_teleport", function(peer, req)
    --logger:info("on_teleport = (" .. peer.peer_id .. ")[" .. tonumber(req.data) .. "]:")

    local char = peer:get_player_mob()
    local origin = { x = char.x, y = char.y };
    local pos = coord(char.x, char.y)
    local world = server:get_world()

    local pos_to = teleports[pos]
    if pos_to then
        logger:info("teleport from (" .. origin.x .. "," .. origin.y .. ") to (" .. pos_to[1] .. "," .. pos_to[2] .. ")")
        world:move_mob(char, pos_to[1], pos_to[2])
        peer:send_command("motion_mob", {
            origin = origin,
            kind = 1,
            speed = 0,
            mob_id = peer.peer_id,
            destination = { x = pos_to[1], y = pos_to[2] },
        })
    end
end)
