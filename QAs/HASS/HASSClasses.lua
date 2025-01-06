---@diagnostic disable: undefined-global
HASS = HASS or {} -- Table to stire "global" HASS functions and data
local function member(t,v)
  for _,m in ipairs(t) do if m == v then return true end end
end

-- Supported HASS types and initial QA config values
local deviceTypes = {}

function deviceTypes.light(d,e)
  -- depending on capabilities we may want to create different fibaro types...
  local attr = e.attributes.supported_color_modes or {}
  if #attr == 0 then
     fibaro.warning(__TAG,"No attributes.supported_color_modes for",e.entity_id)
     return
  end
  if #attr == 1 and attr[1] == "onoff" then
    d.type = "com.fibaro.binarySwitch"
    d.className = "BinarySwitch"
  elseif member(attr,"brightness") then
    d.type = "com.fibaro.multilevelSwitch"
    d.className = "Light"
  else
    fibaro.warning(__TAG,"Unsupported attributes.supported_color_modes for ",
    e.entity_id,
    table.concat(attr,",")
  )
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

function deviceTypes.button(d,e)
  d.type = "com.fibaro.remoteController"
  d.className = "Button"
  return d
end

function deviceTypes.speaker(d,e)
  d.type = "com.fibaro.speaker"
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

------------------------------------------------------
--- QuickApp classes for HASS devices ----------------
------------------------------------------------------

-- Base class for HASS devices
class 'HASSChild'(QwikAppChild)
function HASSChild:__init(device)
  QwikAppChild.__init(self, device)
  self.uid = self._uid
  self.domain = self.uid:match("^(.-)%.")
  self._initData = HASS.children[self.uid]
  self.url = self._initData
  self:delayProp('dead',self._initData.hass.state == 'unavailable')
end
function HASSChild:send(cmd,data,cb) -- send command
  self.parent.WS:serviceCall(self.domain,cmd,data,cb)
end
function HASSChild:delayProp(name,value)
  -- Need to delay the setting of the property because device not created yet...
  setTimeout(function() self:updateProperty(name,value) end, 0)
end
function HASSChild:change(new,old)
  self:updateProperty('dead',new.state == 'unavailable') -- Update dead property
  if self.update then self:update(new,old) end
end

class 'Light'(HASSChild)
function Light:__init(device)
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  local attr = self._initData.hass.attributes
  self:delayProp('state',state=='on')
  self:delayProp('value',attr.brightness or 0)
end
function Light:update(new,old)
  self:updateProperty('state',new.state=='on')
  self:updateProperty('value',new.attributes.brightness or new.state=='on' or false)
end
function Light:setValue(v)
  self:send("turn_on",{entity_id=self._uid, brightness = v})
end
function Light:turnOn() self:send("turn_on",{entity_id=self._uid}) end
function Light:turnOff() self:send("turn_off",{entity_id=self._uid}) end
function Light:toggle() self:send("toggle",{entity_id=self._uid}) end

class 'BinarySwitch'(HASSChild) -- Plug looking like light
function BinarySwitch:__init(device)
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  self:delayProp('state',state=='on')
  self:delayProp('value',state=='on')
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
  local state = self._initData.hass.state
  self:delayProp('state',state=='on')
  self:delayProp('value',state=='on')
end
function BinarySensor:update(new,old)
  self:updateProperty('state',new.state=='on')
  self:updateProperty('value',new.state=='on')
end

class 'Switch'(HASSChild)
function Switch:__init(device)
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  self:delayProp('value',state=='on')
end
function Switch:update(new,old)
  self:updateProperty('value',new.state=='on')
end
function Switch:turnOn() self:send("turn_on", {entity_id=self.entity_id}) end
function Switch:turnOff() self:send("turn_off", {entity_id=self.entity_id}) end
function Switch:toggle() self:send("toggle", {entity_id=self.entity_id}) end

class 'Button'(HASSChild)
function Button:__init(device)
  HASSChild.__init(self, device)
end
function Button:update(new,old)
  printf(self._uid,json.encode(new)) -- TBD
end

class 'Speaker'(HASSChild)
function Speaker:__init(device)
  HASSChild.__init(self, device)
end
function Speaker:update(new,old)
  printf(self._uid,json.encode(new)) -- TBD
end

class 'Motion'(HASSChild)
function Motion:__init(device)
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  self:delayProp('value',state=='on')
end
function Motion:update(new,old)
  self:updateProperty('value',new.state=='on')
end

class 'Illuminance'(HASSChild)
local function toLux(value) return 10 ^ ((value - 1) / 10000) end
function Illuminance:__init(device)
  HASSChild.__init(self, device)
  local level = self._initData.hass.attributes.light_level
  local lux = toLux(level)
  --print(lux) --What is the lux value????
  self:delayProp('value',lux)
end
function Illuminance:update(new,old)
  self:updateProperty('value',toLux(new.attributes.light_level))
end

class 'DoorSensor'(HASSChild)
function DoorSensor:__init(device)
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  self:delayProp('value',state=='on')
end
function DoorSensor:update(new,old)
  self:updateProperty('value',new.state=='on')
end

class 'DoorLock'(HASSChild)
function DoorLock:__init(device)
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  self:delayProp('secured',state=='locked' and 255 or 0)
end
function DoorLock:update(new,old)
  self:updateProperty('secured',new.state=='locked' and 255 or 0)
end
function DoorLock:secure() self:send("lock", {entity_id=self._uid}) end
function DoorLock:unsecure() self:send("unlock", {entity_id=self._uid}) end

class 'Temperature'(HASSChild)
function Temperature:__init(device)
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  self:delayProp('value',tonumber(state))
end
function Temperature:update(new,old)
  self:updateProperty('value',tonumber(new.state))
end

class 'Humidity'(HASSChild)
function Humidity:__init(device)
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  self:delayProp('value',tonumber(state))
end
function Humidity:update(new,old)
  self:updateProperty('value',tonumber(new.state))
end

class 'Pm25'(HASSChild)
function Pm25:__init(device)
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  self:delayProp('value',tonumber(state))
end
function Pm25:update(new,old)
  self:updateProperty('value',tonumber(new.state))
end

class 'Fan'(HASSChild) --TBD
function Fan:__init(device)
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  self:logState(self._initData.hass)
  --self:delayProp('value',tonumber(state))
end
function Fan:logState(d)
  local a = d.attributes
  printf("Fan %s %s%% dir:%s osc:%s",d.state,a.percentage,a.direction,a.oscillating)
end
function Fan:update(new,old)
  self:logState(new)
  --self:updateProperty('value',tonumber(new.state))
end

class 'Cover'(HASSChild) --TBD
function Cover:__init(device)
  HASSChild.__init(self, device)
  local d = self._initData.hass
  self:logState(d)
  local state = d.state
  local percentage = d.attributes.current_position or 0
  local val = state=='open' and 99 or state=='closed' and 0 or percentage
  self:delayProp('value',val)
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
  local val = state=='open' and 100 or state=='closed' and 0 or percentage
  self:updateProperty('value',val)
end