local server = require("server");
local logger = require("logger");

server:on("on_whisper", function(peer, req)
    logger:info("(" .. peer.peer_id .. ")[" .. req.name .. "]: " .. req.message)

    local actions = {
        ["time"] = function()
            local datetime = server:get_local_date();
            local date = "" .. os.date("!%d-%m-%Y %H:%M:%S", datetime)
            peer:send_text(date)
        end,
        ["tab"] = function()
            local account = peer.account
            local char = account:get_current_char()
            if not char then
                logger:error("Character not found for peer " .. peer.peer_id)
                peer:disconnect()
                return
            end

            char.tab = req.message
            server:multicast("mob_spawn", {
                position = char.position,
                owner_id = peer.peer_id,
                mob = char:to_mob(),
            })
            account:save(server:get_database())
            peer:send_text("Tab updated to: " .. char.tab)
        end,
        ["help"] = function()
            peer:send_text(req.name)
        end,
    }

    local action = actions[req.name]
    if action then
        action()
    else
        peer:send_text("Unknown command: " .. req.name)
    end
end)
