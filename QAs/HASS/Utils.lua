---@diagnostic disable: undefined-global
HASS = HASS or {}
local fmt = string.format
function printf(fmt,...) print(fmt:format(...)) end
fibaro.debugFlags = fibaro.debugFlags or {}
function DEBUGF(flag,fmt,...) if fibaro.debugFlags[flag] then printf(fmt,...) end end
function ERRORF(f,...) fibaro.error(fmt(f,...)) end

-- function GET(path,cb)
--   local url = HASS.URL..path
--   net.HTTPClient():request(url,{
--     options = {
--       method = 'GET',
--       --checkCertificate = false, -- if you get handshake error, try uncomment this
--       timeout = 10000,
--       headers = {
--         ["Content-Type"] = "application/json",
--         ["Authorization"] = "Bearer " .. HASS.token
--       }
--     },
--     success = function(resp)
--       if resp.status == 200 then
--          if cb then cb(json.decode(resp.data)) end
--       else
--         fibaro.error(__TAG,json.encode(resp))
--       end
--     end,
--     error = function(err)
--       fibaro.error(__TAG,url,err)
--     end
--   })
-- end

-- function POST(path,payload,cb)
--   local url = HASS.URL..path
--   net.HTTPClient():request(url,{
--     options = {
--       method = 'POST',
--       checkCertificate = false, -- if you get handshake error, try uncomment this
--       headers = {
--         ["Content-Type"] = "application/json",
--         ["Authorization"] = "Bearer " .. HASS.token
--       },
--       data = json.encode(payload)
--     },
--     success = function(resp)
--       if resp.status == 200 then if cb then cb(resp.data) end end
--     end,
--     error = function(err)
--       fibaro.error(__TAG,url,err)
--     end
--   })
-- end

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
  local function handleDataReceived(data)
    data = json.decode(data)
    if data.id and mcbs[data.id] then
      local cb,timeout = mcbs[data.id].cb,mcbs[data.id].timeout
      mcbs[data.id] = nil
      if timeout then clearTimeout(timeout) end
      if cb then pcall(cb,data) else print(json.encode(data)) end
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