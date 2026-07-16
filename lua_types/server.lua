---@meta

---@class Server
local Server = {}

---Registers a handler for a server event.
---@overload fun(self: Server, event: "on_disconnected", handler: fun(peer: Peer))
---@overload fun(self: Server, event: "on_create_char", handler: fun(peer: Peer, req: CharCreateEvent): boolean)
---@overload fun(self: Server, event: "on_delete_char", handler: fun(peer: Peer, req: CharDeleteEvent): boolean)
---@overload fun(self: Server, event: "on_pinpassword", handler: fun(peer: Peer, req: PinPasswordEvent): boolean)
---@overload fun(self: Server, event: "on_spawn_char",  handler: fun(peer: Peer, req: CharSpawnEvent))
---@overload fun(self: Server, event: "on_mob_move",  handler: fun(peer: Peer, req: MobMotionEvent))
---@overload fun(self: Server, event: "on_whisper",  handler: fun(peer: Peer, req: WhisperEvent))
---@overload fun(self: Server, event: "on_login", handler: fun(peer: Peer, req: LoginEvent): boolean)
---@param event string Event name
---@param handler fun(peer: Peer, req: any) Callback invoked when the event fires
function Server:on(event, handler) end

---@class World
---@field players_count integer number of player current in server
local World = {}

---get all mobs within distance range
---@param position Position
---@param distance integer
function World:list_mobs_near(position, distance) end

---@class Rect
---@field x integer
---@field y integer
---@field width integer
---@field height integer

---get all mobs within area
---@param rect Rect
---@return Mob[]
function World:list_mobs_in_area(rect) end

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

---@class MulticastOptions
---@field time? integer Optional timestamp for the multicast event
---@field filter? fun(Peer): boolean filter
---@field opcode? integer

---@class MulticastAreaCommand
---@field x integer position origin from multicast
---@field y integer position origin from multicast
---@field width integer distance between origin and other players
---@field height integer distance between origin and other players

---Broadcasts an event to all connected peers.
---@param event string Event name
---@param data table Event data to send
---@param area MulticastAreaCommand parameters to send multicast command
---@param opts MulticastOptions? overload options
---@overload fun(self: Server, event: "mob_spawn", area: MulticastAreaCommand, data: MobSpawnCommand, opts: MulticastOptions?)
---@overload fun(self: Server, event: "mob_move", area: MulticastAreaCommand, data: MobMoveCommand, opts: MulticastOptions?)
---@return string error message if the multicast fails
function Server:multicast_command_in_area(event, area, data, opts) end

return Server
