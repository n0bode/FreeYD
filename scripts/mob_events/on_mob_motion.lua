local server = require("server")
local logger = require("logger")

server:on("on_mob_move", function(peer, req)
    local position = req.origin
    logger:info("source(" .. position.x .. "," .. req.origin.y .. ")")
    logger:info("kind: " .. req.kind .. " speed " .. req.speed)
    logger:info("destination(" .. req.destination.x .. "," .. req.destination.y .. ")")
    logger:info("time: " .. req.header.time);
    logger:info("route: " .. req.routes);

    local account = peer.account
    local char = account:get_current_char();
    if not char then
        logger:error("Character not found for peer " .. peer.peer_id)
        return
    end


    local data = {
        mob_id = peer.peer_id,
        origin = req.origin,
        kind = req.kind,
        speed = req.speed,
        destination = req.destination,
    }


    local opts = {
        -- send time from client
        time = server:get_time(),
        peer_id = peer.peer_id,
        opcode = 0x366,
    }

    logger:info("sent " .. opts.opcode)
    -- notification all peers about new char
    server:multicast("mob_move", data, opts)
end)
