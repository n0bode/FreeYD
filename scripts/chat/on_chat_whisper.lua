local server = require("server");
local logger = require("logger");

for key, value in pairs(StorageType) do
    logger:info("StorageType[" .. key .. "] = " .. value)
end

server:on("on_chat_whisper", function(peer, req)
    logger:info("(" .. peer.peer_id .. ")[" .. req.name .. "]: " .. req.message)

    local world = server:get_world()
    local actions = {
        ["time"] = function()
            local datetime = server:get_local_date();
            local date = "" .. os.date("!%d-%m-%Y %H:%M:%S", datetime)
            peer:send_text(date)
        end,
        ["set_equip"] = function()
            local args = req.message:gmatch("%S+")
            local slot = tonumber(args()) or 0
            local item_id = tonumber(args()) or 0

            local account = peer.account
            local char = account:get_current_char()
            if not char then
                logger:error("Character not found for peer " .. peer.peer_id)
                peer:disconnect()
                return
            end

            local attrs = {}
            if slot == 14 then
                attrs = {
                    { index = 0, value = 100 },
                    { index = 0, value = 100 },
                    { index = 0, value = 100 },
                }
            end

            local item = Item.new(item_id, unpack(attrs))
            char:set_equipment(slot, item)
            peer:send_text("Item added to slot " .. slot)
            account:save(server:get_database())
            peer:send_command("move_item", {
                mob_id = peer.peer_id,
                item = item,
                storage = StorageType.EQUIPMENT,
                slot = slot,
            })
            peer:send_command("update_equipments", {
                mob = char:to_mob(),
            })
        end,
        ["dc"] = function()
            logger:info("Disconnecting peer " .. peer.peer_id)
            peer:disconnect()
        end,
        ["add_item"] = function()
            local args = string.gmatch(req.message, "%S+")
            local item_id = tonumber(args()) or 0
            if item_id == 0 then
                peer:send_text("Invalid item_id")
                return
            end

            local account = peer.account
            local char = account:get_current_char()
            if not char then
                logger:error("Character not found for peer " .. peer.peer_id)
                peer:disconnect()
                return
            end

            local item = Item.new(item_id)
            local slot = char:add_item_on_empty(item)
            if slot >= 0 then
                peer:send_text("Item added to slot " .. slot)
                account:save(server:get_database())
                peer:send_command("move_item", {
                    mob_id = peer.peer_id,
                    item = item,
                    storage = StorageType.INVENTORY,
                    slot = slot,
                })
            end
        end,
        ["update_ground"] = function()
            local args = string.gmatch(req.message, "%d+")
            local item_id = tonumber(args()) or 0
            if item_id == 0 then
                peer:send_text("Invalid item_id")
                return
            end

            local item = world:get_ground_item(item_id)
            if not item then
                peer:send_text("ground item not found")
                return
            end

            local last_state = item.state
            item.state = tonumber(args()) or 0
            peer:send_command("update_ground_item", {
                item_id = item.item_id,
                state = item.state,
            })
            peer:send_text("updated item_id " .. item_id .. " state from " .. last_state .. " to " .. item.state)
        end,
        ["create_item"] = function()
            local args = string.gmatch(req.message, "%d+")
            local item_id = tonumber(args()) or 0
            if item_id == 0 then
                peer:send_text("Invalid item_id")
                return
            end

            server:spawn_item {
                item = Item.new(item_id),
                position = { x = tonumber(args()) or 0, y = tonumber(args()) or 0 },
                rotation = 0,
                state = 1,
                height = tonumber(args()) or 1,
                on_interact = function(peer, item)
                end,
                create = 1,
            }
        end,
        ["tp"] = function()
            local args = string.gmatch(req.message, "%S+")
            local x = tonumber(args()) or 2112
            local y = tonumber(args()) or 2101

            logger:info("Teleporting peer " .. peer.peer_id .. " to: " .. x .. "," .. y)
            peer:send_text("Teleporting to: " .. x .. "," .. y)
            local world = server:get_world()
            local char = peer:get_player_mob()

            local position = world:get_position(peer.peer_id)
            if not position then
                return
            end

            world:move(peer.peer_id, x, y)
            peer:send_command("motion_mob", {
                origin = { x = position.x, y = position.y },
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
