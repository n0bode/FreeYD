---@meta

---@class Logger
local Logger = {}

---Logs an informational message.
---@param message any
function Logger:info(message) end

---Logs a warning message.
---@param message any
function Logger:warn(message) end

---Logs an error message.
---@param message any
function Logger:error(message) end

---Logs a debug message.
---@param message any
function Logger:debug(message) end

return Logger
