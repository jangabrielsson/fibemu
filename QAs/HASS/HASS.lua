--[[
HASS integration QA for the Fibaro Home Center 3
Copyright (c) 2025 Jan Gabrielsson
Email: jan@gabrielsson.com
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.
--]]

---@diagnostic disable: undefined-field
--%%name=HASS
--%%type=com.fibaro.deviceController
--%%proxy="HASSProxy2"
--%%var=url:config.HASS_url
--%%var=token:config.HASS_token
--%%var=auto:"true"
--%%clobber=token
--%%var=debug:"main,wsc,child,color,battery,speaker,send,late"

--%%file=lib/QwikChild.lua,QC;
--%%file=QAs/HASS/Utils.lua,utils;
--%%file=QAs/HASS/Classes.lua,classes;
--%%file=lib/BetterQA.lua,BQA;
--%%file=QAs/HASS/Config.lua,config;
--%% file=QAs/HASS/User.lua,User;

--%%u={label="title",text="Label (Title)"}
--%%u={label="label_ID_2",text="QuickAppChildren:"}
--%%u={select="qaSelect",text="QuickAppChild",visible=true,onToggled="qaSelected",options={}}
--%%u={select="classSelect",text="Class",visible=true,onToggled="classSelected",options={}}
--%%u={label="qaInfo",text="QA info"}
--%%u={multi="entitySelect",text="Entities",visible=true,onToggled="entitySelected",options={}}
--%%u={{button="buttonA",text="Create",visible=true,onLongPressDown="",onLongPressReleased="",onReleased="buttonA"},{button="buttonB",text="Entity info",visible=true,onLongPressDown="",onLongPressReleased="",onReleased="buttonB"}}
--%%u={{button="syncStates",text="Resync",visible=true,onLongPressDown="",onLongPressReleased="",onReleased="syncStates"},{button="restart",text="Restart",visible=true,onLongPressDown="",onLongPressReleased="",onReleased="restart"},{button="dump",text="Dump config",visible=true,onLongPressDown="",onLongPressReleased="",onReleased="dumpConfig"}}
--%%u={label="logLabel",text=""}

--%%debug=refresh:false

local VERSION = "0.72"
local fmt = string.format
local token,URL
local dfltDebugFlags = "child"
local MessageHandler = {}
local entityFilter = HASS.createEntityFilter()
HASS = HASS or {}
HASS.classes = HASS.classes or {}
HASS.entities = HASS.entities or {}
HASS.customTypes = HASS.createKeyList()
HASS.entityFilter = entityFilter
local skippedEntities = {}

--[[---------------------------------------------------------
MessageHandler.
Receives incoming messages from the websocket and dispatches
to Entity objects that sends the state changes on to subscribing child QAs
--------------------------------------------------------------]]
function MessageHandler.auth_required(data,ws)
  DEBUGF('test',"Websocket auth reqired")
  ws:sendRaw({type= "auth",access_token = token})
end
function MessageHandler.auth_ok(data,ws)
  DEBUGF('test',"Websocket auth OK")
  quickApp:authenticated()
end

function MessageHandler.event(data,ws)
  local data = data.event.data
  local entity_id = data.entity_id
  DEBUGF('event',"Event %s",entity_id)
  local entity = HASS.entities[entity_id]
  if entity then entity:change(data.new_state,data.old_state)
  elseif skippedEntities[entity_id] then
    DEBUGF('event',"Ignoring %s",entity_id)
  else -- late entity after a HASS restart? or an newly entity created
    DEBUGF("late","Late entity %s",entity_id)
    local stat,entity = pcall(Entity,data.new_state)
    if not stat then 
      ERRORF("Error creating entity %s",entity_id)
    else
      HASS.entities[entity_id] = entity
    end
  end
end

