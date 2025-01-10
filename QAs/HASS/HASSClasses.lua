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
HASS = HASS or {} -- Table to stire "global" HASS functions and data
local fmt = string.format
local function round(v) return math.floor(v+0.5) end
local function to100(v) return math.floor((v/255.0)*100+0.5) end
local function to255(v) return math.floor((v/100.0)*255+0.5) end

-- Supported HASS types and initial QA config values
local deviceTypes = {}

function deviceTypes.light(d,e)
  -- depending on capabilities we may want to create different fibaro types...
  local attr = e.attributes
  local support = {}
  for _,a in ipairs(attr.supported_color_modes or {}) do support[a] = true end
  if attr.rgb_color then --or support.xy then
    d.type = "com.fibaro.colorController"
    d.className = "ColorRGBLight"
    d.properties = {colorComponents = {red=0,green=0,blue=0,warmWhite=0}}
    d.interfaces = {"ringColor","colorTemperature"}
  elseif support.xy then --or support.xy then
    d.type = "com.fibaro.colorController"
    d.className = "ColorXYLight"
    d.properties = {colorComponents = {red=0,green=0,blue=0,warmWhite=0}}
    d.interfaces = {"ringColor","colorTemperature"}
  elseif attr.brightness or support.brightness then
    d.type = "com.fibaro.multilevelSwitch"
    d.className = "DimLight"
  elseif support.onoff then -- plug
    d.type = "com.fibaro.binarySwitch"
    d.className = "BinarySwitch"
  else
    WARNINGF("Unsupported attributes.supported_color_modes for %s %s",
    e.entity_id,
    table.concat(attr.supported_color_modes or {},",")
    )
    return nil
  end
  return d
end

function deviceTypes.switch(d,e)
  d.type = "com.fibaro.binarySwitch"
  d.className = "Switch"
  d.properties = {}
  d.interfaces = {}
  return d
end

function deviceTypes.temperature(d,e)
  d.type = "com.fibaro.temperatureSensor"
  d.className = "Temperature"
  return d
end

function deviceTypes.illuminance(d,e)
  d.type = "com.fibaro.lightSensor"
  d.className = "Illuminance"
  return d
end

local buttonEvs = {'initial_press','repeat','short_release','long_press','long_release'}
local rotaryEvs = {'clock_wise','counter_clock_wise'}
function deviceTypes.button(d,e)
  local attr = e.attributes
  if table.equal(attr.event_types,rotaryEvs) then
    d.type = "com.fibaro.multilevelSensor"
    d.className = "Rotary"
  elseif table.equal(attr.event_types,buttonEvs) then
    d.type = "com.fibaro.remoteController"
    d.className = "Button"
    d.properties = {
      centralSceneSupport = {
        { keyAttributes = {"Pressed","Released","HeldDown","Pressed2","Pressed3"},keyId = 1 },
      }
    }
    d.interfaces={"zwaveCentralScene"}
  else
    WARNINGF("Unsupported event_types for %s %s",e.entity_id,table.concat(attr.event_types or {},","))
    return nil
  end
  return d
end

function deviceTypes.speaker(d,e)
  d.type = "com.fibaro.sonosSpeaker"
  d.className = "Speaker"
  return d
end

function deviceTypes.motion(d,e)
  d.type = "com.fibaro.motionSensor"
  d.className = "Motion"
  return d
end

function deviceTypes.opening(d,e)
  d.type = "com.fibaro.doorSensor"
  d.className = "DoorSensor"
  return d
end

function deviceTypes.binary_sensor(d,e)
  d.type = "com.fibaro.binarySensor"
  d.className = "BinarySensor"
  return d
end

function deviceTypes.humidity(d,e)
  d.type = "com.fibaro.humiditySensor"
  d.className = "Humidity"
  return d
end

function deviceTypes.pm25(d,e)
  d.type = "com.fibaro.multilevelSensor"
  d.className = "Pm25"
  d.properties = {unit = " "..(e.attributes.unit_of_measurement or "µg/m³")}
  return d
end

function deviceTypes.lock(d,e)
  d.type = "com.fibaro.doorLock"
  d.className = "DoorLock"
  return d
