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
            self:post{type='connected'}
        end,
        error = function(message)
            self:debug("connection error:%s", message)
        end,
    })
end

function Event:connected(ev)
    self.sock:write("HELLO\n",{
        success = function(n)
            self:debug("wrote %s bytes",n)
            --self:post{type='read'}
            fibaro.sleep(1000)
            self:post{type='connected'}
        end,
        error = function(message)
            self:debug("send error:%s", message)
        end,
    })
end

function Event:read(ev)
    self.sock:read({
        success = function(msg)
            self:debug("read '%s'",msg)
        end,
        error = function(message)
            self:debug("read error:%s", message)
        end,
    })
end

function QuickApp:onInit()
    self:debug(self.name,self.id)
    post({type='init'}, {host="127.0.0.1",port=8986})
end

