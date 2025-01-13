--[[
Supported devices:
Property      Type           QA type                         QA className
-------------------------------------------------------------------------
domain        switch         com.fibaro.binarySwitch         Switch
domain        light          com.fibaro.multilevelSwitch     Light
com.fibaro.binarySwitch         BinarySwitch
device_class  temperature    com.fibaro.temperatureSensor    Temperature
device_class  illuminance    com.fibaro.lightSensor          Illuminance
device_class  humidity       com.fibaro.humiditySensor       Humidity
device_class  motion         com.fibaro.motionSensor         Motion
device_class  opening        com.fibaro.doorSensor           DoorSensor
domain        binary_sensor  com.fibaro.binarySensor         BinarySensor
device_class  pm25           com.fibaro.multilevelSensor     Pm25
domain        lock           com.fibaro.doorLock             DoorLock
domain        fan            com.fibaro.genericDevice        Fan
domain        cover          com.fibaro.rollerShutter        Cover
domain        device_tracker com.fibaro.binarySensor         DeviceTracker
--]]
---@diagnostic disable: undefined-global
HASS = HASS or {} -- Table to store "global" HASS functions and data
HASS.IFmap = HASS.IFmap or {}

local fmt = string.format

local round =  math.round
local to100 = math.to100
local to255 = math.to255

--[[---------------------------------------------------------
QA Class info
Class types and initial properties and interfaces.
Used when creating a QA of specific class
--------------------------------------------------------------]]
function MODULE_0classes() -- named to be loaded first...

  HASS.classes.DimLight = { type = "com.fibaro.multilevelSwitch",}
  HASS.classes.RGBLight = {
    type = "com.fibaro.colorController",
    properties = {colorComponents = {red=0,green=0,blue=0,warmWhite=0}},
    interfaces = {"ringColor","colorTemperature"},
  }
  HASS.classes.XYLight = {
    type = "com.fibaro.colorController",
    properties = {colorComponents = {red=0,green=0,blue=0,warmWhite=0}},
    interfaces = {"ringColor","colorTemperature"},
  }
  HASS.classes.BinarySwitch = { type = "com.fibaro.binarySwitch",}
  HASS.classes.BinarySensor = { type = "com.fibaro.binarySensor",}
  HASS.classes.Switch = { type = "com.fibaro.binarySwitch",}
  HASS.classes.Button = {
    type = "com.fibaro.remoteController",
    properties = {
      centralSceneSupport = {
        { 
          keyAttributes = {"Pressed","Released","HeldDown","Pressed2","Pressed3"},
          keyId = 1 
        }
      }
    },
    interfaces = {"zwaveCentralScene"},
  }
  HASS.classes.Rotary = {type = "com.fibaro.multilevelSensor",}
  local SpeakerUI = {
    {label="statusLabel",text="Status:"},
    {label="artistLabel",text="Artist"},
    {label="trackLabel",text="Track"},
    {select="favoriteSelector",text="Favorite",onToggled="favoriteSelected",options={}},
  }
  HASS.classes.Speaker = {
    type = "com.fibaro.player",
    properties = { uiView = fibaro.ui.UI2NewUiView(SpeakerUI) }
  }
  HASS.classes.Motion = { type = "com.fibaro.motionSensor",}
  HASS.classes.Lux = { type = "com.fibaro.lightSensor", }
  HASS.classes.DoorSensor = { type = "com.fibaro.doorSensor",}
  HASS.classes.DoorLock = { type = "com.fibaro.doorLock",}
  HASS.classes.Temperature = { type = "com.fibaro.temperatureSensor",}
  HASS.classes.Humidity = { type = "com.fibaro.humiditySensor",}
  HASS.classes.Pm25 = {
    type = "com.fibaro.multilevelSensor",
    properties = {unit = "µg/m³"}
  }
  HASS.classes.Fan = { type = "com.fibaro.genericDevice",}
  HASS.classes.Cover = { type = "com.fibaro.rollerShutter",}
  HASS.classes.DeviceTracker = { type = "com.fibaro.binarySensor",}
  HASS.classes.Calendar = { type = "com.fibaro.binarySensor",}
  HASS.classes.Thermostat = { type = "com.fibaro.hvacSystemAuto",}
end