end

function deviceTypes.fan(d,e)
  d.type = "com.fibaro.genericDevice"
  d.className = "Fan"
  return d
end

function deviceTypes.cover(d,e)
  d.type = "com.fibaro.rollerShutter"
  d.className = "Cover"
  return d
end

function deviceTypes.device_tracker(d,e)
  d.type = "com.fibaro.binarySensor"
  d.className = "DeviceTracker"
  return d
end

function deviceTypes.calendar(d,e)
  d.type = "com.fibaro.binarySensor"
  d.className = "Calendar"
  return d
end

function deviceTypes.climate(d,e)
  -- com.fibaro.hvacSystemAuto
  -- com.fibaro.hvacSystemHeat
  -- com.fibaro.hvacSystemCool
  -- com.fibaro.coolAutomationHvac
  d.type = "com.fibaro.hvacSystemAuto"
  d.className = "Thermostat"
  return d
end

-- Returns child init data for a HASS device
function HASS.childData(e)
  local typ,data = e.type,e.data
  local d = {
    name = e.data.attributes.friendly_name or e.entity_id or "Unknown",
    hass = data,
  }
  if deviceTypes[typ] then return deviceTypes[typ](d,data) end
end
HASS.deviceTypes = deviceTypes

---------------- HASS device addons ----------------
--- batter, power, energy, etc. -------------------
local addons = {}
-- categories: battery, power, voltage, current, energy
local batteries,energy,power = {},{},{}
class 'AddOn'
function AddOn:__init(e,prop)
  self.entity_id = e.entity_id
  self.state = e.state
  self.prop = prop
  self.attributes = e.attributes
  self.subscribers = {}
end
function AddOn:subscriber(uid)
  self.subscribers[uid] = true
end
function AddOn:update(new)
  self.state = new.state
  for c,_ in pairs(self.subscribers) do c:updateAddOn(self.prop,self.state,new.attributes) end
end
function AddOn:__tostring()
  return fmt("%s %s %s",self.prop,self.entity_id,self.state)
end
class 'Favo'(AddOn)
function Favo:__init(e,prop) AddOn.__init(self,e,prop) end
function Favo:update(new)
  for c,_ in pairs(self.subscribers) do 
    if c.setFavorites then c:setFavorites(new.attributes.items) end
  end
end

local AD = {}
function AD.battery(e) addons[e.entity_id] = AddOn(e,"batteryLevel") end
function AD.power(e) addons[e.entity_id] = AddOn(e,"power") end
function AD.energy(e) addons[e.entity_id] = AddOn(e,"energy") end
function AD.current(e) addons[e.entity_id] = AddOn(e,"current") end
function AD.voltage(e) addons[e.entity_id] = AddOn(e,"voltage") end
AD['sensor.sonos_favorites'] = function(e) addons[e.entity_id] = Favo(e,"sonos_favorites") end
HASS.deviceAddons = AD

local addonsNames = {'battery','power','energy','current','voltage','favorites'}
function HASS.resolveAddons()
  for _,c in pairs(quickApp.childDevices) do
    for _,addon in ipairs(addonsNames) do
      if c[addon] then
        if not addons[c[addon]] then
          WARNINGF("AddOn %s not found for %s",c[addon],c.uid)
        else
          addons[c[addon]]:subscriber(c)
        end
      end
    end
  end
  for _,b in pairs(addons) do b:update(b) end
end

