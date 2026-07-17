local server = require("server")
local logger = require("logger")

server:on("on_create_char", function(peer, req)
    logger:info("iniciando o login")
    local db = server:get_database()

    if (req.name == "root") then
        peer:send_command("char_create_failed", "nome invalido")
        return
    end

    local account = peer.account
    logger:info("account(" .. account.name .. ") a new char with name " .. req.name)

    local char, err = account:create_character(req.name, req.slot, req.class, CharacterSoul.MORTAL, function(char)
        -- trainer field
        char.position.x = 2112
        char.position.y = 2042

        local full = { index = 43, value = 9 }
        local sets = {
            [CharacterClass.TK] = { 1106, 1118, 1130, 1142, 1152 },
            [CharacterClass.FM] = { 1253, 1265, 1277, 1289, 1301 },
            [CharacterClass.BM] = { 1418, 1421, 1424, 1427, 1430 },
            [CharacterClass.HT] = { 1568, 1571, 1574, 1577, 1580 }
        }

        for i, item in ipairs(sets[char.class]) do
            char:set_equipment(i, Item.new(item, full))
        end

        char:set_equipment(EquipmentSlot.weapon, Item.new(2704, full))
        char:set_equipment(EquipmentSlot.shield, Item.new(2704))
        char:set_equipment(EquipmentSlot.mount, Item.new(2378, full))

        -- TODO: ler de uma tabela ou algo do tipo
        char.skill_points = 255
        char.stats.state.merchant = 2;
        char.stats.skills.skill0 = 10;
        char.stats.skills.skill1 = 91
        char.stats.skills.skill2 = 92
        char.stats.skills.skill3 = 93
        char.stats.state.movement_speed = 7
        char.current_stats.state.movement_speed = 7
        char.stats.str = 100
        char.stats.int = 100
        char.stats.state.pk_level = 10;
        char.current_stats.state.pk_level = 10;
    end)

    if err ~= nil then
        logger:error("erro ao criar char: " .. err)
        peer:send_command("char_create_failed", "failed to create")
        return false
    end


    -- save creation
    account:save(db)
    peer:send_command("char_created", "character created")
    return true
end)
