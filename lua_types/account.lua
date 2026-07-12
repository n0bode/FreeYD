---@meta

---Defines the possible states of a user account.
---@enum AccountState
AccountState = {
    NEW_ACCOUNT = 0,
    OFFLINE = 1,
    LOGGED = 2,
    BANNED = 3,
    PLAYING = 6,
}

---User account (mapped from the Zig `Account` struct).
---Numeric fields are mapped with their original names (no snake_case conversion).
---@class Account
---@field account_id    integer Unique account ID
---@field name          string  Username (up to 16 chars)
---@field password      string  Hashed password (up to 16 chars)
---@field pin_password  string  Numeric PIN (6 bytes)
---@field server        integer Origin server
---@field gold          integer Available gold
---@field char_info     integer Character information (flags)
---@field char_selected integer Index of the selected character
---@field characters    Character[]
---@field state         AccountState
local Account = {}

---Saves the account to the database.
---@param db Database
function Account:save(db) end

---Returns the character currently associated with the account.
---@return Character?
function Account:get_current_char() end

---Create a new character for the account.
---@param name string
---@param class CharacterClass
---@param slotId integer
---@param type CharacterSoul
---@param builder fun(char: Character) optional function to customize the character after creation
---@return Character?
---@return string? error_message
function Account:create_character(name, slotId, class, type, builder) end

---Get a character by its index in the account's character list.
---@param index integer 0-3
---@return Character?
---@return string? ?error_message
function Account:get_character(index) end