function HASS.dumpAddons()
  local pr = string.buff({"\n"})
  local function dump(title,prop)
    local t = {}
    for k,a in pairs(addons) do 
      if a.prop==prop then t[#t+1] = k end
    end
    table.sort(t)
    pr.printf("\n%s:\n-%s",title,table.concat(t,"\n-"))
  end
  pr.printf("Addons:")
  dump("Battery","batteryLevel")
  dump("Power","power")
  dump("Energy","energy")
  dump("Current","current")
  dump("Voltage","voltage")
  print(pr.tostring())
end

-----------------------------------------------------
HASS.customEntity = {} -- Custom entity types
--[[
HASS.customEntity = {[my_entity_id] = "my_type"}
function HASS.deviceTypes.my_type(d,e)
  d.type = "com.fibaro.specialType"
  d.className = "MySpecialTypClass"
  return d
end
Alt. if my_entity_id is a light but not recognized by domain/device_category
HASS.customEntity = {[my_entity_id] = "light"}
--]]
------------------------------------------------------
--- QuickApp classes for HASS devices ----------------
------------------------------------------------------
--[[
  The general flow is that the HASS devices sends events to the 
  child QA, and the child QA updates it's properties accordingly.
  Ex. If a HASS binary switch is turned on it sends a state_changed
  event to the child QA with state=='on' and the child QA updates
  it's state property to true.
  When the child QA is turned on (self:turnOn()), we send the state change
  to the HASS device, and we wait for the update back from the HASS device.
  Alt. we could update the child QA state property directly, and wait for the
  HASS update to verify that. At the moment we don't.
--]]
-- Base class for HASS devices
class 'HASSChild'(QwikAppChild)
function HASSChild:__init(device)
  QwikAppChild.__init(self, device)
  quickApp.childDevices[self.id] = self -- Hack to get the child devices reged.
  self.uid = self._uid
  self.domain = self.uid:match("^(.-)%.")
  self._initData = HASS.children[self.uid]
  self.url = self._initData
  -- Check if interfaces defined with quickVars, and add/remove accordingly
  for _,i in ipairs({'battery','power','energy'}) do
    local hasIF = self:hasInterface(i)
    if not self[i] and hasIF then
      DEBUGF("child","Removing %s interface from %s",i,self.uid)
      self:deleteInterfaces({i})
    elseif self[i] and not hasIF then
      DEBUGF("child","Adding %s interface to %s",i,self.uid)
      self:addInterfaces({i})
    end
  end
  self:updateProperty('dead',self._initData.hass.state == 'unavailable')
end
function HASSChild:send(cmd,data,cb) -- send command
  self.parent.WS:serviceCall(self.domain,cmd,data,cb)
end
function HASSChild:updateAddOn(prop,value,attr)
  if tonumber(value) then value = math.floor(tonumber(value)+0.5) end
  self:updateProperty(prop,value) 
end
function HASSChild:change(new,old)
  self:updateProperty('dead',new.state == 'unavailable') -- Update dead property
  if new.state~='unavailable' then -- Don't update if dead, some values may be missing
    if self.update then self:update(new,old) end
  end
end

class 'DimLight'(HASSChild) 
function DimLight:__init(device)
  HASSChild.__init(self, device)
  self:update(self._initData.hass)
end
function DimLight:update(new,old)
  local state,br = new.state=='on',new.attributes.brightness
  self.state = state
  self:updateProperty('state',state)
  self:updateProperty('value',state and to100(br) or 0)
end
function DimLight:setValue(v)
  self:send("turn_on",{entity_id=self._uid, brightness = to255(v)})
end
function DimLight:turnOn() self:send("turn_on",{entity_id=self._uid}) end
function DimLight:turnOff() self:send("turn_off",{entity_id=self._uid}) end
function DimLight:toggle() self:send("toggle",{entity_id=self._uid}) end

class 'ColorRGBLight'(DimLight)
function ColorRGBLight:__init(device)
  DimLight.__init(self, device)
  self:update(self._initData.hass)
end
function ColorRGBLight:setColor(r,g,b,w)
  -- send to HASS and wait for update coming back
  self:send("turn_on",{entity_id=self._uid, rgb_color = {r, g, b, w}})
end
function ColorRGBLight:setColorComponents(colorComponents) -- Called by HC3 UI
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
function ColorRGBLight:update(new,old)
  DimLight.update(self,new,old)
  local rgb = new.attributes.rgb_color
  if not self.state then return end
  if rgb == nil then
    print("ToDo convert xy to rgb")
    return 
  end
  DEBUGF("color","ColorRGBLight %s %s %s",new.state,new.attributes.brightness,json.encode(rgb))
  rgb = {red = rgb[1], green = rgb[2], blue = rgb[3], white = rgb[4]}
  local color = string.format("%d,%d,%d,%d", rgb.red or 0, rgb.green or 0, rgb.blue or 0, rgb.white or 0) 
  self:updateProperty('color',color)
  local cc = self.properties.colorComponents
  for k,v in pairs(rgb) do if cc[k] then cc[k] = v end end
  self:updateProperty('colorComponents',cc)
end

class 'ColorXYLight'(ColorRGBLight)
function ColorXYLight:__init(device)
  ColorRGBLight.__init(self, device)
end
function ColorXYLight:setColor(r,g,b,w)
  print("ToDo convert xy to rgb")
  -- local xy = rgbToXy(r,g,b,w)
  -- self:send("turn_on",{entity_id=self._uid, xy = xy})
end

class 'BinarySwitch'(HASSChild) -- Plug looking like light
function BinarySwitch:__init(device)
  HASSChild.__init(self, device)
  self:update(self._initData.hass)
end
function BinarySwitch:update(new,old)
  self:updateProperty('state',new.state=='on')
  self:updateProperty('value',new.state=='on')
end
function BinarySwitch:turnOn() self:send('turn_on',{entity_id=self._uid}) end
function BinarySwitch:turnOff() self:send('turn_off',{entity_id=self._uid}) end
function BinarySwitch:toggle() self:send('toggle',{entity_id=self._uid}) end

class 'BinarySensor'(HASSChild) 
function BinarySensor:__init(device)
  HASSChild.__init(self, device)
  self:update(self._initData.hass)
end
function BinarySensor:update(new,old)
  self:updateProperty('state',new.state=='on')
  self:updateProperty('value',new.state=='on')
end

class 'Switch'(HASSChild)
function Switch:__init(device)
  HASSChild.__init(self, device)
  self:update(self._initData.hass.state)
end
function Switch:update(new,old)
  self:updateProperty('value',new.state=='on')
end
function Switch:turnOn() self:send("turn_on", {entity_id=self.entity_id}) end
function Switch:turnOff() self:send("turn_off", {entity_id=self.entity_id}) end
function Switch:toggle() self:send("toggle", {entity_id=self.entity_id}) end

local function toOsTime(str)
  local y,m,day,h,min,s,offs = str:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)(.*)")
  local t = os.time({year=y,month=m,day=day,hour=h,min=min,sec=s})
  return os.utc2time(t)
