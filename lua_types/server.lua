---@meta

---@class Server
local Server = {}

---Registers a handler for a server event.
---@overload fun(self: Server, event: "on_login",       handler: fun(peer: Peer, req: LoginRequest): boolean)
---@overload fun(self: Server, event: "on_pinpassword", handler: fun(peer: Peer, req: PinPasswordRequest): boolean)
---@overload fun(self: Server, event: "on_enterworld",  handler: fun(peer: Peer, req: EnterWorldRequest): boolean)
---@overload fun(self: Server, event: "on_disconnected", handler: fun(peer: Peer))
---@param event string Event name
---@param handler fun(peer: Peer, req: any) Callback invoked when the event fires
function Server:on(event, handler) end

---Returns the database instance.
---@return Database?
function Server:get_database() end

return Server
