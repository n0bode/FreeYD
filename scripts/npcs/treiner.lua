local server = require("server");
local logger = require("logger");
local queries = require("scripts.utils.queries")

server:create_npc {
    name = "Treinador",
    position = { x = 2126, y = 2037 },
    on_interact = function(ctx, peer)
        logger:info("Player " .. peer.peer_id .. " interacted with NPC " .. ctx.mob.name)
        peer:send_text("Hello, I am the " .. ctx.mob.name .. ". I can help you train your skills.")
    end,
    -- 2 seconds
    tick = 2000,
    equipments = {
        [EquipmentSlot.face] = Item.new(60),    -- Example item ID for face equipment
        [EquipmentSlot.head] = Item.new(130),   -- Example item ID for body equipment
        [EquipmentSlot.body] = Item.new(126),   -- Example item ID for body equipment
        [EquipmentSlot.pants] = Item.new(127),  -- Example item ID for legs equipment
        [EquipmentSlot.boots] = Item.new(128),  -- Example item ID for feet equipment
        [EquipmentSlot.gloves] = Item.new(129), -- Example item ID for hands equipment
        [EquipmentSlot.weapon] = Item.new(986), -- Example item ID for weapon equipment
        [EquipmentSlot.cape] = Item.new(543),   -- Example item ID for weapon equipment
    },
    on_update = function(ctx)
        local mob = ctx.mob
        local position = ctx.start_position

        local world = server:get_world()
        local start = position
        local dest = { x = ctx.start_position.x + math.random(-2, 2), y = ctx.start_position.y + math.random(-2, 2) }

        world:move(mob.mob_id, dest.x, dest.y)
        queries.players_in_area(dest, function(player, position)
            local another = player.peer
            another:send_command("motion_mob", {
                origin = { x = start.x, y = start.y },
                kind = 0,
                speed = 1,
                mob_id = mob.mob_id,
                destination = { x = dest.x, y = dest.y },
            })
        end)
    end
}

--[[
server:create_npc {
    name = "Guarda",
    position = { x = 2114, y = 2080 },
    on_interact = function(npc, peer)
        peer:send_command("chat_message", {
            mob_id = npc.id,
            type = 0,
            message = "Hello, I am the " .. npc.name .. ". I can help you with your quests.",
        })
    end,
    equipments = {
        [EquipmentSlot.face] = Item.new(60),    -- Example item ID for face equipment
        [EquipmentSlot.head] = Item.new(130),   -- Example item ID for body equipment
        [EquipmentSlot.body] = Item.new(126),   -- Example item ID for body equipment
        [EquipmentSlot.pants] = Item.new(127),  -- Example item ID for legs equipment
        [EquipmentSlot.boots] = Item.new(128),  -- Example item ID for feet equipment
        [EquipmentSlot.gloves] = Item.new(129), -- Example item ID for hands equipment
        [EquipmentSlot.weapon] = Item.new(986), -- Example item ID for weapon equipment
        [EquipmentSlot.cape] = Item.new(4006),  -- Example item ID for weapon equipment
    },
    on_update = function(npc)
        -- This function is called every server tick to update the NPC's state.
        -- You can add logic here to make the NPC move, interact with players, etc.
    end
}
--]]