end 

local btnMap = {initial_press="Pressed",['repeat']="HeldDown",short_release="Released",long_press="HeldDown",long_release="Released"}

class 'Button'(HASSChild)
function Button:__init(device)
  HASSChild.__init(self, device)
  self:update(self._initData.hass)
end
function Button:logState(d)
  local eventType = d.attributes.event_type
  local date = os.date("%Y-%m-%d %H:%M:%S",self.last)
  printf("Button %s (%s) ev:%s",date,os.time()-self.last,eventType or "")
end
function Button:update(new,old)
  self.last = toOsTime(new.state)
  local t = os.time()-self.last
  self:logState(new)
  if t <= 1 then self:emitEvent(new.attributes) end
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
  self:update(self._initData.hass)
end
function Rotary:logState(d)
  local a = d.attributes
  local date = os.date("%Y-%m-%d %H:%M:%S",self.last)
  printf("Rotary %s (%s) ev:%s ac:%s dur:%s st:%s",
    date, os.time()-self.last, a.event_type or "", a.action or "", a.duration or "", a.steps or "")
end
function Rotary:emitEvent(attr)
  print("Rotary Emit event...")
end

class 'Speaker'(HASSChild)
function Speaker:__init(device)
  HASSChild.__init(self, device)
  self.favorites = self.qvar.favorites or "sensor.sonos_favorites"
  self:update(self._initData.hass)
end
function Speaker:play()
  self:send("media_play",{entity_id=self._uid}) 
end
function Speaker:pause() self:send("media_pause",{entity_id=self._uid}) end
function Speaker:stop() self:send("media_stop",{entity_id=self._uid}) end
function Speaker:next() self:send("media_next_track",{entity_id=self._uid}) end
function Speaker:prev() self:send("media_previous_track",{entity_id=self._uid}) end
function Speaker:setVolume(volume) 
  self:send("volume_set",{entity_id=self._uid, volume_level = volume/100})
