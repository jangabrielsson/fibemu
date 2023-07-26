--[[
   Simple echo server using net.UDPSocket()
   On same machine (Liux/MacOS) run
--]]

--------- Not currently working ------------

ADDR = "192.168.1.129"
PORT = 8986
BROADCAST = true

class "UDPServer"
function UDPServer:__init(port, handler)
    self.port = port
    self.handler = handler
    self.udp = net.UDPSocket({
        broadcast = BROADCAST,
        --timeout = 10000,
        reuseport = true,
        reuseaddr = true
    })
end

function UDPServer:run()
    self.udp:bind(ADDR, self.port)
    local cb
    cb = {
        success = function(data, ip, port)
            self.handler(self, data, ip, port)
            self.udp:receive(cb)     -- will read next datagram
        end,
        error = function(error)
            self:debug("UDP server error:", error)
        end
    }
    print("Server waiting")
    self.udp:receive(cb)
    print("Running UDP server at port ", self.port)
end

--%%name=TCP Test
function QuickApp:onInit()

---@diagnostic disable-next-line: undefined-global
    local server = UDPServer(PORT, function(self, data, ip, port)
        print("Recieved", data, ip, port)
        self.udp:sendTo("OK", ip, port, {
            success = function()
                print("Sent ok")
            end,
            error = function(error)
                print('Error:', error)
            end
        })
    end)
    server:run()

    self.udp = net.UDPSocket({
        broadcast = BROADCAST,
        --timeout = 10000,
        reuseport = true,
        reuseaddr = true
    })

    local seqNr = 1

    local function loop()
        local msg = "HELLO-"..seqNr
        print("Client sending",msg, BROADCAST and "255.255.255.255" or ADDR, PORT)
        self.udp:sendTo(msg, BROADCAST and "255.255.255.255" or ADDR, PORT, {
        success = function(n)
            print("Sent",n,"bytes")
            self.udp:receive({
                success = function(data,ip,port)
                    print("Recieved ",data, ip, port)
                    setTimeout(loop,2000)
                end,
                error = function(error)
                    self:debug("Error:", error)
                end
            })
        end,
        error = function(error)
            print('UPD Client Error:', error)
        end
        })
        fibaro.sleep(1000)
    end
    loop()
end

