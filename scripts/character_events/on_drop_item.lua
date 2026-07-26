local server = require("server");
local logger = require("logger");

server:on("on_drop_item", function(peer, req)
    -- same slot
    logger:info("drop item")
    logger:info("position = (" .. peer.peer_id .. ")[" .. req.position.x .. "," .. req.position.y .. "]")
    logger:info("rotation = (" .. peer.peer_id .. ")[" .. req.rotation.x .. "," .. req.rotation.y .. "]")
    logger:info("item = (" .. peer.peer_id .. ")[" .. req.item_id .. "]")

    local char = peer.account:get_current_char()
    if not char then
        logger:error("Character not found for peer " .. peer.peer_id)
        return
    end

    local item = char:get_item(req.storage, req.slot)
    if not item then
        logger:error("Item not found in storage " .. req.storage .. " slot " .. req.slot .. " for peer " .. peer.peer_id)
        return
    end

    peer:send_command("drop_item", {
        position = req.position,
        rotation = req.rotation,
        item_id = req.item_id,
        storage = req.storage,
        slot = req.slot,
        mob_id = peer.peer_id,
    })

    peer:send_command("move_item", {
        slot = req.slot,
        storage = req.storage,
        item = Item.new(0),
        mob_id = peer.peer_id
    })

    peer:send_command("create_item", {
        position = req.position,
        rotation = req.rotation,
        item_id  = req.item_id,
        rotate   = 0,
        height   = 1,
        state    = 1,
        item     = item,
        create   = 1,
    })
end)