-------------------------------------------------------------
-- Entities are the HASS entities read in at startup.
-- Incoming entity state changes are sent to the Entity object
-- that then sends the change to all subscribing QA children. 
-------------------------------------------------------------
class 'Entity'
function Entity:__init(e)
  self.id = e.entity_id
  self.name = e.attributes.friendly_name or self.id
  self.domain = self.id:match("^(.-)%.") or 'unknown'
  self.deviceClass = e.attributes.device_class or 'unknown'
  self.state = e.state
  self.attributes = e.attributes
  self.subscribers = {}
  self.entityName = self.id:match("^.-%.(.-)$") or "<noname>"
  self.type = self.domain..(e.attributes.device_class and ("_"..self.deviceClass) or "")
  for pattern,typ in pairs(HASS.customTypes) do
    if self.id:match(pattern) then
      if type(typ) == "function" then typ = typ(e) end
      if typ then self.type = typ break end
    end
  end
end

function Entity:__tostring()
  return fmt("[%s:%s:%s]",self.type,self.entityName,self.state)
end

function Entity:change(e)
  self.state = e.state
  self.attributes = e.attributes
  for s,_ in pairs(self.subscribers) do 
    local stat,err = pcall(s.change,s,self)
    if not stat then ERRORF("change:%s %s",err,tostring(s)) end
  end
end

function Entity:subscribe(subscriber)
  self.subscribers[subscriber] = true
  local stat,err = pcall(subscriber.change,subscriber,self)
  if not stat then ERRORF("change:%s %s",err,tostring(subscriber)) end
end

function Entity:unsubscribe(subscriber)
  self.subscribers[subscriber] = nil
end

function HASS.isEntity(entity_id)
  if type(entity_id) ~= 'table' then entity_id = {entity_id} end
  for _,e in ipairs(entity_id) do
    if not HASS.entities[e] then return false end
  end
  return true
end

--[[---------------------------------------------------------
QA Classes
Class types and initial properties and interfaces.
Used when creating a QA of specific class

The general flow is that the QA objects subscribe to state changes 
from HASS entities and the child QA updates it's properties accordingly.
Ex. If a HASS binary switch is turned on it sends a state_changed
event to the child QA with state=='on' and the child QA updates
it's state property to true.
When the child QA is turned on (self:turnOn()), we send the state change
to the HASS device, and we wait for the update back from the HASS device.
Alt. we could update the child QA state property directly, and wait for the
HASS update to verify that. At the moment we don't.
--------------------------------------------------------------]]

-- Base class for HASS devices
class 'HASSChild'(QwikAppChild)
function HASSChild:__init(device)
  self.uiCallbacks = {}
  QwikAppChild.__init(self, device)
  --self:registerUICallbacks()
  quickApp.childDevices[self.id] = self -- Hack to get the child devices reged.
  self.uid = self._uid
  local entities = self:internalStorageGet("entities") or {}
  self._rawEntities = entities
  self.entities = {}
  self.entityTypes = {}
  for _,entity in ipairs(entities) do
    local e = HASS.entities[entity]
    if e then
      self.entities[entity] = e
      local typ = e.type
      self.entityTypes[typ] = self.entityTypes[typ] or {}
      table.insert(self.entityTypes[typ],e)
      setTimeout(function() e:subscribe(self) end,0) -- QA gets update after initialized
    else
      WARNINGF("Entity %s for QA %s not found",entity,self.id)
    end
  end
  self:checkInterfaces()
end

function HASSChild:setEntities(entities)
  self:internalStorageSet("entities",entities)
end

HASS.IFmap.sensor_battery='battery'
HASS.IFmap.sensor_energy='energy'

-- Add or remove interfaces from QA depending on entities subscribed to
function HASSChild:checkInterfaces()
  local IFs = {}
  local device = api.get("/devices/"..self.id)
  if not device then return ERRORF("QA %s has no device",self.id) end
  for _,i in ipairs(device.interfaces or {}) do
    IFs[i] = true
  end
  for _,entity in pairs(self.entities) do
    local IF = HASS.IFmap[entity.type]
    if IF then
      if not IFs[IF] then
        self:addInterfaces({IF})
      else IFs[IF] = nil end
    end
  end
  for i,_ in pairs(IFs) do
    if HASS.IFmap[i] then self:removeInterfaces({i}) end
  end
end

function HASSChild:firstEntityId(typ)
  return self.entityTypes[typ] and self.entityTypes[typ][1] or nil
end

