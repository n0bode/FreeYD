---@meta

---Representa o estado atual do player no servidor
---@class PlayerState
---@field position_x integer
---@field position_y integer
local PlayerState = {};

---Representa a conexão de um cliente (peer de rede).
---@class Peer
---@field account Account
---@field peer_id integer
---@field player_state PlayerState
local Peer = {}

---Envia uma mensagem de texto ao cliente.
---@param message string
function Peer:send_text(message) end

---Configura a conta de que o peer está associado.
---@param account Account
function Peer:associate(account) end

---Desconecta o cliente.
function Peer:disconnect() end
