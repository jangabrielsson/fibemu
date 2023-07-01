--[[
   Simple echo server using net.TCPSocket()
   On same machine (Liux/MacOS) run 
   >nc -l 8986
   to start a socket server to interact with this app
--]]

PORT = 8986
--%%name=TCP Test

local Event = {}
local function post(ev,self) 
    self = self or {}
    function self:post(ev) Event[ev.type](self,ev) end
    function self:debug(...) print(string.format(...)) end
    Event[ev.type](self,ev) 
end

function Event:init(ev)
    self.sock = net.TCPSocket()
    self:debug("init")
    self:post{type='connect'}
end

function Event:connect(ev)
    self.sock:connect(self.host,self.port,{
        success = function(message)
            self:debug("connected",message)
            self:post{type='prompt'}
        end,
        error = function(message)
            self:debug("connection error:%s", message)
        end,
    })
end

function Event:prompt(ev)
    self.sock:write("Echo:",{
        success = function(n)
            self:debug("wrote %s bytes",n)
            self:post{type='read'}
        end,
        error = function(message)
            self:debug("send error:%s", message)
        end,
    })
end

function Event:read(ev)
    self.sock:read({
        success = function(msg)
            self:debug("Echo '%s'",msg)
            self.sock:write(string.format("Echo '%s'\n",msg))
            self:post{type='prompt'}
        end,
        error = function(message)
            self:debug("read error:%s", message)
        end,
    })
end

function QuickApp:onInit()
    self:debug(self.name,self.id)
    post({type='init'}, {host="127.0.0.1",port=PORT})
end

