local server = require("server")
server:on("on_login", function(peer, req)
    local db = server:get_database()
    peer:send_text("ops..")
    if db == nil then
        peer:send_text("ops.. try again soon")
        return false
    end

    print("user by credentials")
    local account = db:get_account_by_credentials(req.username, req.password)

    print("checking account is null")
    if account == nil then
        peer:send_text("username or password is invalid")
        return false
    end

    print("set account")
    peer:associate(account);

    return true
end)
