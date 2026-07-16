local server = require("server")
local logger = require("logger")

server:on("on_delete_char", function(peer, req)
    local db = server:get_database()

    local account = peer.account
    if account == nil then
        peer:send_text("username or password is invalid")
        return false
    end

    if account.password ~= req.password then
        peer:send_text("password not matched")
        return false
    end

    local char = account.characters[req.slot]
    if char.name == "" then
        return true
    end

    if char.name ~= req.name then
        logger:error("name character incorrect")
        peer:send_text("failed to delete, try again soon")
        return false
    end

    char.name = ""
    local updated = account.characters[req.slot]

    logger:info("char nome " .. char.name .. " db = " .. updated.name)
    account:save(db)
    peer:send_text("character deleted successfully")
    return true
end)
