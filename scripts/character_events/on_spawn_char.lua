local server = require("server")
local logger = require("logger")

server:on("on_spawn_char", function(peer, req)
    local db = server:get_database()
    if not db then
        logger:error("Database connection not available")
        return false
    end

    local account = peer.account
    if not account then
        logger:error("Account not found for peer")
        return false
    end

    local char, err = account:get_character(req.char_slot)
    if not char then
        logger:error("Character not found in slot " .. req.char_slot .. ": " .. (err or "unknown error"))
        return false
    end

    char.tab = "peerId:" .. peer.peer_id
    account.char_selected = req.char_slot
    account.state = AccountState.PLAYING
    account:save(db)

    local player_mob = char:to_mob(peer.peer_id)
    if not player_mob then
        logger:error("Failed to convert character to mob for peer " .. peer.peer_id)
        return false
    end


    -- notification all peers about new char
    server:multicast("spawn_mob", {
        position = char.position,
        mob = player_mob,
    })

    return true
end)
