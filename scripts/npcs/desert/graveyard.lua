local server = require("server");
local logger = require("logger");
local multicast = require("scripts.utils.multicast").multicast

server:create_npc {
    name = "Coveiro",
    position = { x = 2372, y = 2099 },
    on_interact = function(npc, peer)
        local mob = peer:get_player_mob()
        local position = { x = mob.x, y = mob.y }
        logger:info("Player " ..
            peer.peer_id .. " interacted with NPC " .. npc.name .. " at position (" .. mob.x .. ", " .. mob.y .. ")")
        if mob.data.stats.level < 40 then
            peer:send_command("chat_message", {
                message = "Voce precisa ser nivel 40 para me ajudar nessa merda",
                mob_id = npc.id,
                type = 0,
            })
            return
        end

        if mob.data.stats.level > 115 then
            multicast(position, position, function(peer, mob, location)
                peer:send_command("chat_message", {
                    message = "Obrigado por me ajudar, mas seu gostoso",
                    mob_id = npc.id,
                    type = 0,
                })
            end)
            return
        end

        if math.abs(npc.start_position.x - mob.x) > 3 or math.abs(npc.start_position.y - mob.y) > 3 then
            return
        end
        local dest = { x = 2397, y = 2104 };
        multicast(position, dest, function(another_peer, mob, location)
            another_peer:send_command("motion_mob", {
                mob_id = peer.peer_id,
                kind = 1,
                speed = 0,
                origin = position,
                destination = dest,
            })
        end)
    end,
    equipments = {
        [EquipmentSlot.face] = Item.new(58, { index = 43, value = 250 }), -- Example item ID for face equipment
        [EquipmentSlot.body] = Item.new(101, { index = 43, value = 6 }),  -- Example item ID for body equipment
        [EquipmentSlot.pants] = Item.new(102, { index = 43, value = 6 }), -- Example item ID for legs equipment
        [EquipmentSlot.boots] = Item.new(103, { index = 43, value = 6 }), -- Example item ID for feet equipment
        [EquipmentSlot.gloves] = Item.new(104, { index = 43, value = 6 }),
        [EquipmentSlot.weapon] = Item.new(726, { index = 43, value = 9 }),
    },
    on_update = function(npc, server_time)
    end
}
