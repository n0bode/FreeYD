---@meta

---Represents the current player state on the server.
---@class PlayerState
---@field position_x integer
---@field position_y integer
local PlayerState = {};

---Represents a client connection (network peer).
---@class Peer
---@field account      Account
---@field peer_id      integer
---@field player_state PlayerState
local Peer = {}

---Sends a text message to the client.
---@param message string
function Peer:send_text(message) end

---Associates the peer with the given account.
---@param account Account
function Peer:associate(account) end

---Disconnects the client.
function Peer:disconnect() end
