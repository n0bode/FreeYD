local server = require("server")
local logger = require("logger")

---@param src  {x: integer, y: integer}
---@param func fun(mob: Mob, position: integer)
local function each_mobs_in_area(src, func)
    local multicast_area = tonumber(os.getenv("MULTICAST_AREA"))

    local area = {
        x = src.x - multicast_area / 2,
        y = src.y - multicast_area / 2,
        width = multicast_area,
        height = multicast_area,
    }

    local map = server:get_world()
    map:each_mobs_in_area(area, function(entity, position, is_item)
        if is_item then return end
        if is_player(entity.mob_id) then
            return
        end
        func(entity, position)
    end)
end

return {
    each_mobs_in_area = each_mobs_in_area
}
