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

    local player_mob = char:to_mob()
    if player_mob == nil then
        logger:error("Failed to convert character to mob for peer " .. peer.peer_id)
        return
    end

    local area = os.getenv("MULTICAST_AREA")
    logger:info("area: " .. area);
    local rect = {
        x = char.position.x - area / 2,
        y = char.position.y - area / 2,
        width = area,
        height = area,
    }

    local world = server:get_world()

    world:list_mobs_in_area(rect)
    -- notification all peers about new char
    server:multicast_command_in_area("mob_spawn", rect, {
        position = char.position,
        owner_id = peer.peer_id,
        mob = player_mob,
    })
end)
