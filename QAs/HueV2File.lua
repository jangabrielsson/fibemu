------- QAs/HueV2Engine.lua ----------
--[[
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.
(C) 2022 jan@gabrielsson.com
--]]

-- luacheck: globals ignore quickApp plugin api net netSync setTimeout clearTimeout setInterval clearInterval json
-- luacheck: globals ignore hc3_emulator HUEv2Engine fibaro
-- luacheck: globals ignore homekit device light zigbee_connectivity device_power zgp_cpnnectivity entertainment entertainment_configuration
-- luacheck: globals ignore room zone grouped_light scene button relative_rotary temperature motion light_level bridge bridge_home behavior_script
-- luacheck: globals ignore behavior_instance geolocation geolocation_client
-- luacheck: ignore 212/self

local version = 0.47

local fmt = string.format
fibaro.debugFlags = fibaro.debugFlags or {}
local debug = fibaro.debugFlags
local function DEBUG(flag,fm,...) if debug[flag] then quickApp:debug(fmt(fm,...)) end end
local function WARNING(fm,...) quickApp:warning(fmt(fm,...)) end
local function ERROR(fm,...) quickApp:error(fmt(fm,...)) end

HUEv2Engine = HUEv2Engine or {}
HUEv2Engine.version = version
fibaro.hue = fibaro.hue or {}
fibaro.hue.Engine = HUEv2Engine
local function setup()
end
local function strip(l) local r={} for k,v in pairs(l) do r[#r+1]=k end return r end

--[[
debug.info          -- greetings etc
debug.class         -- class creation
debug.resource_mgmt -- creation/delation/modification of object
debug.event         -- incoming event from Hue hub
debug.v2api         -- v2api info (unhandled events etc)
debug.call          -- http calls to Hue hub
debug.unknownType   -- Unhandled device updates
debug.logger        -- Logs subscribption events
--]]

--[[
Room--+
|             +------ Service A
|             |
+---Device ---+
|
+--+------ Service B
|
Zone-------------+
|
+----- Service - Grouped Light
--]]

if not fibaro.event then
  local _events={}
  function fibaro.event(ev,h) _events[ev.type]=h end
  function fibaro.post(ev,t)
    return setTimeout(function() _events[ev.type](ev) end,t or 0)
  end
end

local function copyShallow(t) local r = {} for k,v in pairs(t) do r[k]=v end return r end
local function copy(t) 
  local r = {} 
  for k,v in pairs(t) do if type(v)=='table' then r[k]=copy(v) else r[k]=v end end 
  return r
end

local function keyMerge(t1,t2)
  local res = copy(t1)
  for k,v in pairs(t2) do if t1[k]==nil then t1[k]=v end end
  return res
end

local _initEngine
local function main()
  local v2 = "1948086000"
  local OPTIMISTIC = false
  local err_retry = 3
  local post = fibaro.post
  local resources = {}
  local props,meths={},{}
  local hueGET,huePUT
  local app_key,url,callBack
  local fmt = string.format
  local merge = keyMerge
  local classes = {}
  local function createResourceTable()
    local self = { resources={}, id2resource={} }
    local resources,id2resource = self.resources,self.id2resource
    function self.changeHook() end
    function self.add(id,rsrc)
      local typ = rsrc.type
      if id2resource[id] then self.modify(id,rsrc)
      else
        if classes[typ] then
          rsrc = classes[typ](rsrc)
        else
          WARNING("Missing resource type:%s",typ)
          return
        end
        resources[typ]=resources[typ] or {};
        resources[typ][id]=rsrc;
        id2resource[id]=rsrc
        rsrc:added()
      end
    end
    function self.modify(id,rsrc)
      assert(id2resource[id],"No resource for modify")
      id2resource[id]:modify(rsrc)
    end
    function self.delete(id)
      local rsrc=id2resource[id]
      assert(rsrc,"No resource")
      resources[rsrc.type][id]=nil
      rsrc:deleted()
      id2resource[id]=nil
    end
    function self.get(id) return id2resource[id] end
    return self
  end
  
  local function resolve(rr)
    return rr and resources.get(rr.rid) or 
    { subscribe=function() end, publishMySubs=function() end, publishAll=function() end } 
  end
  
  local function classs(name,parent)
    local p = class(name)
    local cl = _G[name]
    classes[name] = cl
    _G[name] = nil
    if parent then p(parent) end
    return cl
  end

  local hueResource = classs('hueResource')
  function hueResource:__init(rsrc) self:setup(rsrc) end
  
  function hueResource:setup(rsrc)
    local id = rsrc.id
    self.id = id
    for m,_ in pairs(self._inheritedFuns or {}) do self[m]=nil end
    self.rsrc = rsrc
    self.type = rsrc.type
    self.services = rsrc.services
    self.children = rsrc.children
    self.owner = rsrc.owner
    self.metadata = rsrc.metadata or {}
    self.product_data = rsrc.product_data or {}
    self.resourceType = self.product_data.model_id or self.metadata.archetype or "unknown"
    self.resourceName = self.product_data.product_name
    self.name = self.metadata.name
    self._inheritedFuns = {}
    self.path = "/clip/v2/resource/"..self.type.."/"..self.id
    self._inited = true
    self.listernes = {}
    self._props = props[self.type]
    self._meths = meths[self.type]
    DEBUG("class","Setup %s '%s' %s",self.id,self.type,self.name or "rsrc")
  end
  function hueResource:getName(dflt)
    if self.name then return self.name end
    local n = resolve(self.owner).name
    if n then self.name = n return n end
    return dflt
  end
  function hueResource:added() DEBUG('resource_mgmt',"Created %s",tostring(self)) end
  function hueResource:deleted() DEBUG('resource_mgmt',"Deleted %s",tostring(self)) end
  function hueResource:modified(rsrc) self:setup(rsrc) DEBUG('resource_mgmt',"Modified %s",tostring(self)) end
  function hueResource:findServiceByType(typ)
    local r = {}
    for _,s in ipairs(self.services or {}) do local x=resolve(s) if x.type==typ then r[#r+1]=x end end
    return r
  end
  function hueResource:getCommand(cmd)
    if self[cmd] then return self end
    for _,s in ipairs(self.services or {}) do
      local x=resolve(s)
      if x[cmd] then return x end
    end
  end
  
  function hueResource:getProps()
    local r,btns = {},0
    for _,s in ipairs(self.services or {}) do
      local r1 = resolve(s) or {}
      local ps = r1.getProps and r1:getProps() or {}
      merge(r,ps)
    end
    merge(r,self._props or {})
    return r
  end
  function hueResource:getMethods()
    local r = {}
    for _,s in ipairs(self.services or {}) do merge(r,resolve(s):getMethods()) end
    merge(r,self._meths or {})
    return r
  end
  function hueResource:event(data)
    DEBUG('event',"Event: %s",data)
    if self.update then self:update(data) return end
    local p = self._props -- { power_state = { get, set changed }, ...
    if p then
      local r = self.rsrc
      for k,f in pairs(p) do
        if data[k] and f.changed then
          local c,v = f.changed(r,data)
          if c then
            f.set(r,v)
            self:publish(k,v)
          end
        end
      end
    end
    if self.owner then
      local o = resolve(self.owner)
      if o._postEvent then o:_postEvent(self.id) end
    end
  end
  function hueResource:publishMySubs()
    local p = self._props -- { power_state = { get, set changed }, ...
    if p then
      local r = self.rsrc
      for k,f in pairs(p) do
        if r[k] then self:publish(k,f.get(r)) end
      end
    end
  end
  function hueResource:publishAll()
    if self.services then
      for _,s in ipairs(self.services or {}) do resolve(s):publishMySubs() end
    else
      self:publishMySubs()
    end
    if self._postEvent then self:_postEvent(self.id) end
  end
  function hueResource:publish(key,value)
    local ll = self.listernes[key] or {}
    if next(ll) then
      for l,_ in pairs(ll) do
        l(key,value,self)
      end
    end
  end
  
  function hueResource:subscribe(key,fun)
    if self.services then
      for _,s in ipairs(self.services or {}) do resolve(s):subscribe(key,fun) end
    elseif self._props and self._props[key] then
      self.listernes[key] = self.listernes[key] or {}
      self.listernes[key][fun]=true
    end
  end
  function hueResource:unsubscribe(key,fun)
    for _,s in ipairs(self.services or {}) do resolve(s):unsubscribe(key,fun) end
    if self.listernes[key] then
      if fun==true then self.listernes[key]={}
      else self.listernes[key][fun]=nil end
    end
  end
  function hueResource:sendCmd(cmd) return huePUT(self.path,cmd) end
  function hueResource:__tostring() return self._str or fmt("[rsrc:%s]",self.id) end
  function hueResource:annotateEvent(r)
    return setmetatable(r,{
      __tostring = function(r)
        return fmt("%s %s",r.type,self.name or r.id_v1 or "") 
      end
    })
  end
  -------
  
  local homekit = classs('homekit',hueResource)
  function homekit:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[homekit:%s]",self.id)
  end
  
  local device = classs('device',hueResource)
  function device:__init(id)
    hueResource.__init(self,id)
    self.archetype = self.rsrc.metadata.archetype
    self.name = self.name or "device"
    self._str = fmt("[device:%s,%s,%s]",self.id,self.name,self.resourceType)
  end
  
  local pprops = { color={"setColor"},color_temperature={"setTemperature"},dimming={"setDim"} }
  local function pruneLights(self)
    self._props = copyShallow(self._props)
    self._meths = copyShallow(self._meths)
    for p,m in pairs(pprops) do
      if self.rsrc[p]==nil then
        self._props[p]=nil
        for _,f in ipairs(m) do self._meths[f]=nil end
      end
    end
  end
  
  local light = classs('light',hueResource)
  function light:__init(id)
    hueResource.__init(self,id)
    self.archetype = resolve(self.owner).archetype or "unknown_archetype"
    pruneLights(self)
    self._str = fmt("[light:%s,%s,%s]",self.id,self:getName("LGHT"),self.resourceType)
  end
  function light:turnOn(transition) self:sendCmd({on={on=true},dynamics=transition and {duration=transition} or nil}) if OPTIMISTIC then self.rsrc.on.on = true end end
  function light:turnOff(transition) self:sendCmd({on={on=false},dynamics=transition and {duration=transition} or nil}) if OPTIMISTIC then self.rsrc.on.on = true end end
  function light:setDim(val,transition)
    if val == -1 then
      self:sendCmd({dimming_delta={action='stop'}})
    else
      self:sendCmd({dimming={brightness=val},dynamics=transition and {duration=transition} or nil})
    end
  end
  function light:setColor(arg,transition) -- {x=x,y=y} <string>, {r=r,g=g,b=b}
    local xy
    if type(arg)=='string' then
      xy = HUEv2Engine.xyColors[tostring(arg:lower())] or HUEv2Engine.xyColors['white']
    elseif type(arg)=='table' then
      if arg.x and arg.y then xy = arg
      elseif arg.r and arg.g and arg.b then
      end
    end
    if xy then self:sendCmd({color={xy=xy},dynamics=transition and {duration=transition} or nil}) end
  end
  function light:toggle(transition)
    local on = self.rsrc.on.on
    self:sendCmd({on={on=not on},dynamics=transition and {duration=transition} or nil})
    if OPTIMISTIC then self.rsrc.on.on = not on end
  end
  function light:rawCmd(cmd) self:sendCmd(cmd) end
  function light:setTemperature(t,transition) self:sendCmd({color_temperature={mirek=math.floor(t+0.5)},dynamics=transition and {duration=transition} or nil}) end
  meths.light = { turnOn=true, turnOff=true, setDim=true, setColor=true, setTemperature=true, toggle=true, rawCmd=true }
  props.light = {
    on={get=function(r) return r.on.on end,set=function(r,v) r.on.on=v end, changed=function(o,n) return o.on.on ~= n.on.on, n.on.on end },
    dimming={
      get=function(r) return r.dimming.brightness end,
      set=function(r,v) r.dimming.brightness=v end,
      changed=function(o,n) return o.dimming.brightness~=n.dimming.brightness,n.dimming.brightness end,
    },
    color_temperature={
      get=function(r) return r.color_temperature.mirek end,
      set=function(r,v) r.color_temperature.mirek=v end,
      changed=function(o,n) return n.color_temperature.mirek_valid and o.color_temperature.mirek~=n.color_temperature.mirek,n.color_temperature.mirek end,
    },
    color={
      get=function(r) return r.color.xy end,
      set=function(r,v) r.color.xy=v end,
      changed=function(o,n)
        local oxy,nxy = o.color.xy,n.color.xy
        return oxy.x~=nxy.x or oxy.y~=nxy.y,nxy
      end,
    },
  }
  
  props.zigbee_connectivity = {
    status={
      get=function(r) return r.status end,
      set=function(r,v) r.status=v end,
      changed=function(o,n) return o.status~=n.status,n.status end,
    },
  }
  local zigbee_connectivity = classs('zigbee_connectivity',hueResource)
  function zigbee_connectivity:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[zigbee_connectivity:%s,%s]",self.id,self:getName("CON"))
  end
  function zigbee_connectivity:connected()
    return self.rsrc.status=="connected"
  end
  
  props.device_power = {
    power_state={
      get=function(r) return r.power_state end,
      set=function(r,v) r.power_state=v end,
      changed=function(o,n) local s0,s1 = o.power_state,n.power_state return s0.battery_state~=s1.battery_state or s0.battery_level~=s1.battery_level,s1  end
    },
  }
  local device_power = classs('device_power',hueResource)
  function device_power:__init(id)
    hueResource.__init(self,id)
  end
  function device_power:power()
    return self.rsrc.power_state.battery_level,self.rsrc.power_state.battery_state
  end
  function device_power:__tostring()
    return fmt("[device_power:%s,%s,value:%s]",self.id,self:getName(),self:power())
  end
  function device_power:event(data)
    hueResource.event(self,data)
  end
  
  props.zgp_connectivity = {
    status={get=function(r) return r.status end,set=function(r,v) r.status=v end},
  }
  meths.zgp_connectivity = { connected=true }
  local zgp_connectivity = classs('zgp_connectivity',hueResource)
  function zgp_connectivity:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[zgp_connectivity:%s,%s]",self.id,self:getName("ZGP"))
  end
  function zgp_connectivity:connected()
    return self.rsrc.status=="connected"
  end
  
  local zigbee_device_discovery = classs('zigbee_device_discovery',hueResource)
  function zigbee_device_discovery:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[zigbee_device_discovery:%s,%s]",self.id,self:getName("ZDD"))
  end
  
  local device_software_update = classs('device_software_update',hueResource)
  function device_software_update:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[device_software_update:%s,%s]",self.id,self:getName("DSU"))
  end

  props.contact = {
    contact_report={
      get=function(r) return r.contact_report.state end,
      set=function(r,v) r.contact_report.state=v end,
      changed=function(o,n) return o.contact_report.state~=n.contact_report.state,n.contact_report.state end,
    },
  }
  local contact = classs('contact',hueResource)
  function contact:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[contact:%s,%s]",self.id,self:getName("CON"))
  end

  props.tamper = {
    tamper={
      get=function(r) return r.tamper_reports[1].state end,
      set=function(r,v) r.tamper_reports[1].state=v end,
      changed=function(o,n) return o.tamper[1].state~=n.tamper[1].state,n.tamper[1].state end,
    },
  }
  local tamper = classs('tamper',hueResource)
  function tamper:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[tamper:%s,%s]",self.id,self:getName("TAM"))
  end

  local matter = classs('matter',hueResource)
  function matter:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[matter:%s,%s]",self.id,self:getName("MATT"))
  end
  
  local entertainment = classs('entertainment',hueResource)
  function entertainment:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[entertainment:%s,%s]",self.id,self:getName("ENT"))
  end
  
  local entertainment_configuration = classs('entertainment_configuration',hueResource)
  function entertainment_configuration:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[entertainment_configuration:%s,%s]",self.id,self:getName("ENT_CFG"))
  end

  meths.room = { targetCmd=true }
  local room = classs('room',hueResource)
  function room:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[room:%s,%s,%s]",self.id,self.name,self.resourceType)
  end
  function room:setup(rsrc) hueResource.setup(self,rsrc) self.resourceName="Room" end
  function room:targetCmd(cmd)
    for _,s in ipairs(self.services or {}) do
      s = resolve(s)
      if s and s.type == 'grouped_light' then
        s:sendCmd(cmd)
      end
    end
  end
  
  meths.zone = { targetCmd=true }
  local zone = classs('zone',hueResource)
  function zone:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[zone:%s,%s,%s]",self.id,self.name,self.resourceType)
  end
  function zone:setup(rsrc) hueResource.setup(self,rsrc) self.resourceName="Zone" end
  function zone:targetCmd(cmd)
    for _,s in ipairs(self.services or {}) do
      s = resolve(s)
      if s and s.type == 'grouped_light' then
        s:sendCmd(cmd)
      end
    end
  end

  props.grouped_light = props.light
  meths.grouped_light = meths.light
  local grouped_light = classs('grouped_light',hueResource)
  function grouped_light:__init(id)
    hueResource.__init(self,id)
    pruneLights(self)
  end
  function grouped_light:__tostring() return fmt("[grouped_light:%s,%s]",self.id,self:getName("GROUP")) end
  function grouped_light:turnOn(transition) self:sendCmd({on={on=true},dynamics=transition and {duration=transition} or nil}) if OPTIMISTIC then self.rsrc.on.on = true end end
  function grouped_light:turnOff(transition) self:sendCmd({on={on=false},dynamics=transition and {duration=transition} or nil}) if OPTIMISTIC then self.rsrc.on.on = true end end
  function grouped_light:setDim(val,transition)
    if val == -1 then
      self:sendCmd({dimming_delta={action='stop'}})
    else
      self:sendCmd({dimming={brightness=val},dynamics=transition and {duration=transition} or nil})
    end
  end
  function grouped_light:setColor(arg,transition) -- {x=x,y=y} <string>, {r=r,g=g,b=b}
    local xy
    if type(arg)=='string' then
      xy = HUEv2Engine.xyColors[tostring(arg:lower())] or HUEv2Engine.xyColors['white']
    elseif type(arg)=='table' then
      if arg.x and arg.y then xy = arg
      elseif arg.r and arg.g and arg.b then
      end
    end
    if xy then self:sendCmd({color={xy=xy},dynamics=transition and {duration=transition} or nil}) end
  end
  function light:toggle(transition)
    local on = self.rsrc.on.on
    self:sendCmd({on={on=not on},dynamics=transition and {duration=transition} or nil})
    if OPTIMISTIC then self.rsrc.on.on = not on end
  end
  function light:rawCmd(cmd) self:sendCmd(cmd) end
  function grouped_light:setTemperature(t,transition) self:sendCmd({color_temperature={mirek=math.floor(t+0.5)},dynamics=transition and {duration=transition} or nil}) end
  
  meths.scene = { recall=true, targetCmd=true }
  local scene = classs('scene',hueResource)
  function scene:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[scene:%s,%s]",self.id,self.name)
  end
  function scene:recall(transition) self:sendCmd({recall = { action = "active",dynamics=transition and {duration=transition} or nil  }}) end
  function scene:targetCmd(cmd)
    if not self.rsrc.group then return end
    local zoneroom = resolve(self.rsrc.group)
    if not zoneroom then return end
    if zoneroom.targetCmd then zoneroom:targetCmd(cmd) end
  end

  props.button = {
    button = {
      get=function(r) if r.button then return r.button end end,
      set=function(r,v) if not r.button then r.button = { last_event = v } else r.button.last_event=v end end,
      changed=function(o,n)
        local ob,nb = o.button or {},n.button or {}
        return ob.last_event~=nb.last_event,nb.last_event
      end
    }
  }
  local button = classs('button',hueResource)
  function button:__init(id)
    hueResource.__init(self,id)
  end
  function button:button_state()
    return self.rsrc.button and self.rsrc.button.last_event,self.rsrc.metadata.control_id
  end
  function button:__tostring()
    return fmt("[button:%s,%s,value:%s]",self.id,self:getName("BTN"),self:button_state())
  end
  

  props.relative_rotary = {
    relative_rotary = {
      get=function(r) if r.relative_rotary then return r.relative_rotary.last_event end end,
      set=function(r,v) if not r.relative_rotary then r.relative_rotary = { last_event = v } else r.relative_rotary.last_event=v end end,
      changed=function(o,n)
        local ob,nb = o.relative_rotary or {},n.relative_rotary or {}
        return true,nb.last_event
      end
    }
  }
  local relative_rotary = classs('relative_rotary',hueResource)
  function relative_rotary:__init(id)
    hueResource.__init(self,id)
  end
  function relative_rotary:relative_rotary_state()
    local le = self.rsrc.relative_rotary and self.rsrc.relative_rotary.last_event
    if le then 
      return le.rotation.steps,le.rotation.direction 
    else return "N/A","N/A" end
  end
  function relative_rotary:__tostring()
    return fmt("[rotary:%s,%s,value:%s/%s]",self.id,self:getName("ROT"),self:relative_rotary_state())
  end
  
  props.temperature = {
    temperature={
      get=function(r) return r.temperature.temperature_report.temperature end,
      set=function(r,v) r.temperature.temperature_report.temperature=v end,
      changed=function(o,n) return o.temperature.temperature_report.temperature~=n.temperature.temperature_report.temperature,n.temperature.temperature_report.temperature end,
    },
  }
  
  local temperature = classs('temperature',hueResource)
  function temperature:__init(id)
    hueResource.__init(self,id)
  end
  function temperature:temperature()
    return self.rsrc.temperature.temperature_report.temperature
  end
  function temperature:__tostring()
    return fmt("[temperature:%s,%s,value:%s]",self.id,self:getName(),self:temperature())
  end
  
  props.motion = {
    motion={
      get=function(r) return r.motion.motion_report.motion end,
      set=function(r,v) r.motion.motion_report.motion=v end,
      changed=function(o,n) return o.motion.motion_report.motion~=n.motion.motion_report.motion,n.motion.motion_report.motion end
    },
  }
  local motion = classs('motion',hueResource)
  function motion:__init(id)
    hueResource.__init(self,id)
  end
  function motion:motion()
    return self.rsrc.motion.motion
  end
  function motion:__tostring()
    return fmt("[motion:%s,%s,value:%s]",self.id,self:getName(),self:motion())
  end
  
  props.camera_motion = {
    motion={
      get=function(r) return r.motion.motion_report.motion end,
      set=function(r,v) r.motion.motion_report.motion=v end,
      changed=function(o,n) return o.motion.motion_report.motion~=n.motion.motion_report.motion,n.motion.motion_report.motion end
    },
  }
  local camera_motion = classs('camera_motion',hueResource)
  function camera_motion:__init(id)
    hueResource.__init(self,id)
  end
  function camera_motion:motion()
    return self.rsrc.motion.motion_report.motion
  end
  function camera_motion:__tostring()
    return fmt("[camera_motion:%s,%s,value:%s]",self.id,self:getName(),self:motion())
  end

  props.light_level = {
    light={
      get=function(r) return r.light.light_level_report.light_level end,
      set=function(r,v) r.light.light_level_report.light_level=v end,
      changed=function(o,n) return o.light.light_level_report.light_level~=n.light.light_level_report.light_level,n.light.light_level_report.light_level end,
    },
  }
  local light_level = classs('light_level',hueResource)
  function light_level:__init(id)
    hueResource.__init(self,id)
  end
  function light_level:light_level()
    return self.rsrc.light.light_level_report.light_level
  end
  function light_level:__tostring()
    return fmt("[light_level:%s,%s,value:%s]",self.id,self:getName(),self:light_level())
  end
  
  local bridge = classs('bridge',hueResource)
  function bridge:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[bridge:%s]",self.id)
  end
  
  local bridge_home = classs('bridge_home',hueResource)
  function bridge_home:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[bridge_home:%s]",self.id)
  end
  
  local behavior_script = classs('behavior_script',hueResource)
  function behavior_script:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[behavior_script:%s,%s,%s]",self.id,self.rsrc.metadata.name,self.rsrc.metadata.category)
  end
  
  local behavior_instance = classs('behavior_instance',hueResource)
  function behavior_instance:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[behavior_instance:%s,%s,%s]",self.id,self.rsrc.metadata.name,self.rsrc.metadata.category)
  end
  
  local geolocation = classs('geolocation',hueResource)
  function geolocation:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[geolocation:%s]",self.id)
  end
  
  local geofence_client = classs('geofence_client',hueResource)
  function geofence_client:__init(id)
    hueResource.__init(self,id)
    self._str = fmt("[geofence_client:%s]",self.id)
  end
  
  local fetchEvents
  local function handle_events(data)
    for _,e1 in ipairs(data) do
      if e1.type=='update' then
        for _,r in ipairs(e1.data) do
          local d = resources.get(r.id)
          if d and d.event then
            DEBUG('all_event',"Event id:%s type:%s",d.id,d.type)
            d:annotateEvent(r)
            d:event(r)
          else
            local _ = 0
            if debug.unknownType then WARNING("Unknow resource type: %s",json.encode(e1)) end
          end
        end
      elseif e1.type == 'delete' then
        for _,r in ipairs(e1.data) do
          resources.changeHook()
          resources.delete(r.id)
        end
      elseif e1.type == 'add' then
        for _,r in ipairs(e1.data) do
          resources.changeHook()
          resources.add(r.id,r)
        end
      else
        DEBUG('v2api',"New v2 event type: %s",e1.type)
        DEBUG('v2api',"%s",json.encode(e1))
      end
    end
  end
  
  local function fetchEvents_emu()
    local getw
    local eurl = url.."/eventstream/clip/v2"
    local args = { options = { 
      method='GET', 
      checkCertificate=false, 
      headers={ 
        ['hue-application-key'] = app_key,
        ['Accept'] = "application/json",
    }}}
    function args.success(res)
      local data = json.decode(res.data)
      handle_events(data)
      getw()
    end
    function args.error(err) if err~="timeout" and err~="wantread" then ERROR("/eventstream: %s",err) end getw() end
    function getw() net.HTTPClient():request(eurl,args) end
    setTimeout(getw,0)
  end
  
  local function fetchEvents_hc3()
    local getw
    local eurl = url.."/eventstream/clip/v2"
    local args = {
      options = { 
        method='GET', 
        checkCertificate=false,
        headers={
          ["hue-application-key"] = app_key, 
          ['Accept'] = "text/event-stream" 
        },
        timeout = 2000 
      }
    }
    function args.success(res)
      local stat,res = pcall(function()
        if res.data:match("^: hi") then res.data="[]"
        else res.data = res.data:match("(%b[])") end
        local data = json.decode(res.data)
        handle_events(data)
      end)
      if not stat then print("ERR",res) getw() end
    end
    function args.error(err) if err~="timeout" and err~="wantread" then ERROR("/eventstream: %s",err) end getw() end
    function getw() net.HTTPClient():request(eurl,args) end
    setTimeout(getw,0)
  end
  
  if fibaro.fibemu then fetchEvents = fetchEvents_emu
  else fetchEvents = fetchEvents_hc3 end
  
  function hueGET(api,event)
    local u = url..api
    net.HTTPClient():request(u,{
      options = { 
        method='GET',
        checkCertificate=false, 
        headers={ 
          ['hue-application-key'] = app_key,
          ["Accept"] = "application/json",
        }
      },
      success = function(res) 
        if res.status < 300 then
          post({type=event,result=json.decode(res.data)}) 
        else
          post({type=event,error=res.status}) 
        end
      end,
      error = function(err) post({type=event,error=err})  end,
    })
  end
  
  function huePUT(path,data,op)
    DEBUG('call',"%s %s",path,json.encode(data))
    net.HTTPClient():request(url..path,{
      options = {
        method=op or 'PUT', 
        data=data and json.encode(data) or nil,
        checkCertificate=false, 
        ['content-type']="application/json",
        headers={ ['hue-application-key'] = app_key }
      },
      success = function(resp)
        local b = resp
      end,
      error = function(err,f,g)
        ERROR("hue call, %s %s - %s",path,json.encode(data),err)
      end,
    })
  end
  
  --[[
  {
    "dimming":{"brightness":58.66}, // color,color_temperature,on
    "owner":{"rtype":"device","rid":"8dddf049-0a73-44e2-8fdd-e3c2310c1bb1"},
    "type":"light",
    "id_v1":"/lights/5",
    "id":"fb31c148-177b-4b52-a1a5-e02d46c1c3dd"
  }
  
  {
    "id_v1":"/groups/5",
    "type":"grouped_light",
    "on":{"on":true},
    "id":"39c94b33-7a3d-48e7-8cc1-dc603d401db2"
  }
  
  {
    "id":"efc3283b-304f-4053-a01a-87d0c51462c3",
    "owner":{"rtype":"device","rid":"a007e50b-0bdd-4e48-bee0-97636d57285a"},
    "button":{"last_event":"initial_press"}, // "repeat","long_release","short_release"
      "id_v1":"/sensors/2",
      "type":"button"
    }
    
    {
      "type":"light_level",
      "light":{"light_level":0,"light_level_valid":true},
      "owner":{"rtype":"device","rid":"9222ea53-37a6-4ac0-b57d-74bca1cfa23f"},
      "id_v1":"/sensors/7",
      "id":"a7295dae-379b-4d61-962f-6f9ad9426eda"
    }
    
    {
      "type":"motion",
      "motion":{"motion":false,"motion_valid":true},
      "owner":{"rtype":"device","rid":"9222ea53-37a6-4ac0-b57d-74bca1cfa23f"},
      "id_v1":"/sensors/6","id":"6356a5c3-e5b7-455c-bf54-3af2ac511fe6"
    }
    
    {
      "type":"device_power",
      "power_state":{"battery_state":"normal","battery_level":76},
      "owner":{"rtype":"device","rid":"a007e50b-0bdd-4e48-bee0-97636d57285a"},
      "id_v1":"/sensors/2",
      "id":"d6bc1f77-4603-4036-ae5f-28b16eefe4b5"
    }
    
    {
      "type":"zigbee_connectivity",
      "owner":{"rtype":"device","rid":"3ab27084-d02f-44b9-bd56-70ea41163cb6"},
      "status":"connected",  // "status":"connectivity_issue"
      "id_v1":"/lights/9",
      "id":"c024b020-395d-45a4-98ce-9df1409eda30"
    }
    --]]
    
    ---------------------------------------------------------------------------
    
    fibaro.event({type='STARTUP'},function(_) hueGET("/api/config",'HUB_VERSION') end)
    
    fibaro.event({type='HUB_VERSION'},function(ev)
      if ev.error then
        ERROR("%s",ev.error)
      else
        resources = createResourceTable()
        local res = ev.result
        if res.swversion >= v2 then
          DEBUG('info',"V2 api available (%s)",res.swversion)
          post({type='REFRESH_RESOURCES'})
        else
          WARNING("V2 api not available (%s)",res.swversion)
        end
      end
    end)
    
    fibaro.event({type='REFRESH_RESOURCES'},function(_) hueGET("/clip/v2/resource",'REFRESHED_RESOURCES') end)
    
    fibaro.event({type='REFRESHED_RESOURCES'},function(ev)
      if ev.error then
        ERROR("/clip/v2/resource %s",ev.error)
        ERROR("Retry in %ss",err_retry)
        post({type='REFRESH_RESOURCES'},1000*err_retry)
        return
      end
      for _,r in pairs(resources.id2resource) do
        r._dirty = true
      end
      for _,r in ipairs(ev.result.data or {}) do
        r._dirty=nil
        resources.add(r.id,r)
      end
      for _,r in pairs(resources.id2resource) do
        if r._dirty then
          resources.delete(r.id)
        end
      end
      local cb
      if callBack then cb,callBack=callBack,nil setTimeout(cb,0) end
    end)
    
    function HUEv2Engine:getResources() return resources.resources end
    function HUEv2Engine:getResourceIds() return resources.id2resource end
    function HUEv2Engine:getResource(id) return resources.id2resource[id] end
    function HUEv2Engine:getResourceType(typ) return resources.resources[typ] or {} end
    function HUEv2Engine:_resolve(id) return resolve(id) end
    function HUEv2Engine:getSceneByName(name,roomzone)
      local scenes = self:getResourceType('scene')
      for id,scene in pairs(scenes) do
        if scene.name == name then
          if not roomzone then return scene end
          local g = scene.rsrc.group and resolve(scene.rsrc.group) or {}
          if g.name == roomzone then return scene end
        end
      end
    end
    local filter1 = { device=1, scene=10, room=2, zone=3 }
    
    local filter2 = { device=1, light=4, button=5, relative_rotary=5.5, scene=10, room=2, zone=3, temperature=6, light_level=7, motion=8, tamper=7.5, contact=7.6, grouped_light=9, zigbee_connectivity=10, device_power=11 }
    
    local function printBuffer(init) 
      local b = {init}
      function b:add(s) b[#b+1]=s end
      function b:printf(fmt,...) b:add(fmt:format(...)) end
      function b:tostring() return table.concat(b) end
      return b
    end
    fibaro.printBuffer = printBuffer

    function HUEv2Engine:dumpDeviceTable(filter,selector,orgDevMap)
      filter =filter and filter2 or filter1
      orgDevMap = orgDevMap or {}
      selector = selector or function() return true end
      local  pb = printBuffer("\n")
      pb:add("\nlocal HueDeviceTable = {\n")
      local rs = {}
      for _,r in pairs(HUEv2Engine:getResourceIds()) do
        if filter[r.type] then
          rs[#rs+1]={order=filter[r.type],str=tostring(r),r=r}
        end
      end
      local parentMap = {room={},zone={}}
      for _,r0 in ipairs(rs) do
        local r = r0.r
        if r.type=='room' or r.type=='zone' then
          for _,c in ipairs(r.children) do
            parentMap[r.type][c.rid]=r.name
          end
        end
      end
      table.sort(rs,function(a,b) return a.order < b.order or a.order==b.order and a.str < b.str end)
      for _,r0 in ipairs(rs) do
        local r = r0.r
        local room = parentMap.room[r.id]
        local zone = parentMap.zone[r.id]
        local ref = (orgDevMap[r.id] or {}).ref
        room=room and (",room='"..room.."'") or ""
        zone=zone and (",zone='"..zone.."'") or ""
        ref=ref and (",ref='"..ref.."'") or ""
        if r.type=='scene' then
          room = (",room='"..resolve(r.rsrc.group).name.."'")
        end
        pb:printf("%s['%s']={type='%s',name='%s',model='%s'%s%s%s},\n",selector(r.id) and "  " or "--",r.id,r.type,r.name,r.resourceType,room,zone,ref)
      end
      pb:add("}\n")
      print(pb:tostring())
    end
    
    function HUEv2Engine:createDeviceTable(filter)
      filter =filter and filter2 or filter1
      local rs,rs2,res = HUEv2Engine:getResourceIds(),{},{}
      
      local parentMap = {room={},zone={}}
      for uid,r in pairs(rs) do
        if filter[r.type] then
          rs2[uid]=r
          if r.type=='room' or r.type=='zone' then
            for _,c in ipairs(r.children) do
              parentMap[r.type][c.rid]=r.name
            end
          end
        end
      end
      for uid,r in pairs(rs2) do
        local m = {}
        res[uid]=m
        m.room = parentMap.room[r.id]
        m.zone = parentMap.zone[r.id]
        if r.type=='scene' then
          m.room = resolve(r.rsrc.group).name
        end
        m.type=r.type
        m.name=r.name
        m.model=r.resourceType
        m.props=strip(r:getProps())
        local btns=0
        if r.services then
          for _,s in ipairs(r.services) do
            btns = btns + (s.rtype=='button' and 1 or 0)
          end
        end
        m.buttons=btns
      end
      return res
    end
    
    local function sortResources(list,f)
      local rs = {}
      for _,r in pairs(list) do
        r = f and f(r) or r
        if filter2[r.type] then
          rs[#rs+1]={order=filter2[r.type],resource=r}
        end
      end
      table.sort(rs,function(a,b) return a.order < b.order or a.order==b.order and a.resource.id < b.resource.id end)
      local r0 = {}
      for _,r in ipairs(rs) do r0[#r0+1]=r.resource end
      return r0
    end
    
    local function printResource(r,pb,ind)
      pb:add(string.rep(' ',ind)..tostring(r).."\n")
      if r.owner then pb:add(string.rep(' ',ind+2).."Parent:"..r.owner.rid.."\n") end
      local rs = r.children and sortResources(r.children,function(r) return resolve(r) end) or {}
      if rs[1] then
        pb:add(string.rep(' ',ind+2).."Children:\n")
        for _,c in ipairs(rs) do
          printResource(c,pb,ind+4)
        end
      end
      rs = r.services and sortResources(r.services,function(r) return resolve(r) end) or {}
      if rs[1] then
        pb:add(string.rep(' ',ind+2).."Services:\n")
        for _,c in ipairs(rs) do
          printResource(c,pb,ind+4)
        end
      end
      if r.rsrc.actions then
        local w = resolve(r.rsrc.group)
        pb:add(string.rep(' ',ind+2).."Group:"..tostring(w).."\n")
        pb:add(string.rep(' ',ind+2).."Targets:\n")
        for _,a in ipairs(r.rsrc.actions or {}) do
          local f = resolve(a.target)
          pb:add(string.rep(' ',ind+4)..tostring(f).."\n")
        end
      end
    end
    
    function HUEv2Engine:listAllDevicesGrouped(groups)
      local  pb = printBuffer("\n")
      pb:add("------------------------\n")
      local rs = sortResources(HUEv2Engine:getResourceIds())
      for _,r in ipairs(rs) do if not r.owner then printResource(r,pb,0) end end
      pb:add("------------------------\n")
      print(pb:tostring():gsub("\n","</br>"):gsub("%s","&nbsp;"))
    end
    
    function _initEngine(ip,key,cb)
      app_key = key
      url =  fmt("https://%s:443",ip)
      DEBUG('info',"HUEv2Engine v%s",version)
      DEBUG('info',"Hub url: %s",url)
      callBack = function() fetchEvents() if cb then cb() end end
      post({type='STARTUP'})
    end
    
  end -- main()
  
  function HUEv2Engine:init(ip,key,cb) 
    setup() 
    main() 
    _initEngine(ip,key,cb)
  end

------- QAs/HueV2App.lua ----------
fibaro.debugFlags = fibaro.debugFlags or {}
local HUE

local _version = 0.52
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
  --print(json.encode(childDevices))
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
    local props = self.dev:getProps()
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
    if self.properties.userDescription == nil or self.properties.userDescription == "" then
      local fmt = string.format
      local d = fmt("%s\n%s",self.dev.type,self.dev.id)
      print(d)
      if self.dev.product_data then
        local pd = self.dev.product_data
        d = d..fmt("\n%s\n%s",pd.product_name or "",pd.model_id or "")
      end
      self:updateProperty("userDescription",d)
    end
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

      -- Check room/zone dead status
      local statuses = {}
      for _,c in pairs(self.dev.children or {}) do
        c = HUE:_resolve(c)
        if c.type ~= 'device' then
          c = HUE:_resolve(c.owner)
        end
        local props = c:getProps()
        if props.status then
          statuses[c.id] = true
          c = HUE:getResource(c.id)
          c:subscribe("status",function(key,value,b)
            statuses[b.id] = value == 'connected'
            local stat = true
            for _,s in pairs(statuses) do stat=stat and s end
            self:updateProperty("dead",not stat)
            self:print("status %s",stat)
          end)
          local c0 = c
          setTimeout(function() 
            c0:publishAll() 
          end,0)
        end
      end

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
      self:setVariable("scene",event)
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
