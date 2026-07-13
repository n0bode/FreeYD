local server = require("server")
local logger = require("logger")

server:on("on_create_char", function(peer, req)
    logger:info("iniciando o login")
    local db = server:get_database()
    if db == nil then
        peer:send_text("ops.. try again soon")
        return false
    end

    if (req.name == "root") then
        peer:send_text("nome invalido")
        return false;
    end

    local account = peer.account
    logger:info("account(" .. account.name .. ") a new char with name " .. req.name)

    local char, err = account:create_character(req.name, req.slot, req.class, CharacterSoul.MORTAL, function(char)
        -- trainer field
        char.position.x = 2112
        char.position.y = 2042

        local full = { index = 43, value = 9 }
        local sets = {
            [CharacterClass.TK] = 1106,
            [CharacterClass.FM] = 1253,
            [CharacterClass.BM] = 1418,
            [CharacterClass.HT] = 1568,
        }

        local set = sets[char.class]
        for i = 1, 5 do
            char:set_equipment(i, Item.new(set + 12 * (i - 1), full))
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
        char.stats.state.movement_speed = 10
        char.current_stats.state.movement_speed = 10
        char.stats.str = 100
        char.stats.int = 100
        char.stats.state.pk_level = 10;
        char.current_stats.state.pk_level = 10;
    end)

    if err ~= nil then
        logger:error("erro ao criar char: " .. err)
        peer:send_text(err)
        return false
    end

    -- save creation
    account:save(db)

    return true
end)
