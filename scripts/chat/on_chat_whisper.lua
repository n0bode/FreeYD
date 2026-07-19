local server = require("server");
local logger = require("logger");

server:on("on_chat_whisper", function(peer, req)
    logger:info("(" .. peer.peer_id .. ")[" .. req.name .. "]: " .. req.message)

    local actions = {
        ["time"] = function()
            local datetime = server:get_local_date();
            local date = "" .. os.date("!%d-%m-%Y %H:%M:%S", datetime)
            peer:send_text(date)
        end,
        ["tp"] = function()
            local args = string.gmatch(req.message, "%S+")
            local x = tonumber(args()) or 2112
            local y = tonumber(args()) or 2101

            logger:info("Teleporting peer " .. peer.peer_id .. " to: " .. x .. "," .. y)
            peer:send_text("Teleporting to: " .. x .. "," .. y)
            local world = server:get_world()
            local char = peer:get_player_mob()

            world:move_mob(char, x, y)
            peer:send_command("motion_mob", {
                origin = { x = char.x, y = char.y },
                kind = 1,
                speed = 0,
                mob_id = peer.peer_id,
                destination = { x = x, y = y },
            })
        end,
        ["tab"] = function()
            local account = peer.account
            local char = account:get_current_char()
            if not char then
                logger:error("Character not found for peer " .. peer.peer_id)
                peer:disconnect()
                return
            end

            local mob = char:to_mob()
            if mob == nil then
                logger:info("cannot convert to mob " .. peer.peer_id)
                peer:send_text("invalid code, check the code")
                return
            end

            char.tab = req.message

            local area = tonumber(os.getenv("AREA_MULTICAST"))
            local rect = {
                x = char.position.x - area / 2,
                y = char.position.y - area / 2,
                width = area,
                height = area,
            }

            local opts = {
                -- remove peer that whiper
                filter = function(receiver)
                    return receiver.peer_id ~= peer.peer_id;
                end,
            }

            -- sent to all in area
            server:multicast_command_in_area("mob_spawn", rect, {
                position = char.position,
                owner_id = peer.peer_id,
                mob = mob,
            }, opts)

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
