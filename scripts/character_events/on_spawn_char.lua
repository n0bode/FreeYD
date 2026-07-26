local server = require("server")
local logger = require("logger")
local multicast = require("scripts.utils.multicast").multicast
local view = require("scripts.utils.view")

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
        logger:error("character not found in slot " .. req.char_slot .. ": " .. (err or "unknown error"))
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

    multicast(last_position, last_position, function(another, mob, position, location)
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

        -- notify peer create a mob for another player
        peer:send_command("spawn_mob", {
            position = { x = position.x, y = position.y },
            owner_id = another.peer_id,
            mob = mob,
        })
    end)

    -- only npc and othes...
    view.each_mobs_in_area(last_position, function(mob, position)
        peer:send_command("spawn_mob", {
            position = { x = position.x, y = position.y },
            owner_id = mob.mob_id,
            mob = mob,
        })
    end)
end)