--[[---------------------------------------------------------
Main QuickApp.
Sets up variables and creates the websocket connection.
Flow continues in authenticated() when the websocket is authenticated.
--------------------------------------------------------------]]
function QuickApp:onInit()
  printc("yellow","%s v:%s",self.name,VERSION)
  self:updateView("title","text",self.name.." v:"..VERSION)
  self:setupUIhandler()

  local modules = {} -- Load user modules alphabetically...
  for name,fun in pairs(_G) do
    if name:match("^MODULE_") and type(fun) == 'function' then
      modules[#modules+1] = {fun=fun,name=name}
    end
  end
  table.sort(modules,function(a,b) return a.name < b.name end)
  for _,mod in ipairs(modules) do
    local stat,err = PCALL(mod.fun)
    if not stat then ERRORF("Error in module %s: %s",mod.name,err) end
   end

  local dflags = self.qvar.debug or dfltDebugFlags
  for _,f in ipairs(dflags:split(",")) do fibaro.debugFlags[f] = true end
  -- fibaro.debugFlags.main = true
  -- fibaro.debugFlags.wsc = true    -- websocket states
  -- fibaro.debugFlags.child = true  -- Generic Child qa debug
  -- fibaro.debugFlags.color = true  -- Color light debugging
  -- fibaro.debugFlags.event = true  -- Logs all events from HASS

  token,URL = self.qvar.token,self.qvar.url
  if not(token and URL) then
    self:warning("Please set URL and token")
    return
  end

---@diagnostic disable-next-line: undefined-global
  local WS = WSConnection(URL,token)
  self.WS = WS
  function WS:msgHandler(data)
    local f = MessageHandler[data.type]
    if f then f(data,self) else print(json.encode(data)) end
  end
  WS:connect()
end

local climate = json.decode([[{
        "entity_id": "climate.bedroom",
        "state": "off",
        "attributes": {
            "hvac_modes": [
                "cool",
                "heat",
                "dry",
                "heat_cool",
                "fan_only",
                "off"
            ],
            "min_temp": 17,
            "max_temp": 30,
            "target_temp_step": 1,
            "fan_modes": [
                "quiet",
                "low",
                "medium",
                "medium_high",
                "high",
                "auto",
                "strong"
            ],
            "swing_modes": [
                "stopped",
                "fixedtop",
                "fixedmiddletop",
                "fixedmiddle",
                "fixedmiddlebottom",
                "fixedbottom",
                "rangefull"
            ],
            "current_temperature": 19.3,
            "temperature": 22,
            "current_humidity": 54.2,
            "fan_mode": "auto",
            "swing_mode": "stopped",
            "friendly_name": "Bedroom",
            "supported_features": 425
        },
        "last_changed": "2025-01-15T07:41:04.434429+00:00",
        "last_reported": "2025-01-15T16:01:10.388966+00:00",
        "last_updated": "2025-01-15T16:01:10.388966+00:00",
        "context": {
            "id": "01JHNB4ZQMHP2RW0YB085X2SYX",
            "parent_id": null,
            "user_id": null
        }
    }]])

function QuickApp:authenticated() -- Called when websocket is authenticated
  DEBUGF('main',"Fetching HASS entities")
  self.WS:send({type= "get_states"},function(data)
    data = data.result
    local entities = HASS.entities
    DEBUGF('main',"...fetched %d entities",#data)
    -- table.insert(data,1,climate)
    for _,e in ipairs(data) do
      if not entityFilter:skip(e) then
        local entity = Entity(e)
        entities[e.entity_id] = entity
      else 
        DEBUGF('main',"Skipping %s",e.entity_id)
        skippedEntities[e.entity_id] = true
      end
    end
    self._initialized = true
    local children = self:getChildrenUidMap()
    self:loadExistingChildren(children)
    self.WS:send({type= "subscribe_events",event_type= "state_changed"})
    self:loadDefinedQAs()
    self:loadAuto()
    children = self:getChildrenUidMap()
    self:populatePopup(children)
    --self:notify("HASS QA","Connected")
  end)
end

local logTimer = nil
function QuickApp:log(str)
  if logTimer then clearTimeout(logTimer) end
  logTimer = self:updateView("logLabel","text",str)
  setTimeout(function() self:updateView("logLabel","text","") end,5000)
end

local n = 0
function QuickApp:newUID() n=n+1 return "uuid"..os.time().."_"..n end

function QuickApp:notify(title,msg)
  if not self._initialized then return end
  self.WS:serviceCall('notify','notify',{title=title,message=msg})
end

function QuickApp:loadAuto()
  for className,d in pairs(HASS.classes) do
    if d.auto then
      local types = type(d.auto) == 'string' and {d.auto} or d.auto
      for _,typ in ipairs(types) do
        self:loadAutoAux(className,typ)
      end
    end
  end
end

function QuickApp:loadAutoAux(className,typ)
  for _,entity in ipairs(HASS.getEntitiesOfType(typ)) do
    local auid = "auto_"..entity.id
    if not self.children[auid] then
      DEBUGF('main',"Auto creating %s QA for %s",className,entity.id)
      local name = HASS.nameNewQA(entity.name)
      local uid = auid
      local entities = {entity.id}
      local room = HASS.defaultRoom
      self:newChildQA(uid,name,room,entities,className)
    end
  end
end

function QuickApp:loadDefinedQAs()
  for className,cls in pairs(HASS.classes) do
    if cls.qa then
      for uid,qa in pairs(cls.qa) do
        if not self.children[uid] then
          local entities = qa.entities or {}
          if not HASS.isEntity(entities) then
            ERRORF("Entity(s) %s not found for defined QA %s",json.encode(entities),uid)
          elseif #entities==0 then
            ERRORF("No entities for defined QA %s",uid)
          else
            DEBUGF('main',"Creating defined QA %s",uid)
            local name = qa.name or HASS.nameNewQA(HASS.entities[entities[1]].name)
            local room = qa.room or HASS.defaultRoom
            self:newChildQA(uid,name,room,entities,className)
          end
        end
      end
    end
  end
end

function QuickApp:populatePopup(children)
  local options = {}
  for uid,d in pairs(children) do
    local c = self.childDevices[d.id]
    options[#options+1] = {text=c.id.." "..c.name,type="option",value=tostring(c.id)}
  end
  table.sort(options,function(a,b) return a.text < b.text end)
  table.insert(options,1,{text="<New QA>",type="option",value="new"})
  self:updateView("qaSelect","options",options)

  local classes = {}
  for name,cls in pairs(HASS.classes) do
    classes[#classes+1] = {text=name,type="option",value=name}
  end
  table.sort(classes,function(a,b) return a.text < b.text end)
  self:updateView("classSelect","options",classes)

  local entities = {}
  for id,entity in pairs(HASS.entities) do
    local kn = tostring(entity):sub(2,-2)
    entities[#entities+1] = {text=kn,type="option",value=id}
  end
  table.sort(entities,function(a,b) return a.text < b.text end)
  self:updateView("entitySelect","options",entities)
  self:updateView("entitySelect","selectedItems",{})
end

local buttonState = "create"
local selectedQA = nil
local selectedClass = nil
local selectedEntities = {}
local firstEntity = nil

function QuickApp:qaSelected(data)
  local val = tonumber(data.values[1])
  if val then -- existing child
    local child = self.childDevices[val]
    selectedQA = child
    selectedClass = child._className
    local values = {}
    for id,entity in pairs(child.entities) do
      values[#values+1] = id
    end
    selectedEntities = values
    self:updateQAinfo()
    self:updateView("entitySelect","selectedItems",values)
    self:updateView("buttonA","text","Update")
    self:updateView("buttonB","text","Delete")
    buttonState = "update"
  else                                        -- new child
    self:updateView("buttonA","text","Create")
    self:updateView("buttonB","text","Info")
    self:updateView("entitySelect","selectedItems",{})
    selectedEntities = {}
    selectedQA = nil
    buttonState = "create"
    self:updateQAinfo()
  end
end

function QuickApp:updateQAinfo()
  local buff = string.buff()
  if selectedQA then
    buff.printf("DeviceID: %s, Name: %s\n",selectedQA.id,selectedQA.name)
  else buff.printf("[New QA]\n") end
  buff.printf("Type: %s\n",selectedClass and HASS.classes[selectedClass].type or "[None]")
  buff.printf("Class: %s\n",selectedClass or "[None]")
  if selectedEntities then
    for i,entity_id in ipairs(selectedEntities) do
      local entity = HASS.entities[entity_id] or entity_id
      buff.printf("Entity%s:  %s\n",i,tostring(entity))
    end
  end
  self:updateView("qaInfo","text",buff.tostring())
end

function QuickApp:classSelected(data)
  selectedClass = data.values[1]
  self:updateQAinfo()
end

function QuickApp:entitySelected(data)
  selectedEntities = data.values[1]
  if #selectedEntities == 0 then firstEntity = nil
  elseif #selectedEntities == 1 then
    firstEntity = HASS.entities[selectedEntities[1]]
  end
  self:updateQAinfo()
end

------------------------------------------------------------
function QuickApp:buttonA()
  if buttonState == "create" then self:createQA()
  else self:updateQA() end
end

function QuickApp:buttonB()
  if buttonState == "create" then self:showEntities()
  else self:deleteQA() end
end

local n = 0
function QuickApp:createQA()
  if not selectedClass then return end
  local entities = selectedEntities or {}
  n=n+1
  local uid = self:newUID()
  local name = HASS.nameNewQA(firstEntity and firstEntity.name or "New QA")
  local room = HASS.defaultRoom
  self:newChildQA(uid,name,room,entities,selectedClass)
end

local rooms = {}
for _,room in ipairs(api.get("/rooms") or {}) do
  rooms[room.name] = true
  rooms[room.id] = true
end

function QuickApp:newChildQA(uid,name,room,entity_ids,className)
  local cls = HASS.classes[className]
  if room and not rooms[room] then
    WARNINGF("Room %s not found",room)
    room = nil
  end
  local found = false
  for _,id in ipairs(entity_ids) do
    local entity = HASS.entities[id]
    if entity and entity.type == 'sensor_battery' then found=true break end
  end

  local props = {
    name = name,
    type = cls.type,
    properties = cls.properties or {},
    interfaces = cls.interfaces or {},
    store = { entities = entity_ids },
    room = room,
  }

  local UI = cls.UI

  if cls.modify then 
    -- Custom modification of properties and interfaces
    -- Ex. to add a custom UI depending on the entities
    props = cls.modify(table.copy(props)) 
  end
  return self:createChild(uid,props,className,UI)
end

function QuickApp:updateQA()
  if selectedQA then
    selectedQA:setEntities(selectedEntities or {})
  end
  self:restart()
end

function QuickApp:deleteQA()
  if selectedQA then
    self:removeChildDevice(selectedQA.id)
    setTimeout(function() self:restart() end,1000)
  end
end

function QuickApp:showEntities()
  printf("Entities:")
  for _,id in ipairs(selectedEntities or {}) do
    local entity = HASS.entities[id] or id
    printf("%s",tostring(entity))
    if type(id) ~= 'string' then
      for k,v in pairs(entity.attributes) do
        printf("- %s: %s",k,json.encode(v))
      end
    end
  end
end

function QuickApp:deleteAllChildren()
  local children = api.get("/devices?parentId="..self.id) or {}
  for _,child in ipairs(children) do
    local a,b = api.delete("/plugins/removeChildDevice/" .. child.id)
    a=b
  end
  self:restart()
end

function QuickApp:syncStates()
  DEBUGF('main',"Fetching HASS entity states")
  self.WS:send({type= "get_states"},function(data)
    data = data.result
    local entities = HASS.entities
    DEBUGF('main',"...fetched %d entities",#data)
    for _,e in ipairs(data) do
      if HASS.entities[e.entity_id] then
        HASS.entities[e.entity_id]:change(e,e)
      end
    end
    DEBUGF('main',"...synched",#data)
  end)
end

function QuickApp:dumpConfig()
  DEBUGF('main',"Dumping config")
end

function QuickApp:restart() plugin.restart() end