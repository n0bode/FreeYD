---@meta

---@class Server
local Server = {}

---Registers a handler for a server event.
---@overload fun(self: Server, event: "on_disconnected", handler: fun(peer: Peer))
---@overload fun(self: Server, event: "on_create_char", handler: fun(peer: Peer, req: CharCreateEvent): boolean?)
---@overload fun(self: Server, event: "on_delete_char", handler: fun(peer: Peer, req: CharDeleteEvent): boolean?)
---@overload fun(self: Server, event: "on_pinpassword", handler: fun(peer: Peer, req: PinPasswordEvent): boolean?)
---@overload fun(self: Server, event: "on_spawn_char",  handler: fun(peer: Peer, req: CharSpawnEvent))
---@overload fun(self: Server, event: "on_chat_message",  handler: fun(peer: Peer, req: ChatMessageEvent))
---@overload fun(self: Server, event: "on_chat_whisper",  handler: fun(peer: Peer, req: ChatWhisperEvent))
---@overload fun(self: Server, event: "on_teleport",  handler: fun(peer: Peer, req: TeleportEvent))
---@overload fun(self: Server, event: "on_motion_mob",  handler: fun(peer: Peer, req: MobMotionEvent))
---@overload fun(self: Server, event: "on_move_item",  handler: fun(peer: Peer, req: MoveItemEvent))
---@overload fun(self: Server, event: "on_drop_item",  handler: fun(peer: Peer, req: DropItemEvent))
---@overload fun(self: Server, event: "on_login", handler: fun(peer: Peer, req: LoginEvent): boolean)
---@overload fun(self: Server, event: "on_interact_ground_item", handler: fun(peer: Peer, req: LoginEvent): boolean)
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

---Creates a new NPC in the world.
---@param npc_info NPCCreateInfo
function Server:create_npc(npc_info) end

---@class SpawnItemInfo
---@field item Item
---@field position Position
---@field rotation integer? default 0
---@field on_interact fun(peer: Peer, item: GroundItem)
---@field state integer? default 0
---@field height integer? default 1
---@field create integer? default 1

---@param info SpawnItemInfo
function Server:spawn_item(info) end

---Spawn the player mob for this peer in the world.
---@param peer Peer
---@param slot_id integer The slot ID of the character to spawn.
---@param x integer The x-coordinate where the mob should be spawned.
---@param y integer The y-coordinate where the mob should be spawned.
---@return SpawnedMob
function Server:spawn_player(peer, slot_id, x, y) end

return Server
