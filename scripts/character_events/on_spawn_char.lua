local server = require("server")
local logger = require("logger")

server:on("on_spawn_char", function(peer, req)
    local db = server:get_database()

    local account = peer.account
    if not account then
        logger:error("Account not found for peer")
    end

    local char, err = account:get_character(req.char_slot)
    if not char then
        logger:error("Character not found in slot " .. req.char_slot .. ": " .. (err or "unknown error"))
        return
    end

    logger:info("character " .. char.name);
    char.tab = "peerId:" .. peer.peer_id
    account.char_selected = req.char_slot
    account.state = AccountState.PLAYING
    account:save(db)

    -- send to peer character infos
    err = peer:send_command("spawn_char", {
        position = char.position,
        character = char,
    })

    if not err == nil then
        logger:error("erro to send spawn_char: " .. err)
        return
    end

    local player_mob = peer:get_player_mob()

    local world = server:get_world()
    world:move_mob(player_mob, player_mob.x, player_mob.y)
    world:each_mobs(function(mob)
        -- owns server
        local owner_id = mob.data.mob_id

        local mob_id = mob.data.mob_id
        logger:info("mob_id " .. mob_id)
        local is_player = server:is_player(mob_id)
        local is_mine = mob_id == peer.peer_id

        if (is_player) then
            owner_id = mob_id

            -- notify near players
            if not (is_mine) then
                local another = server:get_peer(owner_id)
                if (another) then
                    another:send_command("spawn_mob", {
                        position = char.position,
                        owner_id = peer.peer_id,
                        mob = player_mob.data,
                    })
                end
            end
        end

        logger:info("(" .. mob.x .. "," .. mob.y .. ") = " .. mob.data.mob_id .. "|" .. mob.data.name)
        peer:send_command("spawn_mob", {
            position = { x = mob.x, y = mob.y },
            owner_id = owner_id,
            mob = mob.data,
        })
    end)
end)
