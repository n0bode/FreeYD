local server = require("server")
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
    -- se for um conta nova seta um novo password
    if account.state == AccountState.NEW_ACCCOUNT then
        account.pin_password = password
    elseif password == account.pin_password then
        peer:send_text("try again")
        return true
    end

    account.state = AccountState.LOGGED
    account:save(db)
    peer:send_text("welcome to jungle")
    return true
end)
