fibaro.debugFlags = fibaro.debugFlags or {}

local oldPrint = print
local jsonEncode = json.encode
local fmt = string.format
local debugFlags = fibaro.debugFlags
local inhibitPrint = {['onAction: ']='onaction', ['UIEvent: ']='uievent'}

local function setDefaults(flag,value)
  if debugFlags[flag]==nil then debugFlags[flag]=value end
end

setDefaults('html',true)

function print(a,...)
  a = a == nil and "" or a
  if not inhibitPrint[a] or debugFlags[inhibitPrint[a]] then
    oldPrint(a,...) 
  end
end

local htmlCodes={['\n']='<br>', [' ']='&nbsp;'}
local function fix(str) return str:gsub("([\n%s])",function(c) return htmlCodes[c] or c end) end
local function htmlTransform(str) -- Avoid transforming inside html tags <
  local hit = false
  str = str:gsub("([^<]*)(<.->)([^<]*)",function(s1,s2,s3) hit=true
      return (s1~="" and fix(s1) or "")..s2..(s3~="" and fix(s3) or "")
    end)
  return hit and str or fix(str)
end

local function encodeObject(t)
  if type(t)~='table' then return tostring(t) end
  local mt = getmetatable(t)
  if mt and mt.__tostring then return tostring(t)
  else return jsonEncode(t) end
end

local function fformat(str,...)
  jsonEncode = table.encode or json.encode
  local args = {...}
  if #args == 0 then return tostring(str) end
  for i,v in ipairs(args) do if type(v)=='table' then args[i]=encodeObject(v) end end
  return fmt(str,table.unpack(args))
end
string.fformat = fformat

local function arr2str(del,...)
  local args = {...}
  for i=1,#args do if args[i]~=nil then args[#args+1]=encodeObject(args[i]) end end 
  return table.concat(args,del)
end 

local function print_debug(typ,tag,str)
  local m,s=str:match("^##(%d)(.*)") -- truncate output
  if m then 
    str=s
    local sl,ml = str:len()-3,tonumber(m)
    if ml and sl > ml then str=str:sub(1,ml).."..." end
  end
  if debugFlags.html then str = htmlTransform(str) end
  __fibaro_add_debug_message(tag or __TAG, str, typ)
  return str
end

function fibaro.debug(tag,...) 
  return print_debug('debug',tag,arr2str(" ",...))
end
function fibaro.trace(tag,a,...)
  return print_debug('trace',tag,arr2str(" ",a,...)) 
end
function fibaro.error(tag,...)
  return print_debug('error',tag,arr2str(" ",...))
end
function fibaro.warning(tag,...) 
  return print_debug('warning',tag,arr2str(" ",...))
end
function fibaro.debugf(tag,fmt,...) 
  return print_debug('debug',tag,fformat(fmt,...)) 
end
function fibaro.tracef(tag,fmt,...) 
  return print_debug('trace',tag,fformat(fmt,...)) 
end
function fibaro.errorf(tag,fmt,...)
  return print_debug('error',tag,fformat(fmt,...)) 
end
function fibaro.warningf(tag,fmt,...) 
  return print_debug('warning',tag,fformat(fmt,...))
end

--------------------- Scene function  -----------------------------------------
function fibaro.isSceneEnabled(sceneID) 
  __assert_type(sceneID,"number" )
  return (api.get("/scenes/"..sceneID) or { enabled=false }).enabled 
end

function fibaro.setSceneEnabled(sceneID,enabled) 
  __assert_type(sceneID,"number" )   __assert_type(enabled,"boolean" )
  return api.put("/scenes/"..sceneID,{enabled=enabled}) 
end

function fibaro.getSceneRunConfig(sceneID)
  __assert_type(sceneID,"number" )
  return api.get("/scenes/"..sceneID).mode 
end

function fibaro.setSceneRunConfig(sceneID,runConfig)
  __assert_type(sceneID,"number" )
  assert(({automatic=true,manual=true})[runConfig],"runconfig must be 'automatic' or 'manual'")
  return api.put("/scenes/"..sceneID, {mode = runConfig}) 
end

function fibaro.getSceneByName(name)
  __assert_type(name,"string" )
  for _,s in ipairs(api.get("/scenes")) do
    if s.name==name then return s end
  end
end

--------------------- Globals --------------------------------------------------
function fibaro.createGlobalVariable(name,value,options)
  __assert_type(name,"string")
  if not fibaro.existGlobalVariable(name) then 
    value = tostring(value)
    local args = table.copy(options or {})
    args.name,args.value=name,value
    return api.post("/globalVariables",args)
  end
end

function fibaro.deleteGlobalVariable(name) 
  __assert_type(name,"string")
  return api.delete("/globalVariables/"..name) 
end

function fibaro.existGlobalVariable(name)
  __assert_type(name,"string")
  return api.get("/globalVariables/"..name) and true 
end

function fibaro.getGlobalVariableType(name)
  __assert_type(name,"string")
  local v = api.get("/globalVariables/"..name) or {}
  return v.isEnum,v.readOnly
end

function fibaro.getGlobalVariableLastModified(name)
  __assert_type(name,"string")
  return (api.get("/globalVariables/"..name) or {}).modified 
end

