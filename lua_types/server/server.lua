---@meta

---@class Server
local Server = {}

---Registers a handler for a server event.
---@overload fun(self: Server, event: "on_disconnected", handler: fun(peer: Peer))
---@overload fun(self: Server, event: "on_create_char", handler: fun(peer: Peer, req: CharCreateEvent): boolean?)
---@overload fun(self: Server, event: "on_delete_char", handler: fun(peer: Peer, req: CharDeleteEvent): boolean?)
---@overload fun(self: Server, event: "on_pinpassword", handler: fun(peer: Peer, req: PinPasswordEvent): boolean?)
---@overload fun(self: Server, event: "on_spawn_char",  handler: fun(peer: Peer, req: CharSpawnEvent))
---@overload fun(self: Server, event: "on_mob_move",  handler: fun(peer: Peer, req: MobMotionEvent))
---@overload fun(self: Server, event: "on_whisper",  handler: fun(peer: Peer, req: WhisperEvent))
---@overload fun(self: Server, event: "on_login", handler: fun(peer: Peer, req: LoginEvent): boolean)
---@param event string Event name
---@param handler fun(peer: Peer, req: any) Callback invoked when the event fires
function Server:on(event, handler) end

---Returns the database instance.
---@return Database
function Server:get_database() end

---Returns the world instance
---@return World
function Server:get_world() end

---Returns the database instance.
---@return integer get current time of server
function Server:get_time() end

---Returns the database instance.
---@return integer timestamp of server in local date
function Server:get_local_date() end

---Returns the peer instance of peer_id
---@param peer_id integer unique peer_id
---@return Peer? timestamp of server in local date
function Server:get_peer(peer_id) end

---@class MulticastOptions
---@field time? integer Optional timestamp for the multicast event
---@field filter? fun(receiver: Peer): boolean filter
---@field opcode? integer

---@class QueryArea
---@field x integer position origin x
---@field y integer position origin y
---@field width integer width of area from x to x + width
---@field height integer height of area from y to y + height

---Multicast in area an event to all connected peers.
---@param event string Event name
---@param data table Event data to send
---@param area QueryArea parameters to send multicast command
---@param opts MulticastOptions? overload options
---@overload fun(self: Server, event: "mob_spawn", area: QueryArea, data: MobSpawnCommand, opts: MulticastOptions?)
---@overload fun(self: Server, event: "mob_move", area: QueryArea, data: MobMoveCommand, opts: MulticastOptions?)
---@return string error message if the multicast fails
function Server:multicast_command_in_area(event, area, data, opts) end

return Server
