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

function deviceTypes.device_tracker(d,e)
  d.type = "com.fibaro.binarySensor"
  d.className = "DeviceTracker"
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
  for c,_ in pairs(self.subscribers) do c:updateAddOn(self.prop,self.state) end
end
function AddOn:__tostring()
  return fmt("%s %s %s",self.prop,self.entity_id,self.state)
end
local AD = {}
function AD.battery(e) addons[e.entity_id] = AddOn(e,"batteryLevel") end
function AD.power(e) addons[e.entity_id] = AddOn(e,"power") end
function AD.energy(e) addons[e.entity_id] = AddOn(e,"energy") end
function AD.current(e) addons[e.entity_id] = AddOn(e,"current") end
function AD.voltage(e) addons[e.entity_id] = AddOn(e,"voltage") end
HASS.deviceAddons = AD

function HASS.resolveAddons()
  for _,c in pairs(quickApp.childDevices) do
    if c.battery then
      if not addons[c.battery] then
        fibaro.warning(__TAG,fmt("Battery %s not found for %s",c.battery,c.uid))
      else
        addons[c.battery]:subscriber(c)
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
------------------------------------------------------
--- QuickApp classes for HASS devices ----------------
------------------------------------------------------

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
function HASSChild:updateAddOn(prop,value)
  if tonumber(value) then value = math.floor(tonumber(value)+0.5) end
  self:updateProperty(prop,value) 
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
  self:updateProperty('state',state=='on')
  self:updateProperty('value',attr.brightness or 0)
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
  self:updateProperty('state',state=='on')
  self:updateProperty('value',state=='on')
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
  self:updateProperty('state',state=='on')
  self:updateProperty('value',state=='on')
end
function BinarySensor:update(new,old)
  self:updateProperty('state',new.state=='on')
  self:updateProperty('value',new.state=='on')
end

class 'Switch'(HASSChild)
function Switch:__init(device)
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  self:updateProperty('value',state=='on')
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
  self:updateProperty('value',state=='on')
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
  self:updateProperty('value',lux)
end
function Illuminance:update(new,old)
  self:updateProperty('value',toLux(new.attributes.light_level))
end

class 'DoorSensor'(HASSChild)
function DoorSensor:__init(device)
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  self:updateProperty('value',state=='on')
end
function DoorSensor:update(new,old)
  self:updateProperty('value',new.state=='on')
end

class 'DoorLock'(HASSChild)
function DoorLock:__init(device)
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  self:updateProperty('secured',state=='locked' and 255 or 0)
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
  self:updateProperty('value',tonumber(state))
end
function Temperature:update(new,old)
  self:updateProperty('value',tonumber(new.state))
end

class 'Humidity'(HASSChild)
function Humidity:__init(device)
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  self:updateProperty('value',tonumber(state))
end
function Humidity:update(new,old)
  self:updateProperty('value',tonumber(new.state))
end

class 'Pm25'(HASSChild)
function Pm25:__init(device)
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  self:updateProperty('value',tonumber(state))
end
function Pm25:update(new,old)
  self:updateProperty('value',tonumber(new.state))
end

class 'Fan'(HASSChild) --TBD
function Fan:__init(device)
  HASSChild.__init(self, device)
  local state = self._initData.hass.state
  self:logState(self._initData.hass)
  --self:updateProperty('value',tonumber(state))
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
  local state = self._initData.hass.state
  --self:logState(self._initData.hass)
  self:updateProperty('value',state=='home')
  self:updateProperty('log',state)
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
  local d = self._initData.hass
  self:logState(d)
  local state = d.state
  local percentage = d.attributes.current_position or 0
  local val = state=='open' and 99 or state=='closed' and 0 or percentage
  self:updateProperty('value',val)
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

class 'Thermostat'(HASSChild) --TBD
function Thermostat:__init(device)
  HASSChild.__init(self, device)
  local d = self._initData.hass
  local a = d.attributes
  self:updateProperty("supportedThermostatModes", a.preset_modes)
  self:logState(d)
  self:updateProperty('thermostatMode',d.state)
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