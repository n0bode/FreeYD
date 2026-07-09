---@meta

---Conta de usuário (mapeada do `Account` Zig).
---Os campos numéricos são mapeados com os nomes originais (sem snake_case).
---@class Character
---@field name       string  Nome do usuário (até 16 chars)
---@field gold       integer Ouro disponível
local Character = {}
