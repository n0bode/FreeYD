local server = require("server")
local logger = require("logger")
local query = require("scripts.utils.queries")

server:on("on_spawn_char", function(peer, req)
    local db = server:get_database()

    local account = peer.account
    if not account then
        logger:error("peer " .. peer.peer_id .. " has no associated account")
        peer:disconnect()
        return
    end

    local char = account:get_character(req.char_slot)
    if not char then
        logger:error("character not found in slot " .. req.char_slot)
        peer:disconnect()
        return
    end

    local last_position = char.position
    logger:info("character " .. char.name);
    char.tab = "peerId:" .. peer.peer_id
    account.state = AccountState.PLAYING

    local err = server:spawn_player(peer, req.char_slot, last_position.x, last_position.y)
    if not err == nil then
        logger:error("erro to send spawn_char: " .. err)
        return
    end
    account:save(db)

    local player_mob = peer:get_player_mob()

    query.in_area(last_position, nil, function(object)
        local position = { x = object.position.x, y = object.position.y }
        if object.type == 2 then
            local another = object.result.peer
            -- notify another player create a mob
            if peer == another then
                return
            end

            logger:info("notify another player " .. another.peer_id .. " to spawn mob for peer " .. peer.peer_id)
            another:send_command("spawn_mob", {
                position = char.position,
                owner_id = peer.peer_id,
                mob = player_mob,
            })
        end

        if object.type == 3 then
            local item = object.result.item
            logger:info("notify peer " .. peer.peer_id .. " to spawn item " .. item.item_id)
            peer:send_command("create_ground_item", {
                position = position,
                item_id = item.item_id,
                item = item.item,
                rotate = item.rotation,
                state = item.state,
            })
        else
            local mob = object.result.mob
            peer:send_command("spawn_mob", {
                position = position,
                owner_id = mob.mob_id,
                mob = mob,
            })
        end
    end)
end)
