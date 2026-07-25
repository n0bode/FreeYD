local server = require("server");
local multicast = require("scripts.utils.multicast").multicast
local logger = require("logger");

server:on("on_drop_item", function(peer, req)
    -- same slot
    logger:info("drop item")
    logger:info("position = (" .. peer.peer_id .. ")[" .. req.position.x .. "," .. req.position.y .. "]")
    logger:info("rotation = (" .. peer.peer_id .. ")[" .. req.rotation.x .. "," .. req.rotation.y .. "]")
    logger:info("item = (" .. peer.peer_id .. ")[" .. req.item_id .. "]")

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
end)
