local server = require("server")
local logger = require("logger")

local function signup(db, req)
    return db:create_account({
        username = req.username,
        password = req.password,
        email = "email.com",
    })
end

server:on("on_login", function(peer, req)
    local db = server:get_database()

    local account = db:get_account_by_username(req.username)
    if account then
        logger:info("account found for username: " .. req.username)
        if account.password ~= req.password then
            logger:info("password invalid for username: " .. req.username)
            peer:send_text("username or password is invalid")
            return false
        end
    else
        account = signup(db, req)
        if account == nil then
            peer:send_text("username or password is invalid")
            return false
        end
        account:save(db)
        peer:associate(account)
        peer:send_command("enter_account", "bem vindo ao servidor")
        return true
    end

    if account.state ~= AccountState.OFFLINE then
        logger:info("account already logged: " .. req.username)
        peer:send_text("account is already logged in")
        account.state = AccountState.OFFLINE
        account:save(db)
        return false
    end

    account.state = AccountState.LOGGED
    account:save(db)
    peer:associate(account)


    peer:send_command("enter_account", "bem vindo ao servidor")
    return true
end)
