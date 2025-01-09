---@diagnostic disable: undefined-global
local fmt = string.format
function printf(fmt,...) print(fmt:format(...)) end
fibaro.debugFlags = fibaro.debugFlags or {}
function DEBUGF(flag,fmt,...) if fibaro.debugFlags[flag] then printf(fmt,...) end end
function ERRORF(f,...) fibaro.error(fmt(f,...)) end

class 'WSConnection'
function WSConnection:__init(url,token)
  self.token = token
  self.url = fmt("ws://%s/api/websocket",url)
end

local mid,mcbs = 99,{}
function WSConnection:sendRaw(data)
  self.sock:send(json.encode(data))
end
function WSConnection:send(data,cb)
  mid = mid + 1
  data.id = mid
  mcbs[mid] = {
    cb = cb,
    timeout = setTimeout(function() mcbs[mid] = nil end,5000) -- 5s timeout
  }
  self:sendRaw(data)
end

function WSConnection:serviceCall(domain, service, data, cb)
  self:send({type="call_service", domain=domain, service=service, service_data=data})
end

function WSConnection:connect()
  DEBUGF('wsc',"Websocket connect")
  local function handleConnected()
    DEBUGF('wsc',"Connected")
  end
  local function handleDisconnected(a,b)
    DEBUGF('wsc',"Disconnected")
    fibaro.warning(__TAG,"Disconnected - will restart in 5s")
    setTimeout(function()
      plugin.restart()
    end,5000)
  end
  local function handleError(err)
    ERRORF("Error: %s", err)
  end
  local nEvents = 0
  setInterval(function()
  end,60*60*1000)
  local function handleDataReceived(data)
    nEvents = nEvents+1
    data = json.decode(data)
    if data.id and mcbs[data.id] then
      local cb,timeout = mcbs[data.id].cb,mcbs[data.id].timeout
      mcbs[data.id] = nil
      if timeout then clearTimeout(timeout) end
      if cb then 
        local stat,err = pcall(cb,data) 
        if not stat then ERRORF("Callback error: %s",err) end
      else print(json.encode(data)) end
      return
    end
    if self.msgHandler then self:msgHandler(data)
    else
      DEBUGF('wsc',"Unknown message type: %s",data.type)
    end
  end
  self.sock = net.WebSocketClient()
  self.sock:addEventListener("connected", handleConnected)
  self.sock:addEventListener("disconnected", handleDisconnected)
  self.sock:addEventListener("error", handleError)
  self.sock:addEventListener("dataReceived", handleDataReceived)

  DEBUGF('wsc',"Connect: %s",self.url)
  self.sock:connect(self.url)
end

getmetatable("").__idiv = function(str,len) return (#str < len or #str < 4) and str or str:sub(1,len-2)..".." end -- truncate strings

function string.buff(b)
  local self,buff = {},b or {}
  function self.printf(fmt,...) table.insert(buff,fmt:format(...)) end
  function self.tostring()
    local str = table.concat(buff)
    str = str:gsub("\n","<br>")
    str = str:gsub("  ","&nbsp;&nbsp;")
    print(table.concat(buff))
    buff = {}
  end
  return self
end