---@diagnostic disable: undefined-global
---------------------------------------------------------------
--- Device classses (2) ------------------------------------------
--- DirigeraDevice, base class for all devices
--- Light, Lamps etc
--- LightController, Remote controller with buttons
--- Speaker, typically Sonos
--- Gateway, The hub
--- MotionSensor, usually combined with light sensor
--- LightSensor, usually combined with motion sensor
--- DoorSensor, magnetic sensor
--- AirSensor, 
--- BinaySwitch, Outlet
--- Speaker, Sonos players
---------------------------------------------------------------
DG = DG or { childs = {}}
local fmt = string.format
local function round(s) return math.floor(s+0.5) end
local devices = { id={}, type={}, deviceType={}, name={} } 
DG.devices = devices

local function dumpAttributes(id,a)
  for k,v in pairs(a or {}) do
    local d = DG.devices.id[id]
    local name = d.attributes.customName
    name = name and name ~= "" and name or "<noname>"
    v = type(v)=='table' and json.encode(v) or v
    DEBUGF('test',"%s -%s: %s",name,k,v)
  end
end

function QuickApp:defineClasses()
  
  class 'DirigeraDevice'
  function DirigeraDevice:__init(d) -- class for all devices
    self.id = d.id
    self.type = d.type
    self.deviceType = d.deviceType
    self.name = d.attributes.customName or "<noname>"
    if self.name == "" then self.name = "<noname>" end
    self.attributes = d.attributes
    local r = {}
    for _,v in ipairs(d.capabilities.canReceive or {}) do r[v] = true end
    self.canReceive = r -- can-receieve map
    self.capabilities = d.capabilities
    if self.isReachable ~= d.isReachable then
      self.isReachable = d.isReachable
      printc('yellow',"Init %s '%s' reachable: %s",self.deviceType,self.name,d.isReachable)
    end
    dumpAttributes(d.id,d.attributes)
  end
  function DirigeraDevice:change(data)
    if data.isReachable and self.isReachable ~= data.isReachable then
      self.isReachable = data.isReachable
      printc('yellow',"Change '%s' reachable: %s",self.name,data.isReachable)
    end
    dumpAttributes(data.id,data.attributes)
    if self.child then self.child:updateProperty('dead',self.isReachable==false) end
    if self.child then self:update(data) end
  end
  function DirigeraDevice:update(d) end -- Called when device is updated
  function DirigeraDevice:created() 
    if self.child then 
      local manufacturer, model = self.attributes.manufacturer or "", self.attributes.model or ""
      setTimeout(function() self.child:updateProperty('manufacturer',manufacturer) end,0)
      self.child:updateProperty('model',model)
      self.child:updateProperty('dead',self.isReachable==false)
    end
  end
  
  --- Device classes
  class 'ChildDimmableLight'(QwikAppChild) -- Light that only have dimming capabilities
  function ChildDimmableLight:__init(d) QwikAppChild.__init(self,d) end
  class 'ChildDimmableLight'(QwikAppChild)
  function ChildDimmableLight:__init(d) QwikAppChild.__init(self,d) end
  function ChildDimmableLight:turnOn()
    self:updateValue(100)
    self.dev:turnOn()
  end
  function ChildDimmableLight:turnOff() 
    self:updateValue(0)
    self.dev:turnOff() 
  end
  function ChildDimmableLight:setValue(level) 
    print("SETLEVEL",level)
    self.dev:setLevel(level)
    self.ignoreValue=true
  end
  function ChildDimmableLight:updateValue(level) --0..100
    if not self.ignoreValue then
      self:updateProperty('value',math.min(99,self.dev.lightLevel))
      self:updateProperty('state',level>0)
    end
    self.ignoreValue=false
  end
  class 'ChildTempLight'(ChildDimmableLight) -- Light with temp control
  function ChildTempLight:__init(d) ChildDimmableLight.__init(self,d) end
  function ChildTempLight:setTemperature(temp) --0..100
    print(json.encode(temp))
    if type(temp)=='table' then temp = temp.values[1] end
    self.dev:setTemperature(temp) 
  end 
  function ChildTempLight:updateTemperature(temp) --0..255
    DEBUGF('color',"TempLight updateTemperature called %s",temp)
    temp = round(temp/255*100)
    self:setVariable('temp',temp)
    self:updateView('temp','value',tostring(temp))
  end 
  
  class 'ChildColorLight'(ChildTempLight) -- Light with color control
  function ChildColorLight:__init(d) ChildTempLight.__init(self,d) end
  function ChildColorLight:setColor(r,g,b,w)
    local color = string.format("%d,%d,%d,%d", r or 0, g or 0, b or 0, w or 0)
    self:updateProperty("color", color)
    self.dev:setRGB(r,g,b,w) 
  end 
  function ChildColorLight:updateTemperature(temp) --0..255
    DEBUGF('color',"ColorLight updateTemp called %s",temp)
    local cc = self.properties.colorComponents 
    cc.warmWhite = temp
    self:updateProperty("colorComponents", cc)
  end
  function ChildColorLight:updateColor(r,g,b,w)
    local color = string.format("%d,%d,%d,%d", r or 0, g or 0, b or 0, w or 0)
    DEBUGF('color',"ColorLight updateColor called %s",color)
    self:updateProperty("color", color)
    local cc = self.properties.colorComponents 
    cc.red,cc.green,cc.blue,cc.white = r,g,b,cc.white and w or nil
    self:updateProperty("colorComponents", cc)
  end
  function ChildColorLight:setColorComponents(colorComponents) -- Called by HC3 UI
    DEBUGF('color',"setColorComponents called %s",json.encode(colorComponents))
    if colorComponents.warmWhite and not colorComponents.red then
      DEBUGF('color',"setColorComponents.temp")
      return self:setTemperature(colorComponents.warmWhite) -- 0..255
    end
    local cc = self.properties.colorComponents
    local isColorChanged = false
    for k,v in pairs(colorComponents) do
      if cc[k] and cc[k] ~= v then cc[k] = v isColorChanged = true end
    end
    if isColorChanged == true then
      self:updateProperty("colorComponents", cc)
      self:setColor(cc["red"], cc["green"], cc["blue"], cc["white"])
    end
  end
  
  class 'Light'(DirigeraDevice)
  function Light:__init(d)
    DirigeraDevice.__init(self,d)
    if self.canReceive.colorHue and ChildColorLight then
      DG.childs[self.id] = {
        name = self.name, 
        type = 'com.fibaro.colorController',
        className = 'ChildColorLight',
        properties = {colorComponents = {red=0,green=0,blue=0,warmWhite=0}}
      }
    elseif self.canReceive.colorTemperature and ChildTempLight then
      DG.childs[self.id] = {
        name = self.name,
        type = 'com.fibaro.multilevelSwitch',
        className = 'ChildTempLight',
        properties = {
          uiView = json.decode('[{"components":[{"name":"tempLabel","style":{"weight":"0.5"},"text":"TEMPERATURE","type":"label","visible":true},{"eventBinding":{"onChanged":[{"params":{"actionName":"UIAction","args":["onChanged","setTemperature","$event.value"]},"type":"deviceAction"}]},"max":"100","min":"0","name":"tempSlider","style":{"weight":"1.0"},"text":"","type":"slider","visible":true}],"style":{"weight":"1.0"},"type":"horizontal"}]') 
        }
      }
    elseif self.canReceive.lightLevel and ChildDimmableLight then
      DG.childs[self.id] = {
        name = self.name,
        type = 'com.fibaro.multilevelSwitch',
        className = 'ChildDimmableLight',
        properties = { uiView = {} }
      } 
    else
      ERRORF("Device %s can't recieve lightLevel, colorHue or colorTemperature",self.name)
    end
  end
  function Light:turnOn()
    quickApp:DPUT(fmt("/devices/%s",self.id),{{attributes = {isOn = true}}})
  end
  function Light:turnOff()
    quickApp:DPUT(fmt("/devices/%s",self.id),{{attributes = {isOn = false}}})
  end
  function Light:setLevel(level)
    if not self.canReceive.lightLevel then
      ERRORF("Device %s can't recieve lightLevel",self.name)
      return
    end
    if type(level)=='table' then level = tonumber(level.values[1]) end
    level = level or self.lightLevel
    if level > 100 then level = 100 elseif level < 1 then level = 1 end
    quickApp:DPUT(fmt("/devices/%s",self.id),{{attributes = {lightLevel = level}}})
  end
  function Light:setRGB(r,g,b)
    if not self.canReceive.colorHue then
      ERRORF("Device %s can't recieve colorHue",self.name)
      return
    end
    local h,s,v = RGB2HSV(r,g,b)
    quickApp:DPUT(fmt("/devices/%s",self.id),
    {{attributes = {
      colorHue = h, colorSaturation = s/100,
      lightLevel = round(v),
    }}})
  end
  function Light:setTemperature(temp) --0..255
    local tempOrg = temp
    if not self.canReceive.colorTemperature then
      ERRORF("Device %s can't recieve colorTemperature",self.name)
      return
    end
    local attrs = self.attributes
    local tint = attrs.colorTemperatureMin - attrs.colorTemperatureMax
    temp = round(attrs.colorTemperatureMax + tint*temp/255.0)
    if temp > attrs.colorTemperatureMin then 
      temp = attrs.colorTemperatureMin
    end
    if temp < attrs.colorTemperatureMax then 
      temp = attrs.colorTemperatureMax
    end
    quickApp:DPUT(fmt("/devices/%s",self.id),{{attributes = {colorTemperature = temp}}})
  end
  
  local filter = {colorMode=true,colorHue=true,colorSaturation=true,lightLevel=true,colorTemperature=true,isOn=true}
  
  function Light:update(d)
    local a,n = {},0 -- Log interesting attributes
    for k,v in pairs(d.attributes) do n=n+1; if filter[k] then a[k] = v end end
    DEBUGF("color",json.encode(a))
    self.colorMode = d.attributes.colorMode or self.colorMode
    if d.attributes.isOn ~= nil then self.isOn = d.attributes.isOn end
    self.colorSaturation = d.attributes.colorSaturation or self.colorSaturation
    self.colorHue = d.attributes.colorHue or self.colorHue
    self.lightLevel = d.attributes.lightLevel or self.lightLevel
    self.colorTemperature = d.attributes.colorTemperature or self.colorTemperature
    if self.colorMode == 'temperature' then
      if self.colorTemperature and self.child.setTemperature then
        local attrs = self.attributes
        if self.colorTemperature > attrs.colorTemperatureMin then
          self.colorTemperature = attrs.colorTemperatureMin
        end
        if self.colorTemperature < attrs.colorTemperatureMax then
          self.colorTemperature = attrs.colorTemperatureMax
        end
        local tnorm = self.colorTemperature - attrs.colorTemperatureMax
        local tmax = attrs.colorTemperatureMin - attrs.colorTemperatureMax
        local temp = round(tnorm/tmax*255)
        self.child:updateTemperature(temp)
      end
    elseif self.colorMode == 'color' then
      if self.colorHue and color and self.child.updateColor then
        local r,g,b = HSV2RGB(self.colorHue,100*self.colorSaturation,self.lightLevel)
        self.child:updateColor(r,g,b,self.lightLevel or 0)
      end
    end
    if self.isOn then
      self.child:updateValue(self.lightLevel)
    else
      self.child:updateProperty('state',false)
      self.child:updateProperty('value',0)
      self.ignoreValue = false
    end
  end
  
  class 'LightController'
  function LightController:__init(d)
    DirigeraDevice.__init(self,d)
  end
  
  class 'ChildSpeaker'(QwikAppChild)
  function ChildSpeaker:__init(d) QwikAppChild.__init(self,d) end
  function ChildSpeaker:play() self.dev:play() end
  function ChildSpeaker:setMute(f) self.dev:setMute(f==0) end
  function ChildSpeaker:stop() self.dev:stop() end
  function ChildSpeaker:pause() self.dev:pause() end
  function ChildSpeaker:next() self.dev:next() end
  function ChildSpeaker:prev() self.dev:prev() end
  function ChildSpeaker:setVolume(vol) self.dev:setVolume(vol) end
  --playback: 'playbackPaused', // 'playbackPlaying'
  class 'Speaker'(DirigeraDevice)
  function Speaker:__init(d)
    DirigeraDevice.__init(self,d)
    DG.childs[self.id] = {
      name = self.name,
      type = 'com.fibaro.player',
      className = 'ChildSpeaker'
    }
  end
  function Speaker:play()
    quickApp:DPUT(fmt("/devices/%s",self.id),{{attributes = {playback = "playbackPlaying"}}})
  end
  function Speaker:stop()
    quickApp:DPUT(fmt("/devices/%s",self.id),{{attributes = {playback = "playbackPaused"}}})
  end
  function Speaker:pause()
    quickApp:DPUT(fmt("/devices/%s",self.id),{{attributes = {playback = "playbackPaused"}}})
  end
  function Speaker:setMute(v)
    quickApp:DPUT(fmt("/devices/%s",self.id),{{attributes = {isMuted = v}}})
  end
  function Speaker:setVolume(v)
    quickApp:DPUT(fmt("/devices/%s",self.id),{{attributes = {volume = v}}})
  end
  function Speaker:prev()
    quickApp:DPUT(fmt("/devices/%s",self.id),{{attributes = {playback = "playbackPrevious"}}})
  end
  function Speaker:next()
    quickApp:DPUT(fmt("/devices/%s",self.id),{{attributes = {playback = "playbackNext"}}})
  end
  local speakerStates = {
    playbackPaused = 'paused',
    playbackPlaying = 'playing',
    playbackStopped = 'stopped',
    playbackBuffering = 'buffering',
    [""] = 'unknown'
  }
  local function getIF(v,dflt) if v==nil then return dflt else return v end end
  function Speaker:update(d)
    local stat,res = pcall(function()
      local attr = d.attributes
      if attr.playbackAudio then
        self.playbackAudio = attr.playbackAudio.playItem
      end
      --self.power = geattr.power or self.power
      self.volume = getIF(attr.volume,self.volume)
      self.muted = getIF(attr.isMuted,self.muted)
      self.state = getIF(attr.playback,self.state)
      if self.child then
        local child = self.child
        child:updateProperty('volume',self.volume)
        child:updateProperty('mute',self.muted)
        child:updateProperty('state',speakerStates[self.state])
        if self.playbackAudio then
          local song = self.playbackAudio
          child:setVariable("artist",song.artist or "")
          child:setVariable("title",song.title or "")
          child:setVariable("album",song.album or "")
        end
      end
    end)
    if not stat then 
      printc("red","Speaker update error: %s",res) 
    end
  end
  
  class 'Gateway'(DirigeraDevice)
  function Gateway:__init(d)
    DirigeraDevice.__init(self,d)
  end
  
  class 'ChildMotionSensor'(QwikAppChild)
  function ChildMotionSensor:__init(d) QwikAppChild.__init(self,d) end
  
  class 'MotionSensor'(DirigeraDevice)
  function MotionSensor:__init(d)
    DirigeraDevice.__init(self,d)
    DG.childs[self.id] = {
      name = self.name,
      type = 'com.fibaro.motionSensor',
      className = 'ChildMotionSensor',
      interfaces = {'battery'}
    }
  end
  function MotionSensor:update(d)
    if d.attributes.isDetected ~= nil then self.isDetected = d.attributes.isDetected end
    if d.attributes.isOn ~= nil then self.isOn = d.attributes.isOn end
    self.batteryPercentage = d.attributes.batteryPercentage
    printc("yellow","Motion isOn:%s isDetected:%s",self.isOn,self.isDetected)
    self.child:updateProperty('value',self.isDetected)
    self.child:updateProperty('batteryLevel',self.batteryPercentage)
  end
  
  class 'ChildLightSensor'(QwikAppChild)
  function ChildLightSensor:__init(d) QwikAppChild.__init(self,d) end
  
  class 'LightSensor'(DirigeraDevice)
  function LightSensor:__init(d)
    DirigeraDevice.__init(self,d)
    if self.name == "" then
      local r = DG.childs[d.relationId.."_1"]
      if r then self.name = r.name.."(Temp)" end
    end
    DG.childs[self.id] = {
      name = self.name,
      type = 'com.fibaro.lightSensor',
      className = 'ChildLightSensor',
      interfaces = {'battery'}
    }
  end
  function LightSensor:update(d)
    self.illuminance = d.attributes.illuminance or self.illuminance
    self.batteryPercentage = d.attributes.batteryPercentage or self.batteryPercentage
    self.child:updateProperty('value',self.illuminance)
    local r = DG.devices.id[(d.relationId or "").."_1"]
    if r then 
      self.batteryPercentage = r.object.batteryPercentage
    end
    self.child:updateProperty('batteryLevel',self.batteryPercentage)
  end
  
  class 'ChildDoorSensor'(QwikAppChild)
  function ChildDoorSensor:__init(d) QwikAppChild.__init(self,d) end
  
  class 'DoorSensor'(DirigeraDevice)
  function DoorSensor:__init(d)
    DirigeraDevice.__init(self,d)
    DG.childs[self.id] ={
      name = self.name,
      type = 'com.fibaro.doorSensor',
      className = 'ChildDoorSensor',
      interfaces = {'battery'}
    }
  end
  function DoorSensor:update(d)
    if d.attributes.isOpen ~= nil then self.isOpen = d.attributes.isOpen end
    self.batteryPercentage = d.attributes.batteryPercentage or self.batteryPercentage
    self.child:updateProperty('value',self.isOpen)
    self.child:updateProperty('batteryLevel',self.batteryPercentage)
  end
  
  class 'ChildWaterSensor'(QwikAppChild)
  function ChildWaterSensor:__init(d) QwikAppChild.__init(self,d) end
  
  class 'WaterSensor'(DirigeraDevice)
  function WaterSensor:__init(d)
    DirigeraDevice.__init(self,d)
    DG.childs[self.id] ={
      name = self.name,
      type = 'com.fibaro.waterSensor',
      className = 'ChildWaterSensor',
      interfaces = {'battery'}
    }
  end
  function WaterSensor:update(d)
    if d.attributes.waterLeakDetected ~= nil then self.waterLeakDetected = d.attributes.waterLeakDetected end
    self.batteryPercentage = d.attributes.batteryPercentage or self.batteryPercentage
    self.child:updateProperty('value',self.waterLeakDetected)
    self.child:updateProperty('batteryLevel',self.batteryPercentage)
  end
  
  class 'ChildPM25Sensor'(QwikAppChild)
  function ChildPM25Sensor:__init(d) 
    QwikAppChild.__init(self,d) 
    setTimeout(function() self:updateProperty("unit"," µg/m³") end,0)
    setTimeout(function() self:updateProperty("deviceIcon",550) end,0)
  end
  class 'ChildVocSensor'(QwikAppChild)
  function ChildVocSensor:__init(d) QwikAppChild.__init(self,d) 
    setTimeout(function() self:updateProperty("unit"," ppm") end,0)
    setTimeout(function() self:updateProperty("deviceIcon",273) end,0)
  end
  class 'ChildTempSensor'(QwikAppChild)
  function ChildTempSensor:__init(d) QwikAppChild.__init(self,d) end
  class 'ChildHumiditySensor'(QwikAppChild)
  function ChildHumiditySensor:__init(d) QwikAppChild.__init(self,d) end
  
  class 'AirSensor'(DirigeraDevice)
  function AirSensor:__init(d)
    DirigeraDevice.__init(self,d)
    local manufacturer, model = d.attributes.manufacturer or "", d.attributes.model or ""
    DG.childs[self.id.."_pm25"] = {
      name = self.name.."(PM25)",
      type = 'com.fibaro.multilevelSensor',
      properties = {unit = " µg/m³", manufacturer = manufacturer, model = model},
      className = 'ChildPM25Sensor'
    }
    DG.childs[self.id.."_voc"] = {
      name = self.name.."(tVOC)",
      type = 'com.fibaro.multilevelSensor',
      properties = {unit = " ppm", manufacturer = manufacturer, model = model},
      className = 'ChildVocSensor'
    }
    DG.childs[self.id] = {
      name = self.name.."(Humidity)",
      type = 'com.fibaro.humiditySensor',
      properties = {manufacturer = manufacturer, model = model},
      className = 'ChildHumiditySensor'
    }
    DG.childs[self.id.."_temp"] = {
      name = self.name.."(Temp)",
      type = 'com.fibaro.temperatureSensor',
      
      className = 'ChildTempSensor'
    }
  end
  function AirSensor:update(d)
    self.currentRH = d.attributes.currentRH or self.currentRH
    self.currentPM25 = d.attributes.currentPM25 or self.currentPM25
    self.vocIndex = d.attributes.vocIndex or self.vocIndex
    self.currentTemperature = d.attributes.currentTemperature or self.currentTemperature
    local PM = quickApp.children[self.id.."_pm25"]
    if PM then PM:updateProperty('value',self.currentPM25) end
    local RH = quickApp.children[self.id]
    if RH then RH:updateProperty('value',self.currentRH) end
    local TEMP = quickApp.children[self.id.."_temp"]
    if TEMP then TEMP:updateProperty('value',self.currentTemperature) end
    local VOC = quickApp.children[self.id.."_voc"]
    if VOC then VOC:updateProperty('value',self.vocIndex) end
  end
  
  class 'ChildBinarySwitch'(QwikAppChild)
  function ChildBinarySwitch:__init(d)
    QwikAppChild.__init(self,d)
  end
  function ChildBinarySwitch:turnOn() self.dev:turnOn() end
  function ChildBinarySwitch:turnOff() self.dev:turnOff() end
  
  class 'BinarySwitch'(DirigeraDevice)
  function BinarySwitch:__init(d)
    DirigeraDevice.__init(self,d)
    local interfaces = {}
    if d.attributes.totalEnergyConsumed then 
      table.insert(interfaces,'energy') 
    end
    if d.attributes.currentActivePower then 
      table.insert(interfaces,'power') 
    end
    if #interfaces == 0 then interfaces = nil end
    DG.childs[self.id] = {
      name = self.name,
      type = 'com.fibaro.binarySwitch',
      className = 'ChildBinarySwitch',
      interfaces = interfaces
    }
  end
  function BinarySwitch:turnOn()
    quickApp:DPUT(fmt("/devices/%s",self.id),{{attributes = {isOn = true}}}) 
  end
  function BinarySwitch:turnOff()
    quickApp:DPUT(fmt("/devices/%s",self.id),{{attributes = {isOn = false}}})
  end
  function BinarySwitch:update(data)
    if not self.child then return end
    self.currentAmps = data.attributes.currentAmps or self.currentAmps
    self.currentVoltage = data.attributes.currentVoltage or self.currentVoltage
    self.currentActivePower = data.attributes.currentActivePower or self.currentActivePower
    self.totalEnergyConsumed = data.attributes.totalEnergyConsumed or self.totalEnergyConsumed
    if data.attributes.isOn ~= nil then self.isOn = data.attributes.isOn end
    self.child:updateProperty('value',self.isOn)
    if self.currentActivePower then
      self.child:updateProperty('power',self.currentActivePower)
    end
    if self.totalEnergyConsumed then
      self.child:updateProperty('energy',self.totalEnergyConsumed)
    end
  end
  
  ---------------
  local function NoDevice(d)
    print("Device not implemented: ",d.deviceType)
  end
  local deviceTypeMap = {
    ["light"] = Light,
    ["lightController"] = LightController,
    ["speaker"] = Speaker,
    ["gateway"] = Gateway,
    ["motionSensor"] = MotionSensor,
    ["lightSensor"] = LightSensor,
    ["openCloseSensor"] = DoorSensor,
    ["environmentSensor"] = AirSensor,
    ["outlet"] = BinarySwitch,
    ['blinds'] = NoDevice, --Blinds,
    ['waterSensor'] = NoDevice, --WaterSensor
    ['airPurifier'] = NoDevice, -- AirPurifier
  }
  
  function DG:addDevice(d)
    devices.id[d.id] = d
    devices.type[d.type] = d
    devices.deviceType[d.deviceType] = d
    devices.name[d.attributes.customName] = d
    d.object = (deviceTypeMap[d.deviceType] or NoDevice)(d)
  end
  
  local scenes = {}
  function DG:addScene(d)
    scenes[d.info.name] = d
  end
  
  function QuickApp:scene(name,trigger)
    local scene = scenes[name]
    if not scene then ERRORF("Scene %s not found",name) return end
    if trigger == false then
      self:DPOST(fmt("/scenes/%s/undo",scene.id))
    else
      self:DPOST(fmt("/scenes/%s/trigger",scene.id))
    end
  end
  
  function QuickApp:createScene(name,icon,sceneType,triggers,actions)
    ---Creates a new scene.
    --- Note:
    ---To create an empty scene leave actions and triggers None.
    -- Args:
    --     info (Info): Name & Icon
    --     type (SceneType): typically USER_SCENE
    --     triggers (List[Trigger]): Triggers for the Scene (An app trigger will be created automatically)
    --     actions (List[Action]): Actions that will be run on Trigger
    
    -- Returns:
    --     Scene: Returns the newly created scene.
    local triggerList = json.util.InitArray({})
    if triggers then
      for _,x in ipairs(triggers) do triggerList[#triggerList+1] = json.encode(x) end
      
    end
    local actionList = json.util.InitArray({})
    if actions then
      for _,x in ipairs(actions) do actionList[#actionList+1] = json.encode(x) end
    end
    local data = {
      info = {name=name,icon=icon or "scenesSnowflake"},
      type =  sceneType or "userScene",
      triggers = triggerList,
      actions = actionList,
    }
    local d = json.encode(data)
    self:DPOST("/scenes/",data,function(d)
      print(json.encode(d))
    end)
  end
  
  function DG:linkDevices() 
    for _,d in pairs(devices.id) do
      local child = quickApp.children[d.id]
      if child then 
        d.object.child = child
        child.dev = d.object
        d.object:update(d)
        d.object:created()
      end
    end
  end
  
end