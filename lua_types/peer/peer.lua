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


---@class SendCommandOptions
---@field peer_id integer overload peer_id event, used when command from another peer

---Send a event to client
---@overload fun(self: Peer, event: "spawn_char", data: CharSpawnCommand, opts: SendCommandOptions?) ?string
---@overload fun(self: Peer, event: "spawn_mob", data: MobSpawnCommand, opts: SendCommandOptions?) ?string
---@overload fun(self: Peer, event: "delete_mob", data: MobDeleteCommand, opts: SendCommandOptions?) ?string
---@overload fun(self: Peer, event: "motion_mob", data: MobMotionEvent, opts: SendCommandOptions?) ?string
---@return string? error message
function Peer:send_command(event, data) end
