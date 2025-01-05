---@diagnostic disable: undefined-global
HASS = HASS or {}
local function member(t,v)
  for _,m in ipairs(t) do if m == v then return true end end
end

-- Supported HASS types and initial QA config values
local deviceTypes = {}

function deviceTypes.light(d,e)
  -- depening on capabilities we may want to create different fibaro types...
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
class 'HASSChild'(QwikAppChild)
function HASSChild:__init(device) 
  QwikAppChild.__init(self, device)
  self._initData = HASS.children[self._uid]
  self.url = self._initData
  self:delayProp('dead',self._initData.hass.state == 'unavailable')
end
function HASSChild:delayProp(name,value) 
  -- Need to delay the setting of the property because device not created yet...
  setTimeout(function() self:updateProperty(name,value) end, 0)
end
function HASSChild:change(new,old)
  self:updateProperty('dead',new.state == 'unavailable')
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
  POST("/services/light/turn_on",{entity_id=self._uid, brightness = v})
end

function Light:turnOn()
  POST("/services/light/turn_on",{entity_id=self._uid})
end
function Light:turnOff()
  POST("/services/light/turn_off",{entity_id=self._uid})
end

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
function BinarySwitch:turnOn()
  POST("/services/light/turn_on",{entity_id=self._uid})
end
function BinarySwitch:turnOff()
  POST("/services/light/turn_off",{entity_id=self._uid})
end

class 'Switch'(HASSChild)
function Switch:__init(device) 
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  self:delayProp('value',state=='on')
end
function Switch:update(new,old)
  printf(self._uid,new.state=='on')
end

class 'Button'(HASSChild)
function Button:__init(device) 
  HASSChild.__init(self, device)
end 

class 'Speaker'(HASSChild)
function Speaker:__init(device) 
  HASSChild.__init(self, device)
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

class 'Temperature'(HASSChild)
function Temperature:__init(device) 
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  self:delayProp('value',tonumber(state))
end
function Temperature:update(new,old)
  self:updateProperty('value',tonumber(new.state))
end
