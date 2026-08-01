local server = require("server")
local queries = require("scripts.utils.queries")
local logger = require("logger")

local function spawn_pork(x, y)
    server:create_enemy {
        name = "pork",
        position = { x = x, y = y },
        tick = 5000,
        delay = math.random(0, 10) * 200,
        experience = 10,
        stats = {
            level = 3,
            hp = 100,
            max_hp = 70,
            attack = 7,
            defense = 2,
            speed = 1,
        },
        equipments = {
            [EquipmentSlot.face] = Item.new(216), -- Example item ID for face
            [EquipmentSlot.head] = Item.new(217), -- Example item ID for face
        },
        on_update = function(ctx)
            local mob = ctx.mob

            local world = server:get_world()
            local center = ctx.start_position
            local last_position = ctx.position
            local dest = { x = center.x + math.random(-2, 2), y = center.y + math.random(-2, 2) }

            local closest = queries.player_closest_to(last_position, 2)
            if closest then
                logger:info("Closest player to pork " ..
                    mob.mob_id ..
                    " is " ..
                    closest.peer.peer_id .. " at position (" .. closest.position.x .. ", " .. closest.position.y .. ")")
                dest = { x = closest.position.x, y = closest.position.y }
            end

            world:move(mob.mob_id, dest.x, dest.y)
            queries.players_in_area(dest, function(player, position)
                local another = player.peer
                another:send_command("motion_mob", {
                    origin = { x = last_position.x, y = last_position.y },
                    kind = 0,
                    speed = mob.stats.state.movement_speed,
                    mob_id = mob.mob_id,
                    destination = { x = dest.x, y = dest.y },
                })
            end)
        end,
    }
end

local function rand(min, max)
    return math.random(min, max)
end

local positions = {
    { x = 2144, y = 2028 },
    { x = 2149, y = 2023 },
    { x = 2145, y = 2020 },
    { x = 2138, y = 2019 },
    { x = 2132, y = 2020 },
    { x = 2128, y = 2021 },
    { x = 2124, y = 2027 },
    { x = 2128, y = 2034 },
    { x = 2117, y = 2021 },
    { x = 2112, y = 2028 },
}

for _, pos in pairs(positions) do
    spawn_pork(pos.x, pos.y)
end
