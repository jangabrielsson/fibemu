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
local argsMap = {}
local function getVar(id,key)
    local res, stat = api.get("/plugins/" .. id .. "/variables/" .. key)
    if stat ~= 200 then return nil end
    return res.value
end

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
  local childDevices = {}
  for _,c in ipairs(api.get("/devices?parentId="..quickApp.id) or {}) do
    local uid = getVar(c.id,"ChildID")
    if uid then childDevices[uid]=true end
  end
  print(json.encode(childDevices))
  local ddevices = {}
  for id,dev in pairs(HUE:getResourceType('device')) do
    dev = HUE:getResource(id)
    local props,ok = dev:getProps()
    for p,cls in pairs(devProps) do
      if type(p) == 'function' then ok = p(props)
      else ok = props[p] and p end
      if ok then
        print(ok,"->",dev.name)
        local tag = cls..":"..id
        ddevices[tag] = {
          id = id,
          class = cls,
          enabled = childDevices[tag] or false,
          args = {}
        }
      end
    end
  end
  for id,zr in pairs(HUE:getResourceType('zone')) do
    local tag = "RoomZoneQA:"..id
    ddevices[tag] = {
      id = id,
      class = "RoomZoneQA",
      enabled = childDevices[tag] or false,
      args = {}
    }
  end
  for id,zr in pairs(HUE:getResourceType('room')) do
    local tag = "RoomZoneQA:"..id
    ddevices[tag] = {
      id = id,
      class = "RoomZoneQA",
      enabled = childDevices[tag] or false,
      args = {}
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
  
  local function encodeArgs(t)
    if type(t)~='table' then return "{}" end
    local p = fibaro.printBuffer()
    for k,v in pairs(t) do
      p:printf("%s='%s',",k,tostring(v))
    end
    return "{"..p:tostring().."}"
  end

  if regenerate then
    print("Regenerating map file")
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
      b:printf(" {id='%s', class='%s', enabled=%s, args=%s},\n",dev.id,dev.class,dev.enabled,encodeArgs(dev.args))
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
      if not api.put("/quickApp/"..quickApp.id.."/files/Map",{
        name="Map", isMain=false, isOpem=false, content=b:tostring()
      }) then
        api.post("/quickApp/"..quickApp.id.."/files",{
          name="Map", isMain=false, isOpem=false, content=b:tostring()
        })
      end
    end
    hdevs = {}
    for _,d in ipairs(HUEDevices) do
      hdevs[d.class..":"..d.id] = d
    end
  end
  
  local children = {}
  for id,data in pairs(hdevs) do
    argsMap[id]=data
    if data.enabled then
      local dev = HUE:getResource(data.id)
      children[id] = {
        name = dev.name,
        type =_G[data.class].htype,
        className = data.class,
        interfaces = dev:getProps()['power_state'] and {'battery'} or nil,
      }
      if true then
        _G[data.class].annotate(children[id])
      end
    end
  end
  
  quickApp:initChildren(children)
end

function defClasses()
  print("Defining QA classes")
  class 'HueClass'(QwikAppChild)
  function HueClass:__init(dev)
    QwikAppChild.__init(self,dev)
    self.uid = self._uid:match(".-:(.*)")
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
  function TemperatureSensor.annotate() end
  
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
  function BinarySwitch:turnOn()
    self:updateProperty("value",true)
    self:updateProperty("state",true)
  end
  function BinarySwitch:turnOff()
      self:updateProperty("value",false)
      self:updateProperty("state",false)
  end
  function BinarySwitch.annotate() end

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
  function LuxSensor.annotate() end

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
  function MotionSensor.annotate() end  

  local btnMap = {initial_press="Pressed",['repeat']="HeldDown",short_release="Released",long_release="Released"}
    class 'Button'(HueClass)
    Button.htype = 'com.fibaro.remoteController'
    function Button:__init(device)
      HueClass.__init(self,device)
      local deviceId,ignore = self.id,false
      local btnSelf = self
      self.dev:subscribe("button",function(key,value,b)
        local _modifier,key = b:button_state()
        local modifier = btnMap[_modifier] or _modifier
        btnSelf:print("button:%s %s %s",key,modifier,_modifier)
        local data = {
          type =  "centralSceneEvent",
          source = deviceId,
          data = { keyAttribute = modifier, keyId = key }
        }
        if not ignore then api.post("/plugins/publishEvent", data) end
        btnSelf:updateProperty("log",string.format("Key:%s,Attr:%s",key,modifier))
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
    function Button.annotate() end

    class 'DoorSensor'(HueClass)
    DoorSensor.htype = "com.fibaro.doorSensor"
    function DoorSensor:__init(device)
      HueClass.__init(self,device)
      self.dev:subscribe("contact_report",function(key,value,b)
        value = not(value=='contact')
        self:print("contact %s",value)
        self:updateProperty("value",value)
      end)
      self.dev:publishAll()
    end
    function DoorSensor.annotate() end

    class 'MultilevelSensor'(HueClass)
    MultilevelSensor.htype = "com.fibaro.multilevelSensor"
    function MultilevelSensor:__init(device)
      HueClass.__init(self,device)
      self.args = argsMap[self._uid].args or {}
      self.args.div = self.args.div or 1
      self.value = 0
      self.dev:subscribe("relative_rotary",function(key,v,b)
        local steps = math.max(ROUND(v.rotation.steps / self.args.div),1)
        local dir = (1 - (v.rotation.direction=='clock_wise' and 0 or 2))
        self.value = self.value + steps*dir
        if self.value < 0 then self.value = 0 end
        if self.value > 100 then self.value = 100 end
        self:print("rotary %s",self.value)
        self:updateProperty("value",self.value)
      end)
      self.dev:publishAll()
    end
    function MultilevelSensor.annotate() end

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
      self.dev:publishAll()
    end
    function RoomZoneQA:setScene(event)
      self:setVariable("scene",event.values[1])
    end
    function RoomZoneQA:turnOn()
      self:updateProperty("value", 100)
      self:updateProperty("state", true)
      local sceneName = self:getVar("scene")
      print("S:"..sceneName)
      local scene = HUE:getSceneByName(sceneName,self.dev.name)
      if not scene then
        self:print("Scene",sceneName,"not found")
        self.dev:targetCmd({on = {on=true}})
      else
        self:print("Turn on Scene %s",scene.name)
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
    function RoomZoneQA:getVar(name)
      local qvs = __fibaro_get_device_property(self.id,"quickAppVariables").value
      for _,var in ipairs(qvs or {}) do
        if var.name==name then return var.value end
      end
      return ""
    end
    function RoomZoneQA.annotate() end
    
  end

----------- Child class
do
  local childID = 'ChildID'
  local classID = 'ClassName'
  local defChildren

  local children = {}
  local undefinedChildren = {}
  local createChild = QuickApp.createChildDevice
  class 'QwikAppChild'(QuickAppChild)

  local fmt = string.format 

  local function setupUIhandler(self)
     if not self.UIHandler then
        function self:UIHandler(event)
            local obj = self
            if self.id ~= event.deviceId then obj = (self.childDevices or {})[event.deviceId] end
            if not obj then return end
            local elm,etyp = event.elementName, event.eventType
            local cb = obj.uiCallbacks or {}
            if obj[elm] then return obj:callAction(elm, event) end
            if cb[elm] and cb[elm][etyp] and obj[cb[elm][etyp]] then return obj:callAction(cb[elm][etyp], event) end
            if obj[elm.."Clicked"] then return obj:callAction(elm.."Clicked", event) end
            self:warning("UI callback for element:", elm, " not found-")
        end
     end
  end

  local UID = nil
  function QwikAppChild:__init(device) 
    QuickAppChild.__init(self, device)
    self:debug(fmt("Instantiating ID:%s '%s'",device.id,device.name))
    local uid = UID or self:internalStorageGet(childID) or ""
    self._uid = uid
    if defChildren[uid] then
      children[uid]=self               -- Keep table with all children indexed by uid. uid is unique.
    else                               -- If uid not in our children table, we will remove this child
      undefinedChildren[#undefinedChildren+1]=self.id 
    end
    self._sid = tonumber(uid:match("(%d+)$"))
  end

  function QuickApp:createChildDevice(uid,props,interfaces,className)
    __assert_type(uid,'string')
    __assert_type(className,'string')
    props.initialProperties = props.initialProperties or {}
    props.initialInterfaces = interfaces
    --self:debug("Creating device ",props.name)
    UID = uid
    local c = createChild(self,props,_G[className])
    UID = nil
    if not c then return end
    c:internalStorageSet(childID,uid,true)
    c:internalStorageSet(classID,className,true)
  end

  function QuickApp:loadExistingChildren(chs)
    __assert_type(chs,'table')
    local stat,err = pcall(function()
        defChildren = chs
        self.children = children
        function self.initChildDevices() end
        local cdevs,n = api.get("/devices?parentId="..self.id) or {},0 -- Pick up all my children
        for _,child in ipairs(cdevs) do
          local uid = getVar(child.id,childID)
          local className = getVar(child.id,classID)
          print(child.id,uid,className)
          local childObject = _G[className] and _G[className](child) or QuickAppChild(child)
          self.childDevices[child.id]=childObject
          childObject.parent = self
        end
      end)
    if not stat then self:error("loadExistingChildren:"..err) end
  end

  function QuickApp:createMissingChildren()
    local stat,err = pcall(function()
        local chs,k = {},0
        for uid,data in pairs(defChildren) do
          local m = uid:sub(1,1)=='i' and 100 or 0
          k = k + 1
          chs[#chs+1]={uid=uid,id=m+tonumber(uid:match("(%d+)$") or k),data=data} 
        end
        table.sort(chs,function(a,b) return a.id<b.id end)
        for _,ch in ipairs(chs) do
          if not self.children[ch.uid] then
            local props = {
              name = ch.data.name,
              type = ch.data.type,
              initialProperties = ch.data.properties,
            }
            self:createChildDevice(ch.uid,props,ch.data.interfaces,ch.data.className)
          end
        end 
      end)
    if not stat then self:error("createMissingChildren:"..err) end
  end

  function QuickApp:removeUndefinedChildren()
    for _,deviceId in ipairs(undefinedChildren) do -- Remove children not in children table
      self:removeChildDevice(deviceId)
    end
  end

  function QuickApp:initChildren(children)
    setupUIhandler(self)
    self:loadExistingChildren(children)
    self:createMissingChildren()
    self:removeUndefinedChildren()
  end
end