function HASSChild:send(entity,cmd,data,cb) -- send command
  if not entity then return WARNINGF("QA %s has no entity",self.id) end
  data = data or {}
  data.entity_id = entity.id
  if not cb then cb = function(r) 
    if not r.success then
      ERRORF("send:%s %s %s",json.encode(data),r.error.code or "",r.error.message or "")
    end
    end
  end
  self.parent.WS:serviceCall(entity.domain,cmd,data,cb)
end

function HASSChild:change(entity)
  self:updateProperty('dead',entity.state == 'unavailable') -- Update dead property
  if entity.state~='unavailable' then -- Don't update if dead, some values may be missing
    local updateType = "update_"..entity.type
    if self[updateType] then self[updateType](self,entity)
    elseif self.update then self:update(entity) end
  end
end

function HASSChild:update_sensor_battery(entity)
  DEBUGF('battery',"'%s' battery:%s%%",self.name,entity.state)
  self:updateProperty('batteryLevel',round(entity.state))
end

function HASSChild:update_sensor_energy(entity)
  DEBUGF('energy',"'%s' energy:%s",self.name,entity.state)
  self:updateProperty('energy',round(entity.state))
end

class 'DimLight'(HASSChild) 
function DimLight:__init(device)
  HASSChild.__init(self, device)
  self.meid = self:firstEntityId('light')
end
function DimLight:update(entity)
  self.meid = entity
  local state,br = entity.state=='on',entity.attributes.brightness
  self.state = state
  self:updateProperty('state',state)
  self:updateProperty('value',state and to100(br) or 0)
end
function DimLight:setValue(v) self:send(self.meid,"turn_on",{brightness = to255(v)}) end
function DimLight:turnOn() self:send(self.meid,"turn_on") end
function DimLight:turnOff() self:send(self.meid,"turn_off") end
function DimLight:toggle() self:send(self.meid,"toggle") end

class 'RGBLight'(DimLight)
function RGBLight:__init(device)
  DimLight.__init(self, device)
  self.meid = self:firstEntityId('light')
end
function RGBLight:setColor(r,g,b,w)
  -- send to HASS and wait for update coming back
  self:send(self.meid,"turn_on",{rgb_color = {r, g, b, w}})
end
function RGBLight:setColorComponents(colorComponents) -- Called by HC3 UI
  DEBUGF('color',"setColorComponents called %s",json.encode(colorComponents))
  if colorComponents.warmWhite and not colorComponents.red then
    DEBUGF('color',"setColorComponents.temp")
    return self:setTemperature(colorComponents.warmWhite) -- 0..255
  end
  local cc = self.properties.colorComponents
  local isColorChanged = false
  for k,v in pairs(colorComponents) do
    if cc[k] and cc[k] ~= v then cc[k]=v isColorChanged = true end
  end
  if isColorChanged == true then
    self:setColor(cc["red"], cc["green"], cc["blue"], cc["white"])
  end
end
function RGBLight:update(entity)
  self.meid = entity
  DimLight.update(self,entity)
  local rgb = entity.attributes.rgb_color
  if not self.state then return end
  if rgb == nil then
    print("ToDo convert xy to rgb")
    return 
  end
  DEBUGF("color","ColorRGBLight %s %s %s",entity.state,entity.attributes.brightness,json.encode(rgb))
  rgb = {red = rgb[1], green = rgb[2], blue = rgb[3], white = rgb[4]}
  local color = string.format("%d,%d,%d,%d", rgb.red or 0, rgb.green or 0, rgb.blue or 0, rgb.white or 0) 
  self:updateProperty('color',color)
  local cc = self.properties.colorComponents
  for k,v in pairs(rgb) do if cc[k] then cc[k] = v end end
  self:updateProperty('colorComponents',cc)
end

class 'XYLight'(RGBLight)
function XYLight:__init(device)
  RGBLight.__init(self, device)
  self.meid = self:firstEntityId('light')
end
function XYLight:setColor(r,g,b,w)
  print("ToDo convert xy to rgb")
  -- local xy = rgbToXy(r,g,b,w)
  -- self:send("turn_on",{entity_id=self._uid, xy = xy})
end

class 'BinarySwitch'(HASSChild) -- Plug looking like light
function BinarySwitch:__init(device)
  HASSChild.__init(self, device)
  self.meid = self:firstEntityId('switch')
