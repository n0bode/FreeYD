---@meta

---@class Server
local Server = {}

---Registra um handler para um evento do servidor.
---@overload fun(self: Server, event: "on_login",       handler: fun(peer: Peer, req: PacketLogin): boolean)
---@overload fun(self: Server, event: "on_pinpassword", handler: fun(peer: Peer, req: PacketPinPassword): boolean)
---@overload fun(self: Server, event: "on_enterworld", handler: fun(peer: Peer, req: PacketEnterWorld): boolean)
---@param event string Nome do evento
---@param handler fun(peer: Peer, req: any) Callback invocado quando o evento ocorre
function Server:on(event, handler) end

---Retorna a instância do banco de dados.
---@return Database?
function Server:get_database() end

return Server
