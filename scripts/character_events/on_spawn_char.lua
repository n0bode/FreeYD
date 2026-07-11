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

    account.char_selected = req.char_slot
    account.state = AccountState.PLAYING
    account:save(db)

    return true
end)