end
function BinarySwitch:update(entity)
  self.meid = entity
  self:updateProperty('state',entity.state=='on')
  self:updateProperty('value',entity.state=='on')
end
function BinarySwitch:turnOn() self:send(self.meid,'turn_on') end
function BinarySwitch:turnOff() self:send(self.meid,'turn_off') end
function BinarySwitch:toggle() self:send(self.meid,'toggle') end

class 'BinarySensor'(HASSChild) 
function BinarySensor:__init(device)
  HASSChild.__init(self, device)
end
function BinarySensor:update(entity)
  self.meid = entity
  self:updateProperty('state',entity.state=='on')
  self:updateProperty('value',entity.state=='on')
end

class 'Switch'(HASSChild)
function Switch:__init(device)
  HASSChild.__init(self, device)
  self.meid = self:firstEntityId('switch')
end
function Switch:update(entity)
  self.meid = entity
  self:updateProperty('value',entity.state=='on')
end
function Switch:turnOn() self:send(self.meid,"turn_on") end
function Switch:turnOff() self:send(self.meid,"turn_off") end
function Switch:toggle() self:send(self.meid,"toggle") end

local function toOsTime(str)
  local y,m,day,h,min,s,offs = str:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)(.*)")
  if not y then return 0 end
  local t = os.time({year=y,month=m,day=day,hour=h,min=min,sec=s})
  return os.utc2time(t)
end 

local btnMap = {
  initial_press="Pressed",['rep'..'eat']="HeldDown",short_release="Released",long_press="HeldDown",long_release="Released"
}

class 'Button'(HASSChild)
function Button:__init(device)
  HASSChild.__init(self, device)
end
function Button:logState(entity)
  local eventType = entity.attributes.event_type
  local date = os.date("%Y-%m-%d %H:%M:%S",self.last)
  printf("Button %s (%ss) ev:%s",date,os.time()-self.last,eventType or "")
end
function Button:update(entity)
  self.meid = entity
  self.last = toOsTime(entity.state)
  local t = os.time()-self.last
  self:logState(entity)
  if t <= 1 then self:emitEvent(entity.attributes) end -- ignore older events
end
function Button:emitEvent(attr)
  print("Btn Emit event...")
  local key = 1
  local modifier = btnMap[attr.event_type]
  local data = {
    type =  "centralSceneEvent",
    source = self.id,
    data = { keyAttribute = modifier, keyId = key }
  }
  local a,b = api.post("/plugins/publishEvent", data)
end

class 'Rotary'(Button)
function Rotary:__init(device)
  HASSChild.__init(self, device)
  self.min = self.qvar.min or 0
  self.max = self.qvar.max or 255
  self.step = self.qvar.step or 1
end
function Rotary:logState(entity)
  local a = entity.attributes
  local date = os.date("%Y-%m-%d %H:%M:%S",self.last)
  printf("Rotary %s (%ss) ev:%s ac:%s dur:%s st:%s",
  date, os.time()-self.last, a.event_type or "", a.action or "", a.duration or "", a.steps or "")
end
function Rotary:emitEvent(attr)
  local steps = tonumber(attr.steps)
  --local action = attr.action
  local duration = tonumber(attr.duration)
  local dir = attr.event_type == "clock_wise" and 1 or -1
  local val = fibaro.getValue(self.id,"value")
  val = val + dir*steps
  self:updateProperty('value',round(val))
end

class 'Speaker'(HASSChild)
function Speaker:__init(device)
  HASSChild.__init(self, device)
  self:registerUICallback('favoriteSelector', 'onToggled', 'favoriteSelected')
  self.meid = self:firstEntityId('media_player_speaker')
end
function Speaker:play() self:send(self.meid,"media_play") end
function Speaker:pause() self:send(self.meid,"media_pause") end
function Speaker:stop() self:send(self.meid,"media_stop") end
function Speaker:next() self:send(self.meid,"media_next_track") end
function Speaker:prev() self:send(self.meid,"media_previous_track") end
function Speaker:setVolume(volume) self:send(self.meid,"volume_set",{volume_level = volume/100}) end
function Speaker:setMute(mute)
  self:send(self.meid,"volume_mute",{is_volume_muted = mute==1})
end
function Speaker:logState(entity)
  local a = entity.attributes
  -- media_album_name, media_artist, media_title, media_content_type
  -- media_channel
  printf("Speaker %s vol:%s muted:%s",entity.state,a.volume_level or 0,a.is_volume_muted or false)
