local server = require("server")
local logger = require("logger")

server:on("on_mob_action", function(peer, req)
    local position = req.position
    logger:info("source(" .. position.x .. "," .. req.position.y .. ")")
    logger:info("kind: " .. req.kind .. " speed " .. req.speed)
    logger:info("destination(" .. req.destination.x .. "," .. req.destination.y .. ")")

    local account = peer.account
    local char = account:get_current_char();
    if not char then
        logger:error("Character not found for peer " .. peer.peer_id)
        return true
    end

    local mob = char:to_mob(peer.peer_id)
    if not mob then
        logger:error("Failed to convert character to mob for peer " .. peer.peer_id)
        return true
    end

    server:multicast("spawn_mob", {
        position = req.destination,
        mob = mob,
    })
    return true
end)
