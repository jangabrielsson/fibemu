---@diagnostic disable: undefined-field
--%%name=HASS
--%%type=com.fibaro.deviceController
--%%proxy="HASSProxy"
--%%var=token:config.HASS_token
--%%var=url:config.HASS_url

--%%file=lib/QwikChild.lua,QC;
--%%file=QAs/HASS/Utils.lua,utils;
--%%file=QAs/HASS/HASSClasses.lua,classes;
--%%file=lib/BetterQA.lua,BQA;

--%%u={label="title",text="Label (Title)"}
--%%u={multi="deviceSelect",text="Devices",visible=true,onToggled="deviceSelect",options={}}
--%%debug=refresh:false

HASS = HASS or {}

local VERSION = "0.45"
local fmt = string.format

local MessageHandler = {}
function MessageHandler.auth_required(data,ws)
  DEBUGF('test',"Websocket auth reqired")
  ws:sendRaw({type= "auth",access_token = HASS.token})
end
function MessageHandler.auth_ok(data,ws)
  DEBUGF('test',"Websocket auth OK")
  quickApp:authenticated()
end

function MessageHandler.event(data,ws)
  local data = data.event.data
  local entity = data.entity_id
  DEBUGF('test',"Event %s",entity)
  local child = quickApp.children[entity]
  if child and child.change then child:change(data.new_state,data.old_state) end
end

function QuickApp:onInit()
  print(self.name,"v:"..VERSION)
  fibaro.debugFlags.test = true
  fibaro.debugFlags.wsc = true
  self:updateView("title","text",self.name.." v:"..VERSION)

  local token,URL = self.qvar.token,self.qvar.url
  if not(token and URL) then
    self:warning("Please set URL and token")
    return
  end

  HASS.URL = fmt("http://%s/api",URL)
  HASS.token = token
---@diagnostic disable-next-line: undefined-global
  local WS = WSConnection("192.168.1.161:8123",token)
  self.WS = WS
  function WS:msgHandler(data)
    local f = MessageHandler[data.type]
    if f then f(data,self) else print(json.encode(data)) end
  end
  WS:connect()
end

local skipUnknowns = {battery=true,timestamp=true}
function QuickApp:authenticated() -- Called when websocket is authenticated
  DEBUGF('test',"Fetching HASS devices")
  self.WS:send({type= "get_states"},function(data)
    data = data.result
    DEBUGF('test',"...fetched %d devices",#data)
    local allDevices = {}
    local unknowns = {}
    local devices = self.storage.devices or {}
    local children = {} HASS.children = children
    for _,e in ipairs(data) do
      local domain = e.entity_id:match("^(.-)%.")
      if HASS.deviceTypes[e.attributes.device_class or ""] then
        allDevices[e.entity_id] = {type=e.attributes.device_class,data=e}
      elseif HASS.deviceTypes[domain] then
        allDevices[e.entity_id] = {type=domain,data=e}
      else
        if not skipUnknowns[e.attributes.device_class or ""] then
          unknowns[#unknowns+1] = fmt("Unknown entity %s %s",e.entity_id,e.attributes.device_class or "")
        end
      end
      if devices[e.entity_id] then
        children[e.entity_id] =  HASS.childData(allDevices[e.entity_id])
      end
    end
    self.WS:send({type= "subscribe_events",event_type= "state_changed"})
    table.sort(unknowns)
    print("<br>"..table.concat(unknowns,"<br>"))
    self:populatePopup(allDevices)
    self:initChildren(children)
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