local server = require("server")
local logger = require("logger")
local query = require("scripts.utils.queries")
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

    query.in_area(last_position, nil, function(result)
        local position = { x = result.position.x, y = result.position.y }
        if result.is_player then
            local another = result.peer
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

        peer:send_command("spawn_mob", {
            position = { x = result.position.x, y = result.position.y },
            owner_id = result.mob.mob_id,
            mob = result.mob,
        })
    end)
end)
