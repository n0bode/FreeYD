local server = require("server")
local logger = require("logger")

server:on("on_motion_mob", function(peer, req)
    local position = req.origin
    logger:info("source(" .. position.x .. "," .. req.origin.y .. ")")
    logger:info("kind: " .. req.kind .. " speed " .. req.speed)
    logger:info("destination(" .. req.destination.x .. "," .. req.destination.y .. ")")
    logger:info("time: " .. req.header.time);
    logger:info("route: " .. req.routes);


    local map = server:get_world()
    local player_mob = peer:get_player_mob();
    local last_pos = { x = player_mob.x, y = player_mob.y }

    map:move_mob(player_mob, req.destination.x, req.destination.y)

    local max_players = tonumber(os.getenv("MAX_PLAYERS"))
    map:each_mobs(function(spawned_mob)
        local mob = spawned_mob.data
        local mob_id = mob.mob_id
        logger:info("mob_id " .. mob.mob_id)
        local is_player = mob_id <= max_players
        local is_mine = mob_id == peer.peer_id

        if is_player and not is_mine then
            local another = server:get_peer(mob.mob_id)
            if another then
                another:send_command("motion_mob", {
                    destination = req.destination,
                    origin = last_pos,
                    mob_id = peer.peer_id,
                    speed = req.speed,
                    kind = req.kind,
                })
            end
        end
    end)
end)
