--[[
   Simple websocket test
--]]

--%%name=Websocket Test
--%%type=com.fibaro.binarySwitch
--%%var=url:"wss://echo.websocket.events/"

local version = "0.5"
function QuickApp:onInit()
    self:debug("onInit")
    local url = self:getVariable("url")
    self.sock = net.WebSocketClient()

    self.sock:addEventListener("connected", function() self:handleConnected() end)
    self.sock:addEventListener("disconnected", function() self:handleDisconnected() end)
    self.sock:addEventListener("error", function(error) self:handleError(error) end)
    self.sock:addEventListener("dataReceived", function(data) self:handleDataReceived(data) end)

    self.sock:connect(url)

    --setInterval(function() self:debug("interval") end, 1000)
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


--EXPORT
function QuickApp:turnOn() -- turns on the device
end

--EXPORT
function QuickApp:turnOff() -- turns on the device
end

--EXPORT
function QuickApp:secretFun(x,y) -- takes 2 arguments, try if you dare
end