end
function Speaker:update_media_player_speaker(entity)
  self.meid = entity
  self:logState(entity)
  local state = entity.state
  local a = entity.attributes
  self:updateView('artistLabel', "text", a.media_artist or "")
  self:updateView('trackLabel', "text", a.media_title or "")
  self:updateView('statusLabel', "text", state)
  --self:updateView('mute_Switch', "value", a.is_volume_muted)
  self:updateProperty("state", state or "off")
  self:updateProperty("mute", a.is_volume_muted or false)
  self:updateProperty("volume", round((a.volume_level or 0)*100))
end
function Speaker:update_sensor_favorites(entity)
  DEBUGF('speaker',"Speaker favorites %s",json.encode(entity.attributes.items or {}))
  self.favoriteList = entity.attributes.items or {}
  local opts = {}
  for i,f in pairs(self.favoriteList) do opts[#opts+1]={text=f,type='option', value=i} end
  self:updateView('favoriteSelector', "options", opts)
end
function Speaker:favoriteSelected(ev)
  local sel = ev.values[1]
  self:send(self.meid,"play_media",{
    media_content_id = sel, media_content_type='favorite_item_id'
  })
end

class 'Motion'(HASSChild)
function Motion:__init(device)
  HASSChild.__init(self, device)
end
function Motion:update(entity)
  self:updateProperty('value',entity.state=='on')
end

class 'Lux'(HASSChild)
local function toLux(value) return 10 ^ ((value - 1) / 10000) end -- Tbd, This is not right!
function Lux:__init(device)
  HASSChild.__init(self, device)
end
function Lux:update(entity)
  self:updateProperty('value',toLux(entity.attributes.light_level or 0))
end

class 'DoorSensor'(HASSChild)
function DoorSensor:__init(device)
  HASSChild.__init(self, device)
end
function DoorSensor:update(entity)
  self:updateProperty('value',entity.state=='on')
end

class 'DoorLock'(HASSChild)
function DoorLock:__init(device)
  HASSChild.__init(self, device)
  self.meid = self:firstEntityId('lock')
end
function DoorLock:update(entity)
  self.meid = entity
  self:updateProperty('secured',entity.state=='locked' and 255 or 0)
end
function DoorLock:secure() self:send(self.meid,"lock") end
function DoorLock:unsecure() self:send(self.meid,"unlock") end

class 'Temperature'(HASSChild)
function Temperature:__init(device)
  HASSChild.__init(self, device)
end
function Temperature:update(entity)
  self:updateProperty('value',tonumber(entity.state) or 0)
end

class 'Humidity'(HASSChild)
function Humidity:__init(device)
  HASSChild.__init(self, device)
end
function Humidity:update(entity)
  self:updateProperty('value',tonumber(entity.state))
end

class 'Pm25'(HASSChild)
function Pm25:__init(device)
  HASSChild.__init(self, device)
end
function Pm25:update(entity)
  self:updateProperty('value',tonumber(entity.state) or 0)
end

class 'Fan'(HASSChild) --TBD
function Fan:__init(device)
  HASSChild.__init(self, device)
  self.meid = self:firstEntityId('fan')
end
function Fan:logState(entity)
  local a = entity.attributes
  printf("Fan %s %s%% dir:%s osc:%s",d.state,a.percentage or 0,a.direction or 0,a.oscillating or 0)
end
function Fan:update(entity)
  self.meid = entity
  self:logState(entity)
  --self:updateProperty('value',tonumber(entity.state))
end

class 'DeviceTracker'(HASSChild) --Binary sensor, ON when home
function DeviceTracker:__init(device) -- Location displayed in log property
  HASSChild.__init(self, device)
end
function DeviceTracker:logState(entity)
  local a = entity.attributes
  printf("DeviceTracker %s",entity.state)
end
function DeviceTracker:update(entity)
  --self:logState(entity)
  self:updateProperty('value',entity.state=='home')
  self:updateProperty('log',entity.state)
end

class 'Cover'(HASSChild) --TBD
function Cover:__init(device)
  HASSChild.__init(self, device)
  self.meid = self:firstEntityId('cover')
end
function Cover:open() self:send(self.meid,"open_cover") end
function Cover:close() self:send(self.meid,"close_cover") end
function Cover:stop()
  local val = fibaro.getValue(self.id,'value')
  self:send(self.meid,"stop_cover")
  self:updateProperty('value',val) -- after stop the QA reports 100% opened??? why?
end
function Cover:setValue(value) -- Value is type of integer (0-99)
  self:send(self.meid,"set_cover_position",{position = value})  
end
function Cover:logState(entity)
  local a = entity.attributes
  printf("Cover %s %s%%",entity.state,a.current_position or 0)
end
function Cover:update(entity)
  self.meid = entity
  self:logState(entity)
  local state = entity.state
  local percentage = entity.attributes.current_position or 0
  local val = percentage or 0
  self:updateProperty('value',val)
end

class 'Thermostat'(HASSChild) --TBD
function Thermostat:__init(device)
  HASSChild.__init(self, device)
  self.meid = self:firstEntityId('climate')
end
function Thermostat:logState(entity)
  local a = entity.attributes
  local pr = string.buff()
  pr.printf("Thermostat %s\n",entity.state)
  pr.printf("  current temperature: %s\n",a.current_temperature or 0)
  pr.printf("  temperature: %s\n",a.temperature or 0)
  pr.printf("  min temperature: %s\n",a.min_temp or 0)
  pr.printf("  min temperature: %s\n",a.min_temp or 0)
  pr.printf("  hvac action %s\n",a.hvac_action or 0)
  pr.printf("  hvac modes %s\n",json.encode(a.hvac_modes or {}))
  pr.printf("  preset mode %s\n",a.preset_mode or 0)
  pr.printf("  preset modes %s\n",json.encode(a.preset_modes or {}))
  print(pr.tostring())
end
function Thermostat:update(entity)
  self.meid = entity
  self:logState(entity)
  local state = entity.state
  local a = entity.attributes
  self:updateProperty("supportedThermostatModes", a.preset_modes or {})
  self:updateProperty('thermostatMode',state)
end
function Thermostat:setThermostatMode(mode)
  self:updateProperty("thermostatMode", mode)
end
-- handle action for setting set point for cooling
function Thermostat:setCoolingThermostatSetpoint(value, unit)
  --self:updateProperty("coolingThermostatSetpoint", { value= value, unit= unit or "C" })
end
-- handle action for setting set point for heating
function Thermostat:setHeatingThermostatSetpoint(value, unit)
  --self:updateProperty("heatingThermostatSetpoint", { value= value, unit= unit or "C" })
end

class 'Calendar'(HASSChild)
function Calendar:__init(device)
  HASSChild.__init(self, device)
end
function Calendar:logState(entity)
  local a = entity.attributes
  local pr = string.buff()
  pr.printf("Calendar %s\n",entity.state)
  pr.printf("  all day: %s\n",a.all_day)
  pr.printf("  start: %s\n",a.start_time)
  pr.printf("  end: %s\n",a.end_time)
  pr.printf("  location: %s\n",a.location or "")
  pr.printf("  description: %s\n",(a.description or "") // 60)
  pr.printf("  message: %s\n",(a.message or "") // 60)
  print(pr.tostring())
end
function Calendar:update(entity)
  self:logState(entity)
  self.qvar.allDay = entity.attributes.all_day
  self.qvar.start = entity.attributes.start_time
  self.qvar['end'] = entity.attributes.end_time
  self.qvar.location = entity.attributes.location
  local descr = entity.attributes.description or ""
  self.qvar.description = descr
  self.qvar.message = entity.attributes.message
  local event,descr,before = descr:match("#(.-);(.-);?([%d:]*)#")
  before = before or ""
  if event then
    self.qvar.event = event
    self.qvar.eventDescr = descr or ""
  end
  if entity.state=='off' and before~="" then
    -- 2025-01-21 18:00:00
    local year,month,day,hour,min = before:match("(%d+)-(%d+)-(%d+) (%d+):(%d+)")
    local t = os.time({year=year,month=month,day=day,hour=hour,min=min,sec=0})
    if self.timer then clearTimeout(self.timer) end
    self.timer = setTimeout(function()
      self.timer = nil
      self:publishEvent(event,descr) end,
      (t-os.time())*1000
    )
    -- timer for event
  elseif entity.state=='on' and before=="" then
    self:publishEvent(event,descr)
  end
  self:updateProperty('value',entity.state=='on')
end
function Calendar:publishEvent(name,descr)
  api.post("/customEvent",{name=name,descr=descr})
  api.post("/customEvent/"..name)
end
