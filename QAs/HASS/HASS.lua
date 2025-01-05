---@diagnostic disable: undefined-field
--%%name=HASS
--%%type=com.fibaro.deviceController
--%%proxy="HASSProxy"
--%%var=token:config.HASS_token
--%%var=url:config.HASS_url

--%%file=lib/QwikChild.lua,QC;
--%%file=QAs/HASS/HASSClasses.lua,classes;
--%%file=lib/BetterQA.lua,BQA;

--%%u={label="title",text="Label (Title)"}
--%%u={multi="deviceSelect",text="Devices",visible=true,onToggled="deviceSelect",options={}}
--%%debug=refresh:false

HASS = HASS or {}

local VERSION = "0.2"
local URL = ""
local token =""
local fmt = string.format 
function printf(fmt,...) print(fmt:format(...)) end
fibaro.debugFlags = fibaro.debugFlags or {}
function DEBUGF(flag,fmt,...) if fibaro.debugFlags[flag] then printf(fmt,...) end end
function ERRORF(f,...) fibaro.error(fmt(f,...)) end

function GET(path,cb)
  local url = URL..path
  local sts,err = net.HTTPClient():request(url,{
    options = {
      method = 'GET',
      --checkCertificate = false, -- if you get handshake error, try uncomment this
      timeout = 10000,
      headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. token
      }
    },
    success = function(resp)
      if resp.status == 200 then 
         if cb then cb(json.decode(resp.data)) end 
      else 
        fibaro.error(__TAG,json.encode(resp)) 
      end
    end,
    error = function(err)
      fibaro.error(__TAG,url,err)
    end
  })
end

function POST(path,payload,cb)
  local url = URL..path
  net.HTTPClient():request(url,{
    options = {
      method = 'POST',
      checkCertificate = false, -- if you get handshake error, try uncomment this
      headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. token
      },
      data = json.encode(payload)
    },
    success = function(resp)
      if resp.status == 200 then if cb then cb(resp.data) end end
    end,
    error = function(err)
      fibaro.error(__TAG,url,err)
    end
  })
end

local MessageHandler = {}
function MessageHandler.auth_required(data,ws,s)
  DEBUGF('test',"Websocket auth reqired")
  s:send(json.encode({type= "auth",access_token = token}))
end
function MessageHandler.auth_ok(data,ws,s)
  DEBUGF('test',"Websocket auth OK")
  s:send(json.encode({id=99,type= "subscribe_events",event_type= "state_changed"}))
end
function MessageHandler.result(data,ws)
  DEBUGF('test',"Result %s",json.encode(data))
  -- ws({type = "get_states"},function(data)
  --   for _,e in ipairs(data.result) do
  --     if e.entity_id == "light.right_window" then
  --       DEBUGF('test',"Entity %s",e.entity_id)
  --     end
  --   end
  -- end)
end
function MessageHandler.event(data,ws)
  local data = data.event.data
  local entity = data.entity_id
  DEBUGF('test',"Event %s",entity)
  local child = quickApp.children[entity]
  if child and child.change then child:change(data.new_state,data.old_state) end
end

function QuickApp:setupWebSocket()
  DEBUGF('test',"Websocket connect")
  local URL = "ws://192.168.1.161:8123/api"
  local url = URL.."/websocket"
  local headers = {
    ["Authorization"] = "Bearer "..token
  }
  local mid,mcbs = 99,{}
  local ws = function(data,cb)
    mid = mid + 1
    data.id = mid
    mcbs[mid] = {
      cb = cb,
      timeout = setTimeout(function()
        mcbs[mid] = nil
        end,5000) -- 5s timeout
    }
    self.sock:send(json.encode(data))
  end

  local function handleConnected()
    DEBUGF('test',"Connected")
  end
  local function handleDisconnected(a,b)
    DEBUGF('test',"Disconnected")
    self:warning("Disconnected - will restart in 5s")
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
      clearTimeout(timeout)
      pcall(cb,data)
      return
    end
    local handler  = MessageHandler[data.type or ""]
    if handler then handler(data,ws,self.sock) 
    else
      DEBUGF('test',"Unknown message type: %s",data.type)
    end
  end
  self.sock = net.WebSocketClientTls()
  self.sock:addEventListener("connected", handleConnected)
  self.sock:addEventListener("disconnected", handleDisconnected)
  self.sock:addEventListener("error", handleError)
  self.sock:addEventListener("dataReceived", handleDataReceived) 
  
  DEBUGF('test',"Connect: %s",url)
  self.sock:connect(url)
end

function QuickApp:onInit()
  -- GET("/services",function(data)
  --   print("Services",json.encode(data))
  -- end)
  fibaro.debugFlags.test = true
  print(self.name,"v:"..VERSION)
  self:updateView("title","text",self.name.." v:"..VERSION)
  token = self.qvar.token
  URL = self.qvar.url
  if not(token and URL) then
    self:warning("Please set URL and token")
    return
  end
  URL = fmt("http://%s/api",URL)
  GET("/states",function(data)
    local allDevices = {}
    local unknowns = {}
    local devices = self.storage.devices or {}
    local children = {} HASS.children = children
    for _,e in ipairs(data) do
      if HASS.deviceTypes[e.attributes.device_class or ""] then
        allDevices[e.entity_id] = {type=e.attributes.device_class,data=e}
      elseif e.entity_id:match("^light%.") then
        allDevices[e.entity_id] = {type="light",data=e}
      else
        unknowns[#unknowns+1] = fmt("Unknown entity %s %s",e.entity_id,e.attributes.device_class or "")
      end
      if devices[e.entity_id] then
        children[e.entity_id] =  HASS.childData(allDevices[e.entity_id])
      end
    end
    table.sort(unknowns)
    print("<br>"..table.concat(unknowns,"<br>"))
    self:populatePopup(allDevices)
    self:initChildren(children)
    self:setupWebSocket()
  end)
end

function QuickApp:populatePopup(allDevices)
  local options = {}
  local values = {}
  local devices = self.storage.devices or {}
  local newDevices = {}
  for id,d in pairs(allDevices) do
    local name = fmt("%s %s",d.type,id)
    local i = {text=name,type="option",value=id}
    table.insert(options,i)
    newDevices[id] = devices[id] or false
    if newDevices[id] then table.insert(values,id) end
  end
  self.storage.devices = newDevices
  table.sort(options,function(a,b) return a.text < b.text end)
  self:updateView("deviceSelect","options",options)
  self:updateView("deviceSelect","selectedItems",values)
end

function QuickApp:deviceSelect(data)
  local devices = self.storage.devices
  for id,_ in pairs(devices) do devices[id] = false end
  for _,d in pairs(data.values[1] or {}) do
    devices[d] = true
  end
  self.storage.devices = devices
  self:restart()
end

function QuickApp:restart() plugin.restart() end