--------------------- Custom events --------------------------------------------
function fibaro.getAllCustomEvents()
  local res = {}
  for _,e in ipairs(api.get("/customEvents") or {}) do
    res[#res+1] = e.name
  end
  return res
end

function fibaro.createCustomEvent(name,userDescription) 
  __assert_type(name,"string")
  return api.post("/customEvents",{name=name,userDescription=userDescription or ""})
end

function fibaro.deleteCustomEvent(name) 
  __assert_type(name,"string" )
  return api.delete("/customEvents/"..name) 
end

function fibaro.existCustomEvent(name) 
  __assert_type(name,"string" )
  return api.get("/customEvents/"..name) and true 
end

--------------------- Profiles -------------------------------------------------
function fibaro.activeProfile(id)
  if id then
    if type(id)=='string' then id = fibaro.profileNameToId(id) end
    assert(id,"fibaro.activeProfile(id) - no such id/name")
    return api.put("/profiles",{activeProfile=id}) and id
  end
  return api.get("/profiles").activeProfile 
end

function fibaro.profileIdtoName(pid)
  __assert_type(pid,"number")
  for _,p in ipairs(api.get("/profiles").profiles or {}) do 
    if p.id == pid then return p.name end 
  end 
end

function fibaro.profileNameToId(name)
  __assert_type(name,"string")
  for _,p in ipairs(api.get("/profiles").profiles or {}) do 
    if p.name == name then return p.id end 
  end 
end

--------------------- Alarm ------------------------------------------
function fibaro.partitionIdToName(pid)
__assert_type(pid,"number")
return (api.get("/alarms/v1/partitions/"..pid) or {}).name 
end

function fibaro.partitionNameToId(name)
  assert(type(name)=='string',"Alarm partition name not a string")
  for _,p in ipairs(api.get("/alarms/v1/partitions") or {}) do
    if p.name == name then return p.id end
  end
end

-- Returns devices breached in partition 'pid'
function fibaro.getBreachedDevicesInPartition(pid)
  assert(type(pid)=='number',"Alarm partition id not a number")
  local p,res = api.get("/alarms/v1/partitions/"..pid),{}
  for _,d in ipairs((p or {}).devices or {}) do
    if fibaro.getValue(d,"value") then res[#res+1]=d end
  end
  return res
end

--------------------- Weather --------------------------------------------------
fibaro.weather = {}
function fibaro.weather.temperature() return api.get("/weather").Temperature end
function fibaro.weather.temperatureUnit() return api.get("/weather").TemperatureUnit end
function fibaro.weather.humidity() return api.get("/weather").Humidity end
function fibaro.weather.wind() return api.get("/weather").Wind end
function fibaro.weather.weatherCondition() return api.get("/weather").WeatherCondition end
function fibaro.weather.conditionCode() return api.get("/weather").ConditionCode end

--------------------- Climate panel ----------------------------
function fibaro.getClimateMode(id)
  return (api.get("/panels/climate/"..id) or {}).mode
end

--Returns the currents mode "mode", or sets it - "Auto", "Off", "Cool", "Heat"
function fibaro.climateModeMode(id,mode)
  if mode==nil then return api.get("/panels/climate/"..id).properties.mode end
  assert(({Auto=true,Off=true,Cool=true,Heat=true})[mode],"Bad climate mode")
  return api.put("/panels/climate/"..id,{properties={mode=mode}})
end

-- Set zone to scheduled mode
function fibaro.setClimateZoneToScheduleMode(id)
  __assert_type(id, "number")
  return api.put('/panels/climate/'..id, {properties = {
        handTimestamp     = 0,
        vacationStartTime = 0,
        vacationEndTime   = 0
      }})
end

-- Set zone to manual, incl. mode, time ( secs ), heat and cool temp
function  fibaro.setClimateZoneToManualMode(id, mode, time, heatTemp, coolTemp)
  __assert_type(id, "number") __assert_type(mode, "string")
  assert(({Auto=true,Off=true,Cool=true,Heat=true})[mode],"Bad climate mode")
  return api.put('/panels/climate/'..id, { properties = { 
        handMode            = mode, 
        vacationStartTime   = 0, 
        vacationEndTime     = 0,
        handTimestamp       = tonumber(time) and os.time()+time or math.tointeger(2^32-1),
        handSetPointHeating = tonumber(heatTemp) and heatTemp or nil,
        handSetPointCooling = tonumber(coolTemp) and coolTemp or nil
      }})
end

-- Set zone to vacation, incl. mode, start (secs from now), stop (secs from now), heat and cool temp
function fibaro.setClimateZoneToVacationMode(id, mode, start, stop, heatTemp, coolTemp)
  __assert_type(id,"number") __assert_type(mode,"string") __assert_type(start,"number") __assert_type(stop,"number")
  assert(({Auto=true,Off=true,Cool=true,Heat=true})[mode],"Bad climate mode")
  local now = os.time()
  return api.put('/panels/climate/'..id, { properties = {
        vacationMode            = mode,
        handTimestamp           = 0, 
        vacationStartTime       = now+start, 
        vacationEndTime         = now+stop,
        vacationSetPointHeating = tonumber(heatTemp) and heatTemp or nil,
        vacationSetPointCooling = tonumber(coolTemp) and coolTemp or nil
      }})
end
