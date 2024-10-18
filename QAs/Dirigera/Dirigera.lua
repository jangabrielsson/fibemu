--[[
Dirigera connectivity for the Fibaro Home Center 3
Copyright (c) 2021 Jan Gabrielsson
Email: jan@gabrielsson.com
                    GNU GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007

 Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.

 SHA 256 library from @tinman
--]]

--%%name=Dirigera
--%% id=1782
--%%type=com.fibaro.deviceController
--%%u={{button='b1',text='Request token', onReleased='requestToken'},{button='b2',text='Get token', onReleased='getToken'}}
--%%u={{button='b3',text='Remove children', onReleased='removeChildren'},{button='b4',text='Restart', onReleased='restartQA'}}
--%%u={button='b5',text='List device info', onReleased='listDeviceInfo'}
--%%file=dev/sha2.lua,sha2;
--%%file=examples/Dirigera/QwikChild.lua,QC;
--%%file=examples/Dirigera/Lib.lua,Lib;
--%%file=examples/Dirigera/Devices.lua,Devices;
--%%file=examples/Dirigera/Auth.lua,Auth;
--%%var=IP:"192.168.1.165"

--%%debug=refresh:false

local VERSION = "0.95"
DG = DG or { childs = {}}
EVENT = EVENT or {}
---------------------------------------------------------------
---  local variables ------------------------------------------
---------------------------------------------------------------
Hub = {
  IP = nil,
  port = "8443",
  api_version = "v1",
  api_base_url = nil,
  lastRequest = nil
}
local fmt = string.format
fibaro.debugFlags = fibaro.debugFlags or { test=false, http=true, color=true }

local MessageHandler = {}
function MessageHandler.deviceStateChanged(data)
  local d = DG.devices.id[data.data.id]
  if d and d.object then d.object:change(data.data) end
end
function MessageHandler.sceneUpdated(data)
  print("SCENE",data.data.info.name)
end

function QuickApp:restartQA()
  printc("red","Restarting QuickApp...")
  plugin.restart()
end

function QuickApp:listDeviceInfo()
  local pr = function(...) printc("yellow",...) end
  for _,dev in pairs(DG.devices.id) do
    local d = dev.object
    local a = d.attributes
    pr("%s '%s' %s",d.deviceType,d.name,d.id)
    pr("model:%s",a.model or "")
    pr("manufacturer:%s",a.manufacturer or "")
    pr("firmware:%s",a.firmwareVersion or "")
    pr("hardware:%s",a.hardwareVersion or "")
    pr("----------------------------------")
  end
end

function QuickApp:removeChildren()
  for id,_ in pairs(self.childDevices or {}) do self:removeChildDevice(id) end
end

function QuickApp:listen()
  DEBUGF('test',"Websocket connect")
  local url = fmt("wss://%s:%s/%s",Hub.IP,Hub.port,Hub.api_version)
  local headers = {
    ["Authorization"] = "Bearer "..self.store.token
  }
  local function handleConnected()
    DEBUGF('test',"Connected")
  end
  local function handleDisconnected()
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
    --print(data)
    data = json.decode(data)
    local handler  = MessageHandler[data.type or ""]
    if handler then handler(data) 
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
  self.sock:connect(url, headers)
end
function QuickApp:onInit()
  print("Dirigera version:",VERSION)
  function self.initChildDevices() end
  local IP = self:getVariable("IP")
  if IP == "" then
    self:warning("Please set IP address of Dirigera")
    return
  end
  Hub.IP = IP
  self.store = self:setupStorage()
  self:defineClasses()
  if self.store.token == nil then
    print("Please Request & Get token...")
    return
  else
    print("Your TOKEN :",self.store.token)
  end
  Hub.api_base_url = fmt("https://%s:%s/%s",Hub.IP,Hub.port,Hub.api_version)
  self:DGET("/devices",function(data)
    for _,d in ipairs(data) do
      DG:addDevice(d)
    end
    self:DGET("/scenes",function(data)
      for _,d in ipairs(data) do
        DG:addScene(d)
      end
      self:DGET("/home",function(data)
        -- check for deviceSets?
        self:post({type="start"})
      end)
    end)
  end)
end

function EVENT:start(ev)
  local hub = DG.devices.type['gateway']
  local attr = hub.attributes
  printf("Gateway: %s",attr.customName or "")
  printf("model:%s",attr.model)
  printf("firmware:%s",attr.firmwareVersion)
  printf("hardware:%s",attr.hardwareVersion)  
  quickApp:initChildren(DG.childs)
  DG:linkDevices()
  quickApp:listen()
  -- quickApp:post(function() quickApp:scene("Tända sovrum",true) end,3000)
  -- quickApp:post(function() quickApp:scene("Tända sovrum",false) end,6000)
  --quickApp:createScene("Test42")
  --quickApp:DDEL("/scenes/716340ae-4124-4445-bac7-32a2e0bb1a9e")
  --quickApp:post(function() DG.devices.name['Led sovrum'].object:turnOn() end,3000)
  --quickApp:post(function() DG.devices.name['Led sovrum'].object:turnOff() end,6000)
end