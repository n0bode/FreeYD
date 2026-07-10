---@meta

---Represents the database access interface.
---@class Database
local Database = {}

---
---@class CreateAccountInput
---@field username string
---@field password string
---@field email string
local CreateAccountInput = {}

---Fetches an account by login and password.
---@param login string
---@param password string
---@return Account?
function Database:get_account_by_credentials(login, password) end

---Saves an account to the database.
---@param account Account
function Database:save(account) end

---Create a new account in database
---@param account CreateAccountInput
function Database:create_account(account) end

-----Fetches an account by its unique ID.
---@param account_id integer
---@return Account?
function Database:get_account_by_id(account_id) end

---Get account by username
--- @param username string
--- @return Account?
function Database:get_account_by_username(username) end
