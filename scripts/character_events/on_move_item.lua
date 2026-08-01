local server = require("server");
local queries = require("scripts.utils.queries")

---@param result QueryResult
local only_players = function(result)
    return result.type == queries.QueryResultType.PLAYER_MOB
end

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

    local world = server:get_world()
    -- update mob near
    if changedMob then
        local player_pos = world:get_position(peer.peer_id)
        if not player_pos then
            peer:send_text("server error: player position not found")
            peer:disconnect()
            return
        end

        local player_mob = peer:get_player_mob()
        local position = { x = player_pos.x, y = player_pos.y }
        queries.players_in_area(position,
            function(player)
                local another_peer = player.peer
                another_peer:send_command("update_equipments", {
                    mob = player_mob,
                })
            end)
    end
end)
