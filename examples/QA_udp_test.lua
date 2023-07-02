--[[
   Simple echo server using net.UDPSocket()
   On same machine (Liux/MacOS) run 
   >nc -ul 8986
   to start a socket server to interact with this app
--]]

PORT = 8986
--%%name=TCP Test
function QuickApp:onInit()
    self.udp = net.UDPSocket({ 
        broadcast = true,
        timeout = 10000
    })
    self.udp:bind("127.0.0.1",8986)
    local payload = "HELLO"
 
    self.udp:sendTo(payload, '255.255.255.255', PORT, {
        success = function()
            self:receiveData()
        end,
        error = function(error)
            print('Error:', error)
        end    
    })
end

function QuickApp:receiveData()
    print("Waiting for data")
    self.udp:receive({
    success = function(data, ip, port)
        print("Recieved",data, ip, port)
        self:receiveData() -- will read next datagram
    end,
    error = function(error)
        self:debug("Error:", error)
    end})
end