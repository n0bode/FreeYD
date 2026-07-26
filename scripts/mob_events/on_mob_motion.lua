local server = require("server")
local logger = require("logger")
local multicast = require("scripts.utils.multicast").multicast

server:on("on_motion_mob", function(peer, req)
    local map = server:get_world()

    local position = map:get_position(peer.peer_id)
    if not position then
        logger:error("peer " .. peer.peer_id .. " has no position")
        return
    end

    local last_pos = { x = position.x, y = position.y }

    -- move player in world
    local player_mob = peer:get_player_mob()
    map:move(peer.peer_id, req.destination.x, req.destination.y)

    local pos = map:get_position(peer.peer_id)
    if pos then
        logger:info("peer " .. peer.peer_id .. " moved to " .. pos.x .. "," .. pos.y)
    else
        logger:error("peer " .. peer.peer_id .. " has no position after move")
    end

    local dest = { x = req.destination.x, y = req.destination.y };
    multicast(req.origin, req.destination, function(another_peer, mob, mob_pos, location)
        if another_peer == peer then
            return
        end
        -- visible to both areas, send motion
        if location == 0 then
            another_peer:send_command("motion_mob", {
                origin = position,
                kind = req.kind,
                speed = req.speed,
                mob_id = peer.peer_id,
                destination = dest,
            })
            return
        end

        -- outside of destination area, send delete
        if location == 1 then
            logger:info("delete mob to " .. another_peer.peer_id)
            another_peer:send_command("delete_mob", {
                mob_id = peer.peer_id,
            })
            peer:send_command("delete_mob", {
                mob_id = another_peer.peer_id,
            })
            return
        end

        -- new in area destination, send spawn and motion
        logger:info("spawn mob to " .. another_peer.peer_id)
        another_peer:send_command("spawn_mob", {
            position = dest,
            owner_id = peer.peer_id,
            mob = player_mob,
        })

        another_peer:send_command("motion_mob", {
            origin = position,
            kind = req.kind,
            speed = req.speed,
            mob_id = peer.peer_id,
            destination = dest,
        })

        peer:send_command("spawn_mob", {
            position = { x = mob_pos.x, y = mob_pos.y },
            owner_id = another_peer.peer_id,
            mob = mob,
        })
    end)
end)
