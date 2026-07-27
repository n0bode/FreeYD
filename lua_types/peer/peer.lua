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

---Get current mob peer
---@return Mob
function Peer:get_player_mob() end

---Check if another peer is the same as this peer
---@param another Peer
---@return boolean
function Peer:is_mine(another) end

---@class SendCommandOptions
---@field peer_id integer overload peer_id event, used when command from another peer

---Send a event to client
---@overload fun(self: Peer, event: "spawn_char", data: CharSpawnCommand, opts: SendCommandOptions?) ?string
---@overload fun(self: Peer, event: "move_item", data: ItemMoveCommand, opts: SendCommandOptions?) ?string
---@overload fun(self: Peer, event: "spawn_mob", data: MobSpawnCommand, opts: SendCommandOptions?) ?string
---@overload fun(self: Peer, event: "delete_mob", data: MobDeleteCommand, opts: SendCommandOptions?) ?string
---@overload fun(self: Peer, event: "motion_mob", data: MobMotionCommand, opts: SendCommandOptions?) ?string
---@overload fun(self: Peer, event: "enter_account", message: string?, opts: SendCommandOptions?) ?string
---@overload fun(self: Peer, event: "password_incorrect", message: string?, opts: SendCommandOptions?) ?string
---@overload fun(self: Peer, event: "char_created", message: string?, opts: SendCommandOptions?) ?string
---@overload fun(self: Peer, event: "char_deleted", message: string?, opts: SendCommandOptions?) ?string
---@overload fun(self: Peer, event: "char_create_failed", message: string?, opts: SendCommandOptions?) ?string
---@overload fun(self: Peer, event: "update_equipments", data: UpdateEquipmentsCommand, opts: SendCommandOptions?) ?string
---@overload fun(self: Peer, event: "chat_message", data: ChatMessageCommand, opts: SendCommandOptions?) ?string
---@overload fun(self: Peer, event: "drop_item", data: DropItemCommand, opts: SendCommandOptions?) ?string
---@overload fun(self: Peer, event: "create_item", data: CreateItemCommand, opts: SendCommandOptions?) ?string
---@overload fun(self: Peer, event: "delete_item", data: DeleteItemCommand, opts: SendCommandOptions?) ?string
---@return string? error message
function Peer:send_command(event, data) end
