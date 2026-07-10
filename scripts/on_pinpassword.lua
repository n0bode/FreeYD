local server = require("server")
local logger = require("logger")

server:on("on_pinpassword", function(peer, req)
    local db = server:get_database()
    if db == nil then
        peer:send_text("ops.. try again soon")
        return false
    end

    local account = peer.account
    if account == nil then
        peer:send_text("username or password is invalid")
        return false
    end

    local password = req.numeric
    if account.pin_password == "" then
        account.pin_password = password
        logger:info("set pin password " .. account.pin_password .. " for account: " .. account.name)
        peer:send_text("new password created")
    else
        if account.pin_password ~= password then
            peer:send_text("password incorrect")
            return false
        end
    end

    account.state = AccountState.LOGGED;
    account:save(db);
    return true
end)
