--[[
   Simple websocket test
   On same machine (Liux/MacOS) run 
   >nc -l 8986
   to start a socket server to interact with this app
--]]

PORT = 8986
--%%name=TCP Test

function QuickApp:onInit()
    self:debug("onInit")
    --local url = self:getVariable("url") -- eg. wss://echo.websocket.org
    self.sock = net.WebSocketClient()

    self.sock:addEventListener("connected", function() self:handleConnected() end)
    self.sock:addEventListener("disconnected", function() self:handleDisconnected() end)
    self.sock:addEventListener("error", function(error) self:handleError(error) end)
    self.sock:addEventListener("dataReceived", function(data) self:handleDataReceived(data) end)

    self.sock:connect("ws://echo.websocket.events/")
end

function QuickApp:handleConnected()
    self:debug("connected")
end

function QuickApp:handleDisconnected()
    self:warning("handleDisconnected")
end

function QuickApp:handleError(error)
    self:error("handleError:", error)
end

function QuickApp:handleDataReceived(data)
    self:trace("dataReceived:", data)
end