end
function Speaker:setMute(mute)
  self:send("volume_mute",{entity_id=self._uid, is_volume_muted = mute==1})
end
function Speaker:logState(d)
  local a = d.attributes
  -- media_album_name, media_artist, media_title, media_content_type
  -- media_channel
  printf("Speaker %s vol:%s muted:%s",d.state,a.volume_level,a.is_volume_muted)
end
function Speaker:setFavorites(favorites)
  self.favoriteList = favorites
end
function Speaker:update(new,old)
  self:logState(new)
  local state = new.state
  local a = new.attributes
  if a.media_position and a.media_position > 0 then
    self:updateView('position_Label', "text",tostring(a.media_position))
    self:updateView('title_Label', "text", state)
  else
    self:updateView('creator_Label', "Online radio")
    self:updateView('title_Label', "")
  end
  self:updateView('creator_Label', "text", a.media_artist or "")
  self:updateView('mute_Switch', "value", a.is_volume_muted)
  self:updateProperty("state", state)
  self:updateProperty("mute", a.is_volume_muted)
  self:updateProperty("volume", round((a.volume_level or 0)*100))
end

class 'Motion'(HASSChild)
function Motion:__init(device)
  HASSChild.__init(self, device)
  self:update(self._initData.hass)
end
function Motion:update(new,old)
  self:updateProperty('value',new.state=='on')
end

class 'Illuminance'(HASSChild)
local function toLux(value) return 10 ^ ((value - 1) / 10000) end -- Tbd, This is not right!
function Illuminance:__init(device)
  HASSChild.__init(self, device)
  self:update(self._initData.hass)
end
function Illuminance:update(new,old)
  self:updateProperty('value',toLux(new.attributes.light_level))
end

class 'DoorSensor'(HASSChild)
function DoorSensor:__init(device)
  HASSChild.__init(self, device)
  self:update(self._initData.hass)
end
function DoorSensor:update(new,old)
  self:updateProperty('value',new.state=='on')
end

class 'DoorLock'(HASSChild)
function DoorLock:__init(device)
  HASSChild.__init(self, device)
  self:update(self._initData.hass)
end
function DoorLock:update(new,old)
  self:updateProperty('secured',new.state=='locked' and 255 or 0)
end
function DoorLock:secure() self:send("lock", {entity_id=self._uid}) end
function DoorLock:unsecure() self:send("unlock", {entity_id=self._uid}) end

class 'Temperature'(HASSChild)
function Temperature:__init(device)
  HASSChild.__init(self, device)
  self:update(self._initData.hass)
end
function Temperature:update(new,old)
  self:updateProperty('value',tonumber(new.state))
end

class 'Humidity'(HASSChild)
function Humidity:__init(device)
  HASSChild.__init(self, device)
  self:update(self._initData.hass)
end
function Humidity:update(new,old)
  self:updateProperty('value',tonumber(new.state))
end

class 'Pm25'(HASSChild)
function Pm25:__init(device)
  HASSChild.__init(self, device)
  self:update(self._initData.hass)
end
function Pm25:update(new,old)
  self:updateProperty('value',tonumber(new.state))
end

class 'Fan'(HASSChild) --TBD
function Fan:__init(device)
  HASSChild.__init(self, device)
  self:update(self._initData.hass)
end
function Fan:logState(d)
  local a = d.attributes
  printf("Fan %s %s%% dir:%s osc:%s",d.state,a.percentage,a.direction,a.oscillating)
end
function Fan:update(new,old)
  self:logState(new)
  --self:updateProperty('value',tonumber(new.state))
end

class 'DeviceTracker'(HASSChild) --Binary sensor, ON when home
function DeviceTracker:__init(device) -- Location displayed in log property
  HASSChild.__init(self, device)
  self:update(self._initData.hass)
end
function DeviceTracker:logState(d)
  local a = d.attributes
  printf("DeviceTracker %s",d.state)
