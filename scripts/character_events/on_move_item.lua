local server = require("server");
local multicast = require("scripts.utils.multicast").multicast

server:on("on_move_item", function(peer, req)
    -- same slot
    if req.source_storage == req.dest_storage and req.source_slot == req.dest_slot then
        return
    end

    local account = peer.account
    local char = account:get_current_char()
    if not char then
        peer:send_text("server error: character not found")
        peer:disconnect()
        return
    end

    if req.dest_storage == StorageType.CARGO or req.source_storage == StorageType.CARGO then
        peer:send_text("not implemented yet")
        return
    end

    local item_source = char:get_item(req.source_storage, req.source_slot)
    local item_dest = char:get_item(req.dest_storage, req.dest_slot)

    local swapped = char:swap_items(req.source_storage, req.source_slot, req.dest_storage, req.dest_slot)
    local changedMob = swapped and
        (req.dest_storage == StorageType.EQUIPMENT or req.source_storage == StorageType.EQUIPMENT)


    peer:send_command("move_item", {
        slot = req.dest_slot,
        storage = req.dest_storage,
        item = item_source,
        mob_id = peer.peer_id,
    })

    peer:send_command("move_item", {
        slot = req.source_slot,
        storage = req.source_storage,
        mob_id = peer.peer_id,
        item = item_dest,
    })
    -- update mob near
    if changedMob then
        local player_mob = peer:get_player_mob()
        local position = { x = player_mob.x, y = player_mob.y }
        multicast(position, position,
            function(another_peer, _, _)
                another_peer:send_command("update_equipments", {
                    mob = player_mob.data,
                })
            end)
    end
end)
