local server = require("server")
local logger = require("logger")
local multicast = require("scripts.utils.multicast").multicast

server:on("on_disconnected", function(peer)
    logger:info("peer disconnected: " .. peer.peer_id)
    local db = server:get_database()
    if db == nil then
        return
    end

    local world = server:get_world()
    local pos = world:get_position(peer.peer_id)

    if pos then
        world:remove(peer.peer_id)
        logger:debug("peer " .. peer.peer_id .. " position: " .. pos.x .. "," .. pos.y)
        multicast(pos, pos, function(another_peer, mob, position, location)
            if another_peer == peer then
                return
            end

            logger:info("notify another player " .. another_peer.peer_id .. " to delete mob for peer " .. peer.peer_id)
            another_peer:send_command("delete_mob", {
                mob_id = peer.peer_id,
            })
        end)
    end

    logger:info("peer disconnected: " .. peer.peer_id)
    local account = peer.account

    account.state = AccountState.OFFLINE
    account:save(db)
end)
