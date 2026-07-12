---@meta

---Item description
---@class Item
---@field itemID integer Item ID
---@field attributes ItemAttribute[] Array of 3 effect values
Item = {}


---Item Attribute
---@class ItemAttribute
---@field index integer
---@field value integer
ItemAttribute = {}

---create a new item description
---@param itemID integer
---@param ...ItemAttribute max 3 attributes
---@return Item
function Item.new(itemID, ...) end;
