local server = require("server");
local db = server.db;

local function on_user_entry(client, req)
    local account = client.get_acount()
    local clientId = client.get_id()

    server.send_message("ola mundo")
    client.send()
end

local function on_selected_char(client, req)

end

server.bind("on_user_connect", on_user_entry)
