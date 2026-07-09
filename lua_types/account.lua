---@meta

---Define os possíveis estados de uma conta de usuário.
---@enum AccountState
AccountState = {
    NEW_ACCCOUNT = 0,
    OFFLINE = 1,
    LOGGED = 2,
    BANNED = 3,
}

---Conta de usuário (mapeada do `Account` Zig).
---Os campos numéricos são mapeados com os nomes originais (sem snake_case).
---@class Account
---@field account_id  integer ID único da conta
---@field name       string  Nome do usuário (até 16 chars)
---@field password   string  Senha hash (até 16 chars)
---@field pin_password string PIN numérico (6 bytes)
---@field server     integer Servidor de origem
---@field gold       integer Ouro disponível
---@field char_info   integer Informações de personagem (flags)
---@field char_selected integer Índice do personagem selecionado
---@field state        AccountState
local Account = {}


---Retorna a conta atualmente associada ao cliente.
---@param db Database
function Account:save(db) end

---Retorna a conta atualmente associada ao cliente.
---@return Character?
function Account:get_current_char() end
