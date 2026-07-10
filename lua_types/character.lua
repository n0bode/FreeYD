---@meta

---User character (mapped from the Zig `Character` struct).
---Numeric fields are mapped with their original names (no snake_case conversion).
---@class Character
---@field name string  Character name (up to 16 chars)
---@field gold integer Available gold
local Character = {}
