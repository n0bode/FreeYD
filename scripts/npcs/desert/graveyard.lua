local server = require("server");
local logger = require("logger");
local queries = require("scripts.utils.queries")

server:create_npc {
    name = "Coveiro",
    position = { x = 2372, y = 2099 },
    on_interact = function(npc, peer)
        local world = server:get_world()
        local mob = peer:get_player_mob()
        local position = world:get_position(mob.mob_id)
        if not position then
            logger:error("peer " .. peer.peer_id .. " has no position")
            peer:disconnect()
            return
        end

        local only_players = function(result)
            return result.is_player
        end

        local level = mob.stats.level
        if level < 40 then
            peer:send_command("chat_message", {
                message = "You need to be more experienced to receive my help.",
                mob_id = npc.id,
                type = 0,
            })
            return
        end

        if level > 115 then
            queries.in_area(position, only_players, function(result)
                peer:send_command("chat_message", {
                    message = "Thank you for your help, but now I can take care of myself.",
                    mob_id = npc.id,
                    type = 0,
                })
            end)
            return
        end

        if math.abs(npc.start_position.x - position.x) > 3 or math.abs(npc.start_position.y - position.y) > 3 then
            peer:send_command("chat_message", {
                message = "I cannot hear you from here. Please come closer.",
                mob_id = npc.id,
                type = 0,
            })
            return
        end

        local dest = { x = 2397, y = 2104 };
        queries.teleport(position, dest, function(object, is_dest)
            if not object.type == 2 then
                return
            end

            local another_peer = object.result.peer
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
