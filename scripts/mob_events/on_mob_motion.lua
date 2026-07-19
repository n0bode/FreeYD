local server = require("server")
local logger = require("logger")
local math = require("math")

local field_of_view = tonumber(os.getenv("MULTICAST_AREA"))
logger:info("field_of_view = " .. field_of_view)

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

    local dis_x = math.abs(req.destination.x - last_pos.x)
    local dis_y = math.abs(req.destination.y - last_pos.y)

    -- area orign
    local rect = {
        x = req.destination.x - field_of_view / 2,
        y = req.destination.y - field_of_view / 2,
        width = field_of_view + dis_x,
        height = field_of_view + dis_y,
    }

    map:each_mobs_in_area(rect, function(spawned_mob)
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
