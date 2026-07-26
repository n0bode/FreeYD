local server = require("server")
local logger = require("logger")
local query = require("scripts.utils.queries")

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
    query.in_areas(req.origin, dest, nil, function(result)
        if result.is_player then
            local another_peer = result.peer
            if another_peer == peer then
                return
            end

            if result.location == 0 then
                another_peer:send_command("motion_mob", {
                    origin = position,
                    kind = req.kind,
                    speed = req.speed,
                    mob_id = peer.peer_id,
                    destination = dest,
                })
                return
            end

            if result.location == 1 then
                logger:info("delete mob to " .. another_peer.peer_id)
                another_peer:send_command("delete_mob", {
                    mob_id = peer.peer_id,
                })
                peer:send_command("delete_mob", {
                    mob_id = another_peer.peer_id,
                })
                return
            end

            logger:info("spawn mob to " .. another_peer.peer_id)
            another_peer:send_command("spawn_mob", {
                position = dest,
                owner_id = peer.peer_id,
                mob = player_mob,
            })
        end
        peer:send_command("spawn_mob", {
            position = { x = result.position.x, y = result.position.y },
            owner_id = result.mob.mob_id,
            mob = result.mob,
        })
    end)
end)
