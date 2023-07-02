--[[
   Simple websocket test
--]]

--%%name=TCP Test
--%%var=url:"wss://echo.websocket.org"

function QuickApp:onInit()
    self:debug("onInit")
    local url = self:getVariable("url")
    self.sock = net.WebSocketClient()

    self.sock:addEventListener("connected", function() self:handleConnected() end)
    self.sock:addEventListener("disconnected", function() self:handleDisconnected() end)
    self.sock:addEventListener("error", function(error) self:handleError(error) end)
    self.sock:addEventListener("dataReceived", function(data) self:handleDataReceived(data) end)

    self.sock:connect(url)
end

function QuickApp:handleConnected()
    self:debug("connected")
    self.sock:send("Hello from fibemu")
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