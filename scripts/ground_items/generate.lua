local server = require("server");
local logger = require("logger");


---@param item GroundItem
local function on_interact(peer, item)
    logger:info("on_interact_ground_item: id = " ..
        item.item_id .. ", peer_id = " .. peer.peer_id .. ",item_id = " .. item.item.item_id)

    item.state = 1
    peer:send_command("update_ground_item", {
        item_id = item.item_id,
        state = item.state,
    })
end

local function spawn_item(item_id, x, y, rot, state)
    server:spawn_item {
        item = Item.new(item_id),
        position = { x = x, y = y },
        on_interact = on_interact,
        rotation = rot,
        -- 1 OPEN DOORS
        -- 3 CAN INTERACT
        state = state,
    }
end

local items = {
    { 471,  217,  215,  1, 3 },
    { 471,  217,  221,  1, 3 },
    { 471,  217,  227,  1, 3 },
    { 471,  217,  151,  1, 3 },
    { 471,  217,  157,  1, 3 },
    { 471,  217,  163,  1, 3 },
    { 471,  161,  215,  1, 3 },
    { 471,  161,  221,  1, 3 },
    { 471,  161,  227,  1, 3 },
    { 471,  161,  151,  1, 3 },
    { 471,  161,  157,  1, 3 },
    { 471,  161,  163,  1, 3 },
    { 472,  2603, 1717, 1, 3 },
    { 472,  2603, 1733, 1, 3 },
    { 471,  2624, 1739, 1, 3 },
    { 471,  2624, 1731, 1, 3 },
    { 471,  2624, 1725, 1, 3 },
    { 471,  2624, 1719, 1, 3 },
    { 471,  2624, 1711, 1, 3 },
    -- window?
    { 458,  2075, 2015, 2, 3 },
    { 459,  2143, 1985, 2, 3 },
    { 461,  2081, 1961, 2, 3 },
    { 464,  2504, 2145, 1, 3 },
    { 468,  2528, 2134, 2, 3 },
    { 462,  2487, 2129, 1, 3 },
    { 463,  2518, 2106, 2, 3 },
    { 757,  2240, 1270, 0, 1 },
    { 758,  2248, 1246, 2, 1 },
    { 759,  2262, 1224, 1, 1 },
    { 760,  2279, 1209, 2, 1 },
    { 761,  2265, 1174, 1, 1 },
    { 758,  2230, 1246, 2, 1 },
    { 759,  2216, 1224, 1, 1 },
    { 760,  2199, 1209, 2, 1 },
    { 761,  2213, 1174, 1, 1 },
    { 773,  1129, 1707, 1, 1 },
    { 773,  1116, 1707, 1, 1 },
    { 773,  1094, 1690, 1, 1 },
    { 800,  1075, 1711, 1, 1 },
    -- cannos
    { 746,  1129, 1717, 1, 3 },
    { 746,  1129, 1713, 1, 3 },
    { 746,  1129, 1702, 1, 3 },
    { 746,  1129, 1698, 1, 3 },
    -- towers
    { 3145, 2131, 2115, 1, 0 },
    { 3145, 2493, 1718, 1, 0 },
    { 3145, 2454, 1996, 3, 0 },
    { 3145, 1060, 1717, 1, 0 },
}

for _, item in ipairs(items) do
    spawn_item(item[1], item[2], item[3], item[4], item[5])
end
