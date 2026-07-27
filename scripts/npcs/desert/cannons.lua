local server = require("server");
local logger = require("logger");

local function create_cannon(x, y)
    server:spawn_item {
        item = Item.new(746),
        position = { x = x, y = y },
        rotation = 1,
    }
end


create_cannon(1129, 1717)
create_cannon(1129, 1713)
create_cannon(1129, 1702)
create_cannon(1129, 1698)
