local server = require("server")
local logger = require("logger")

server:on("on_mob_action", function(peer, req)
    local position = req.position
    logger:info("source(" .. position.x .. "," .. req.position.y .. ")")
    logger:info("kind: " .. req.kind .. " speed " .. req.speed)
    logger:info("destination(" .. req.destination.x .. "," .. req.destination.y .. ")")

    return true
end)
