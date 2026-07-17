local server = require("server")
local logger = require("logger")

server:on("on_pinpassword", function(peer, req)
    local db = server:get_database()
    if db == nil then
        peer:send_text("ops.. try again soon")
        return false
    end

    local account = peer.account
    local password = req.numeric
    if account.pin_password == "" then
        account.pin_password = password
        peer:send_text("new password created")
    else
        if account.pin_password ~= password then
            peer:send_command("password_incorrect", "password incorrect")
            return
        end
    end

    account.state = AccountState.LOGGED;
    account:save(db);
end)
