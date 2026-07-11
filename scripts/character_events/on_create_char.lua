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
        -- TODO: ler de uma tabela ou algo do tipo
        char.citizen_info.city = Cities.CITY2
        char.skill_points = 255
        char.stats.state.merchant = 2;
        char.stats.skills.skill0 = 10;
        char.stats.skills.skill1 = 91
        char.stats.skills.skill2 = 92
        char.stats.skills.skill3 = 93
        char.stats.str = 100
        char.stats.int = 100
        logger:info("chamou o builder " .. char.name)
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
