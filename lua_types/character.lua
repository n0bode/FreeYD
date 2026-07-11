---@meta

---@enum CharacterSoul
CharacterSoul = {
    MORTAL = 0,
    GOD = 1,
    CELESTIAL = 2,
    SUBCELESTIAL = 3,
}

---@enum CharaterClass
CharaterClass = {
    TK = 0,
    FM = 1,
    BM = 2,
    HT = 3,
}

---@class SkillAttributes
---@field skill0 integer
---@field skill1 integer
---@field skill2 integer
---@field skill3 integer
local SkillAttributes = {}

---@class CharacterStatsState
---@field merchant integer
---@field direction integer
---@field movement_speed integer
---@field pkLevel integer
local CharacterStatsState = {};

---@enum Cities
Cities = {
    ARMIA = 0,
    CITY1 = 1,
    CITY2 = 2,
    CITY3 = 3,
};

---@class CitizenInfo
---@field city Cities
---@field merchant integer
local CitizenInfo = {};

---@class CharacterStats
---@field level integer character level
---@field state CharacterStatsState state
---@field defense integer character defense
---@field attack integer character attack
---@field max_hp integer maximum hit points
---@field max_mp integer maximum mana points
---@field hp integer current hit points
---@field mp integer current mana points
---@field str integer points of strength
---@field dex integer points of dexterity
---@field int integer points of intelligence
---@field con integer points of constitution
---@field skills SkillAttributes array of skill IDs (up to 16 skills)
local CharacterStats = {}

---@class Position
---@field x integer X coordinate
---@field y integer Y coordinate

---User character (mapped from the Zig `Character` struct).
---Numeric fields are mapped with their original names (no snake_case conversion).
---@class Character
---@field name string  Character name (up to 16 chars)
---@field gold integer Available gold
---@field account_id integer ID of the account that owns this character
---@field skill_points integer amount available points skill
---@field slot_id integer Index of the character in the account's character list (0-3)
---@field class CharaterClass Character class
---@field soul CharacterSoul Character god class
---@field citizen_info CitizenInfo maximum mana points
---@field stats CharacterStats Character stats
---@field position Position Position of the character in the world
---@field current_stats CharacterStats Current stats (after buffs/debuffs)
local Character = {}
