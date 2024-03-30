fibaro.debugFlags = fibaro.debugFlags or {}
local HUE

local _version = 0.5
local serial = "UPD896661234567893"
HUEv2Engine = HUEv2Engine or {}
local HUE = HUEv2Engine
HUE.appName = "YahueV2"
HUE.appVersion = tostring(_version)

local function ROUND(i) return math.floor(i+0.5) end
local function printf(fmt,...) print(string.format(fmt,...)) end
local function keys(t) local r = {} for k,v in pairs(t) do r[#r+1]=k end return r end
local function values(t) local r = {} for k,v in pairs(t) do r[#r+1]=v end return r end
local sceneTargets = {}

local devProps = { 
  temperature = "TemperatureSensor", 
  relative_rotary = "MultilevelSensor", 
  button = "Button", 
  light = "LuxSensor", 
  contact_report = "DoorSensor", 
  motion = "MotionSensor",
  [function(p) return p.on and not (p.color or p.dimming) and "plug" end] = "BinarySwitch", 
}

local defClasses

function HUEv2Engine:app()
  defClasses()
  local ddevices = {}
  for id,dev in pairs(HUE:getResourceType('device')) do
    dev = HUE:getResource(id)
    local props,ok = dev:getProps()
    for p,cls in pairs(devProps) do
      if type(p) == 'function' then ok = p(props)
      else ok = props[p] and p end
      if ok then
        print(ok,"->",dev.name)
        ddevices[cls..":"..id] = {
          id = id,
          class = cls,
          enabled = false,
          args = {}
        }
      end
    end
  end
  for id,zr in pairs(HUE:getResourceType('zone')) do
    local dev = HUE:getResource(id)
    local props = dev:getProps()
    ddevices["RoomZoneQA:"..id] = {
      id = id,
      class = "RoomZoneQA",
      enabled = false
    }
  end
  for id,zr in pairs(HUE:getResourceType('room')) do
    ddevices["RoomZoneQA:"..id] = {
      id = id,
      class = "RoomZoneQA",
      enabled = false
    }
  end
  
  local hdevs = {}
  for _,d in ipairs(HUEDevices) do
    hdevs[d.class..":"..d.id] = d
  end
  
  local regenerate = false
  for id,_ in pairs(hdevs) do
    if not ddevices[id] then hdevs[id] = nil regenerate=true end
  end
  for id,dev in pairs(ddevices) do
    if not hdevs[id] then hdevs[id] = dev regenerate=true end
  end
  
  if regenerate then
    local b = fibaro.printBuffer()
    local hhdevs = values(hdevs)
    table.sort(hhdevs,function(a,b) return a.id < b.id end)
    b:printf("\nHUEDevices = {\n")
    local i = ""
    for _,dev in pairs(hhdevs) do
      local d = HUE:getResource(dev.id)
      if d.id ~= i then
        b:printf("-- '%s', %s\n",d.name,d.resourceName or "<N/A")
        i = d.id
      end
      b:printf(" {id='%s', class='%s', enabled=%s, args='%s'},\n",dev.id,dev.class,dev.enabled,json.encode(dev.args))
    end
    
    for id,room in pairs(HUE:getResourceType('room')) do
      b:printf("-- Room '%s'\n",room.name)
      b:printf(" {id='%s', class='RoomZoneQA', enabled=false},\n",id)
    end
    for id,zone in pairs(HUE:getResourceType('zone')) do
      b:printf("-- Zone '%s'\n",zone.name)
      b:printf(" {id='%s', class='RoomZoneQA', enabled=false},\n",id)
    end
    
    b:printf("}\n")
    print(b:tostring())
    
    if fibaro.fibemu then
      local data = b:tostring()
      local f = io.open("QAs/HueV2Map.lua","w")
      f:write(data)
      f:close()
      data = "return function() "..data.." return HUEDevices end"
      HUEDevices = load(data)()()
    else
      print("Please copy the above output to dev/HueV2Map.lua")
    end
    hdevs = {}
    for _,d in ipairs(HUEDevices) do
      hdevs[d.class..":"..d.id] = d
    end
  end
  
  local children = {}
  for id,data in pairs(hdevs) do
    if data.enabled then
      local dev = HUE:getResource(data.id)
      children[id] = {
        name = dev.name,
        type =_G[data.class].htype,
        className = data.class,
        interfaces = dev:getProps()['power_state'] and {'battery'} or nil,
      }
      if _G[data.class].annotate then
        _G[data.class].annotate(children[id])
      end
    end
  end
  
  local enums = {"_"}
  for id,scene in pairs(HUE:getResourceType('scene')) do
    
    local zoneroom = HUE:_resolve(scene.rsrc.group)
    sceneTargets[zoneroom.id] = sceneTargets[zoneroom.id] or {}
    table.insert(sceneTargets[zoneroom.id],scene.id)
    
    local g = HUE:_resolve(scene.rsrc.group)
    if g then
      enums[#enums+1] = string.format("%s,%s",scene.name,g.name)
    end
  end
  local gv = { name = "HueScenes", value="_", readOnly = true, isEnum=true, enumValues = enums }
  local d = api.post("/globalVariables",gv,"hc3")
  if not d then
    api.put("/globalVariables/HueScenes",gv,"hc3")
  end
  
  quickApp:initChildren(children)
end

function defClasses()
  
  class 'HueClass'(QwikAppChild)
  function HueClass:__init(dev)
    QwikAppChild.__init(self,dev)
    self.uid = self:getVariable("ChildID"):match(".-:(.*)")
    self.dev = HUE:getResource(self.uid)
    self.pname = "CHILD"..self.id
    self.dev:subscribe("status",function(key,value,b)
      self:print("status %s",value)
      if value ~= 'connected' then
        self:updateProperty("dead",true)
      end
      self:updateProperty("dead",value~='connected')
    end)
    self.dev:subscribe("power_state",function(key,value,b)
      self:print("battery %s",value.battery_level)
      self:updateProperty("batteryLevel",value.battery_level)
    end)
  end
  function HueClass:print(fmt,...)
    local TAG = __TAG; __TAG = self.pname
    self:debug(string.format(fmt,...))
    __TAG = TAG
  end
  
  class 'TemperatureSensor'(HueClass)
  TemperatureSensor.htype = "com.fibaro.temperatureSensor"
  function TemperatureSensor:__init(device)
    HueClass.__init(self,device)
    self.dev:subscribe("temperature",function(key,value,b)
      self:print("temperature %s",value)
      self:updateProperty("value",value)
    end)
    self.dev:publishAll()
  end
  
  class 'BinarySwitch'(HueClass)
  BinarySwitch.htype = "com.fibaro.binarySwitch"
  function BinarySwitch:__init(device)
    HueClass.__init(self,device)
    self.dev:subscribe("on",function(key,value,b)
      self:print("on %s",value)
      self:updateProperty("value",value)
    end)
    self.dev:publishAll()
  end
  
  class 'LuxSensor'(HueClass)
  LuxSensor.htype = "com.fibaro.lightSensor"
  function LuxSensor:__init(device)
    HueClass.__init(self,device)
    self.dev:subscribe("light",function(key,value,b)
      value = 10 ^ ((value - 1) / 10000)
      self:print("lux %s",value)
      self:updateProperty("value",value)
    end)
    self.dev:publishAll()
  end
  
  class 'MotionSensor'(HueClass)
  MotionSensor.htype = "com.fibaro.motionSensor"
  function MotionSensor:__init(device)
    HueClass.__init(self,device)
    self.dev:subscribe("motion",function(key,value,b)
      self:print("motion %s",value)
      self:updateProperty("value",value)
    end)
    self.dev:publishAll()
  end
  
  local btnMap = {initial_press="Pressed",['repeat']="HeldDown",short_release="Released",long_release="Released"}
    class 'Button'(HueClass)
    Button.htype = 'com.fibaro.remoteController'
    function Button:__init(device)
      HueClass.__init(self,device)
      local deviceId,ignore = self.id,false
      self.dev:subscribe("button",function(key,value,b)
        local _modifier,key = b:button_state()
        local modifier = btnMap[_modifier] or _modifier
        self:print("button:%s %s %s",key,modifier,_modifier)
        local data = {
          type =  "centralSceneEvent",
          source = deviceId,
          data = { keyAttribute = modifier, keyId = key }
        }
        if not ignore then api.post("/plugins/publishEvent", data) end
      end)
      ignore = true
      self.dev:publishAll()
      ignore = false
    end
    function Button.annotate(child)
      child.properties = child.properties or {}
      child.properties.centralSceneSupport = {   
        { keyAttributes = {"Pressed","Released","HeldDown"},keyId = 1 },
        { keyAttributes = {"Pressed","Released","HeldDown"},keyId = 2 },
        { keyAttributes = {"Pressed","Released","HeldDown"},keyId = 3 },
        { keyAttributes = {"Pressed","Released","HeldDown"},keyId = 4 },
      }
      child.interfaces = child.interfaces or {}
      table.insert(child.interfaces,"zwaveCentralScene")
    end
    
    class 'DoorSensor'(HueClass)
    DoorSensor.htype = "com.fibaro.doorSensor"
    function DoorSensor:__init(device)
      HueClass.__init(self,device)
      self.dev:subscribe("contact_report",function(key,value,b)
        self:print("contact %s",value)
        self:updateProperty("value",value)
      end)
      self.dev:publishAll()
    end
    
    class 'MultilevelSensor'(HueClass)
    MultilevelSensor.htype = "com.fibaro.multilevelSensor"
    function MultilevelSensor:__init(device)
      HueClass.__init(self,device)
      self.value = 0
      self.dev:subscribe("relative_rotary",function(key,v,b)
        self.value = 
        self.value + 
        v.rotation.steps*(1 - (v.rotation.direction=='clock_wise' and 0 or 2))
        if self.value < 0 then self.value = 0 end
        if self.value > 100 then self.value = 100 end
        self:print("rotary %s",self.value)
        self:updateProperty("value",self.value)
      end)
      self.dev:publishAll()
    end
    
    local QAviewJson = [[{"$jason":{"head":{"title":"quickApp_device_1514"},"body":{"sections":{"items":[{"style":{"weight":"1.2"},"type":"vertical","components":[{"type":"label","name":"label_ID_1","visible":true,"text":"Turn On Scene","style":{"weight":"1.2"}},{"type":"space","style":{"weight":"0.5"}}]},{"style":{"weight":"1.2"},"type":"vertical","components":[{"values":{},"style":{"weight":"1.2"},"name":"select_ID_0","options":{},"visible":true,"text":"Scene","type":"select","selectionType":"single"},{"type":"space","style":{"weight":"0.5"}}]}]},"header":{"title":"quickApp_device_1514","style":{"height":"0"}}}}}]]
    local QAView = json.decode(QAviewJson)
    class 'RoomZoneQA'(HueClass)
    RoomZoneQA.htype = "com.fibaro.multilevelSwitch"
    function RoomZoneQA:__init(device)
      HueClass.__init(self,device)
      self.dev:subscribe("on",function(key,value,b)
        self:print("on %s",value)
        local d = ROUND(b._props.dimming.get(b.rsrc))
        self:updateProperty("state",true)
        self:updateProperty("value",d)
      end)
      self.dev:subscribe("dimming",function(key,value,b)
        self:print("dimming %s",value)
        self:updateProperty("value",ROUND(value))
      end)
      local data = {{text='_',type='option',value='_'}}
      for _,s in ipairs(sceneTargets[self.uid] or {}) do
        local scene = HUE:getResource(s)
        data[#data+1] = {text=scene.name,type='option',value=s}
      end
      self:updateView("select_ID_0","options",data)
      self.dev:publishAll()
    end
    function RoomZoneQA:selectScene(event)
      self:setVariable("scene",event.values[1])
    end
    function RoomZoneQA:turnOn()
      self:print("Turn on")
      self:updateProperty("value", 100)
      self:updateProperty("state", true)
      local scene = HUE:getResource(self:getVariable("scene"))
      if not scene then
        self.dev:targetCmd({on = {on=true}})
      else
        scene:recall()
      end
    end
    function RoomZoneQA:turnOff()
      self:print("Turn off")
      self:updateProperty("value", 0)
      self:updateProperty("state", false)
      self.dev:targetCmd({on = {on=false}})
    end
    function RoomZoneQA:setValue(value)
      if type(value)=='table' then value = value.values[1] end
      value = tonumber(value)
      self:print("setValue")
      self:updateProperty("value", value)
      self.dev:targetCmd({dimming = {brightness=value}})
    end
    function RoomZoneQA.annotate(child)
      child.properties = child.properties or {}
      child.properties.viewLayout = QAView
      child.properties.uiCallbacks = {
        {
          callback = "selectScene",
          eventType = "onToggled",
          name = "select_ID_0"
        },
        {
          callback = "turnOn",
          eventType = "onReleased",
          name = "__turnon"
        },
        {
          callback = "setValue",
          eventType = "onChanged",
          name = "__value"
        },
        {
          callback = "turnOff",
          eventType = "onReleased",
          name = "__turnoff"
        }
      }
    end
    
  end