local server = require("server")
local logger = require("logger")

server:on("on_disconnected", function(peer)
    local db = server:get_database()
    if db == nil then
        return
    end

    logger:info("peer disconnected: " .. peer.peer_id)
    local account = peer.account

    account.state = AccountState.OFFLINE
    account:save(db)
end)
