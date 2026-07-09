---@meta

---Representa a interface de acesso ao banco de dados.
---@class Database
local Database = {}

---Busca uma conta pelo login e senha.
---@param login string
---@param password string
---@return Account?
function Database:get_account_by_credentials(login, password) end

---Salva uma conta no banco de dados
---@param account Account
function Database:save(account) end
