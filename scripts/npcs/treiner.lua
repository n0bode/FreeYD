local server = require("server");

server:create_npc {
    name = "Treiner",
    position = { x = 2112, y = 2042 },
    on_interact = function(npc, peer)
        peer:send_text("Hello, I am the " .. npc.name .. ". I can help you train your skills.")
    end,
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
    on_update = function(npc)
        -- This function is called every server tick to update the NPC's state.
        -- You can add logic here to make the NPC move, interact with players, etc.
    end
}

server:create_npc {
    name = "Guarda",
    position = { x = 2114, y = 2080 },
    on_interact = function(npc, peer)
        peer:send_text("Hello, I am the " .. npc.name .. ". I can help you train your skills.")
    end,
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
    on_update = function(npc)
        -- This function is called every server tick to update the NPC's state.
        -- You can add logic here to make the NPC move, interact with players, etc.
    end
}
