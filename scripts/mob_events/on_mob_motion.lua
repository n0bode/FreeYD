local server = require("server")
local logger = require("logger")

server:on("on_motion_mob", function(peer, req)
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

    local area = tonumber(os.getenv("MULTICAST_AREA"))
    local rect = {
        x = char.position.x - area / 2,
        y = char.position.y - area / 2,
        width = area,
        height = area,
    }

    local opts = {
        -- replace peer_id from server to peer sender
        peer_id = peer.peer_id,
        filter = function(receiver)
            -- ignore o sender
            return receiver.peer_id ~= peer.peer_id
        end
    }

    local data = {
        mob_id = peer.peer_id,
        origin = req.origin,
        kind = req.kind,
        speed = req.speed,
        destination = req.destination,
    }
    server:multicast_command_in_area("mob_move", rect, data, opts)
end)
