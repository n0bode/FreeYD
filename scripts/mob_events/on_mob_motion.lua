local server = require("server")
local logger = require("logger")
local multicast = require("scripts.utils.multicast").multicast

server:on("on_motion_mob", function(peer, req)
    local map = server:get_world()
    local player_mob = peer:get_player_mob();
    local last_pos = { x = player_mob.x, y = player_mob.y }

    map:move_mob(player_mob, req.destination.x, req.destination.y)
    multicast(req.origin, req.destination, function(another_peer, mob, location)
        local is_mine = another_peer.peer_id == peer.peer_id
        if is_mine then
            return
        end

        -- visible to both areas, send motion
        if location == 0 then
            another_peer:send_command("motion_mob", {
                origin = last_pos,
                kind = req.kind,
                speed = req.speed,
                mob_id = peer.peer_id,
                destination = req.destination,
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
            position = req.destination,
            owner_id = peer.peer_id,
            mob = player_mob.dataL: *State,
        })

        peer:send_command("spawn_mob", {
            position = { x = mob.x, y = mob.y },
            owner_id = another_peer.peer_id,
            mob = mob.data,
        })
    end)
end)
