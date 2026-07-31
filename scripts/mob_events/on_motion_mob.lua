local server = require("server")
local logger = require("logger")
local query = require("scripts.utils.queries")

server:on("on_motion_mob", function(peer, req)
    local map = server:get_world()

    local current_position = map:get_position(peer.peer_id)
    if not current_position then
        logger:error("peer " .. peer.peer_id .. " has no position")
        return
    end

    -- move player in world
    local player_mob = peer:get_player_mob()
    map:move(peer.peer_id, req.destination.x, req.destination.y)

    local last_pos = { x = current_position.x, y = current_position.y }
    local dest = { x = req.destination.x, y = req.destination.y };

    query.in_areas(last_pos, dest, nil, function(object)
        local position = { x = object.position.x, y = object.position.y }
        if object.type == 3 then
            local item = object.result.item
            if object.location == 1 then
                peer:send_command("delete_ground_item", { item_id = item.item_id })
            elseif object.location == 2 then
                logger:info(" to spawn item " .. item.item_id .. "state = " .. item.state)
                peer:send_command("create_ground_item", {
                    item_id = item.item_id,
                    item = item.item,
                    position = position,
                    rotate = item.rotation,
                    state = item.state,
                })

                if item.state == 1 then
                    peer:send_command("update_ground_item", {
                        item_id = item.item_id,
                        state = item.state,
                    })
                end
            end
            return
        end

        local mob = object.result.mob
        if object.type == 2 then
            local another_peer = object.result.peer
            if another_peer == peer then
                return
            end

            if object.location == 0 then
                another_peer:send_command("motion_mob", {
                    origin = position,
                    kind = req.kind,
                    speed = req.speed,
                    mob_id = peer.peer_id,
                    destination = dest,
                })
                return
            end

            if object.location == 1 then
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

        if object.location == 0 then
            return
        end
        peer:send_command("spawn_mob", {
            position = { x = object.position.x, y = object.position.y },
            owner_id = mob.mob_id,
            mob = mob,
        })
    end)
end)