end
function DeviceTracker:update(new,old)
  --self:logState(new)
  self:updateProperty('value',new.state=='home')
  self:updateProperty('log',new.state)
end


class 'Cover'(HASSChild) --TBD
function Cover:__init(device)
  HASSChild.__init(self, device)
  self:update(self._initData.hass)
end
function Cover:open() self:send("open_cover",{entity_id=self._uid}) end
function Cover:close() self:send("close_cover",{entity_id=self._uid}) end
function Cover:stop()
  local val = fibaro.getValue(self.id,'value')
  self:send("stop_cover",{entity_id=self._uid})
  self:updateProperty('value',val) -- after stop the QA reports 100% opened??? why?
end
function Cover:setValue(value) -- Value is type of integer (0-99)
  self:send("set_cover_position",{entity_id=self._uid, position = value})  
end
function Cover:logState(d)
  local a = d.attributes
  printf("Cover %s %s%%",d.state,a.current_position)
end
function Cover:update(new,old)
  self:logState(new)
  local state = new.state
  local percentage = new.attributes.current_position or 0
  local val = percentage
  self:updateProperty('value',val)
end

class 'Thermostat'(HASSChild) --TBD
function Thermostat:__init(device)
  HASSChild.__init(self, device)
  self:update(self._initData.hass)
end
function Thermostat:logState(d)
  local a = d.attributes
  local pr = string.buff()
  pr.printf("Thermostat %s\n",d.state)
  pr.printf("  current temperature: %s\n",a.current_temperature)
  pr.printf("  temperature: %s\n",a.temperature)
  pr.printf("  min temperature: %s\n",a.min_temp)
  pr.printf("  min temperature: %s\n",a.min_temp)
  pr.printf("  hvac action %s\n",a.hvac_action)
  pr.printf("  hvac modes %s\n",json.encode(a.hvac_modes))
  pr.printf("  preset mode %s\n",a.preset_mode)
  pr.printf("  preset modes %s\n",json.encode(a.preset_modes))
  print(pr.tostring())
end
function Thermostat:update(new,old)
  self:logState(new)
  local state = new.state
  local a = new.attributes
  self:updateProperty("supportedThermostatModes", a.preset_modes)
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
  self:update(self._initData.hass)
end
function Calendar:logState(d)
  local a = d.attributes
  local pr = string.buff()
  pr.printf("Calendar %s\n",d.state)
  pr.printf("  all day: %s\n",a.all_day)
  pr.printf("  start: %s\n",a.start_time)
  pr.printf("  end: %s\n",a.end_time)
  pr.printf("  location: %s\n",a.location or "")
  pr.printf("  description: %s\n",(a.description or "") // 60)
  pr.printf("  message: %s\n",(a.message or "") // 60)
  print(pr.tostring())
end
function Calendar:update(new,old)
  self:logState(new)
  self.qvar.allDay = new.attributes.all_day
  self.qvar.start = new.attributes.start_time
  self.qvar['end'] = new.attributes.end_time
  self.qvar.location = new.attributes.location
  local descr = new.attributes.description or ""
  self.qvar.description = descr
  self.qvar.message = new.attributes.message
  local event,descr,before = descr:match("#(.-);(.-);?([%d:]*)#")
  before = before or ""
  if event then
    self.qvar.event = event
    self.qvar.eventDescr = descr or ""
  end
  if new.state=='off' and before~="" then
    -- 2025-01-21 18:00:00
    local year,month,day,hour,min = before:match("(%d+)-(%d+)-(%d+) (%d+):(%d+)")
    local t = os.time({year=year,month=month,day=day,hour=hour,min=min,sec=0})
    if self.timer then clearTimeout(self.timer) end
    self.timer = setTimeout(function()
      self.timer = nil
      self:publishEvent(event,descr) end,
      (t-os.time())*1000)
    -- timer for event
  elseif new.state=='on' and before=="" then
    self:publishEvent(event,descr)
  end
  self:updateProperty('value',new.state=='on')
end
function Calendar:publishEvent(name,descr)
  api.post("/customEvent",{name=name,descr=descr})
  api.post("/customEvent/"..name)
end