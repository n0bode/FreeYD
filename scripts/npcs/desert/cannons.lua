local server = require("server");
local logger = require("logger");
local multicast = require("scripts.utils.multicast").multicast

local function create_cannon(x, y)
    server:create_npc {
        name = "Cannon",
        position = { x = x, y = y },
        on_interact = function(npc, peer)
            logger:info("Player " .. peer.peer_id .. " interacted with NPC " .. npc.name)
            peer:send_text("Hello, I am the " .. npc.name .. ". I can help you train your skills.")
        end,
        equipments = {
            [EquipmentSlot.face] = Item.new(178), -- Example item ID for face equipment
        },
        on_update = function(npc, server_time)
        end
    }
end

create_cannon(1116, 1717)
create_cannon(1116, 1713)
create_cannon(1116, 1700)
create_cannon(1116, 1696)

create_cannon(1129, 1717)
create_cannon(1129, 1713)
create_cannon(1129, 1700)
create_cannon(1129, 1696)
