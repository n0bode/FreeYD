local server = require("server");
local logger = require("logger");

server:on("on_chat_message", function(peer, req)
    logger:info("chat_message = (" .. peer.peer_id .. ")[" .. req.message .. "]:")
end)
