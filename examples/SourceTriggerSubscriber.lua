---@diagnostic disable: undefined-global
-------------- SourceTrigger engine -------------------
fibaro.debugFlags = fibaro.debugFlags or {}
local debugFlags = fibaro.debugFlags
-- debugFlags.sourceTrigger = true -- log all sourceTrigger events
-- debugFlags.refreshEvent = true -- log all refreshEvent events
-- debugFlags.post = true -- log all events being posted

local GlobalSourceTriggerGV = "GlobalSourceTriggerGV"
local fmt = string.format
local encode,EventMT,toTime

local function equal(e1,e2)
  if e1==e2 then return true
  else
    if type(e1) ~= 'table' or type(e2) ~= 'table' then return false
    else
      for k1,v1 in pairs(e1) do if e2[k1] == nil or not equal(v1,e2[k1]) then return false end end
      for k2,_  in pairs(e2) do if e1[k2] == nil then return false end end
      return true
    end
  end
end
local function copy(t) if type(t) ~= 'table' then return t end local r = {} for k,v in pairs(t) do r[k] = copy(v) end return r end
getmetatable("").__idiv = function(str,len) return (#str < len or #str < 4) and str or str:sub(1,len-2)..".." end -- truncate strings

local function isEvent(e) return type(e) == 'table' and type(e.type)=='string' end

---@diagnostic disable-next-line: param-type-mismatch
local function midnight() local t = os.date("*t"); t.hour,t.min,t.sec = 0,0,0; return os.time(t) end

local function sunturnTime(date, rising, latitude, longitude, zenith, local_offset)
  local rad,deg,floor = math.rad,math.deg,math.floor
  local frac = function(n) return n - floor(n) end
  local cos = function(d) return math.cos(rad(d)) end
  local acos = function(d) return deg(math.acos(d)) end
  local sin = function(d) return math.sin(rad(d)) end
  local asin = function(d) return deg(math.asin(d)) end
  local tan = function(d) return math.tan(rad(d)) end
  local atan = function(d) return deg(math.atan(d)) end

  local function day_of_year(date2)
    local n1 = floor(275 * date2.month / 9)
    local n2 = floor((date2.month + 9) / 12)
    local n3 = (1 + floor((date2.year - 4 * floor(date2.year / 4) + 2) / 3))
    return n1 - (n2 * n3) + date2.day - 30
  end

  local function fit_into_range(val, min, max)
    local range,count = max - min,nil
    if val < min then count = floor((min - val) / range) + 1; return val + count * range
    elseif val >= max then count = floor((val - max) / range) + 1; return val - count * range
    else return val end
  end

  -- Convert the longitude to hour value and calculate an approximate time
  local n,lng_hour,t =  day_of_year(date), longitude / 15,nil
  if rising then t = n + ((6 - lng_hour) / 24) -- Rising time is desired
  else t = n + ((18 - lng_hour) / 24) end -- Setting time is desired
  local M = (0.9856 * t) - 3.289 -- Calculate the Sun^s mean anomaly
  -- Calculate the Sun^s true longitude
  local L = fit_into_range(M + (1.916 * sin(M)) + (0.020 * sin(2 * M)) + 282.634, 0, 360)
  -- Calculate the Sun^s right ascension
  local RA = fit_into_range(atan(0.91764 * tan(L)), 0, 360)
  -- Right ascension value needs to be in the same quadrant as L
  local Lquadrant = floor(L / 90) * 90
  local RAquadrant = floor(RA / 90) * 90
  RA = RA + Lquadrant - RAquadrant; RA = RA / 15 -- Right ascension value needs to be converted into hours
  local sinDec = 0.39782 * sin(L) -- Calculate the Sun's declination
  local cosDec = cos(asin(sinDec))
  local cosH = (cos(zenith) - (sinDec * sin(latitude))) / (cosDec * cos(latitude)) -- Calculate the Sun^s local hour angle
  if rising and cosH > 1 then return -1 --"N/R" -- The sun never rises on this location on the specified date
  elseif cosH < -1 then return -1 end --"N/S" end -- The sun never sets on this location on the specified date

  local H -- Finish calculating H and convert into hours
  if rising then H = 360 - acos(cosH)
  else H = acos(cosH) end
  H = H / 15
  local T = H + RA - (0.06571 * t) - 6.622 -- Calculate local mean time of rising/setting
  local UT = fit_into_range(T - lng_hour, 0, 24) -- Adjust back to UTC
  local LT = UT + local_offset -- Convert UT value to local time zone of latitude/longitude
---@diagnostic disable-next-line: missing-fields
  return os.time({day = date.day,month = date.month,year = date.year,hour = floor(LT),min = math.modf(frac(LT) * 60)})
end

---@diagnostic disable-next-line: param-type-mismatch
local function getTimezone() local now = os.time() return os.difftime(now, os.time(os.date("!*t", now))) end

function fibaro.sunCalc(time)
  local hc3Location = api.get("/settings/location")
  local lat = hc3Location.latitude or 0
  local lon = hc3Location.longitude or 0
  local utc = getTimezone() / 3600
  local zenith,zenith_twilight = 90.83, 96.0 -- sunset/sunrise 90°50′, civil twilight 96°0′

  local date = os.date("*t",time or os.time())
  if date.isdst then utc = utc + 1 end
  local rise_time = os.date("*t", sunturnTime(date, true, lat, lon, zenith, utc))
  local set_time = os.date("*t", sunturnTime(date, false, lat, lon, zenith, utc))
  local rise_time_t = os.date("*t", sunturnTime(date, true, lat, lon, zenith_twilight, utc))
  local set_time_t = os.date("*t", sunturnTime(date, false, lat, lon, zenith_twilight, utc))
  local sunrise = fmt("%.2d:%.2d", rise_time.hour, rise_time.min)
  local sunset = fmt("%.2d:%.2d", set_time.hour, set_time.min)
  local sunrise_t = fmt("%.2d:%.2d", rise_time_t.hour, rise_time_t.min)
  local sunset_t = fmt("%.2d:%.2d", set_time_t.hour, set_time_t.min)
  return sunrise, sunset, sunrise_t, sunset_t
end

local function hm2sec(hmstr,ns)
  local offs,sun
  sun,offs = hmstr:match("^(%a+)([+-]?%d*)")
  if sun and (sun == 'sunset' or sun == 'sunrise') then
    if ns then
      local sunrise,sunset = fibaro.sunCalc(os.time()+24*3600)
      hmstr,offs = sun=='sunrise' and sunrise or sunset, tonumber(offs) or 0
    else
      hmstr,offs = fibaro.getValue(1,sun.."Hour"), tonumber(offs) or 0
    end
  end
  local sg,h,m,s = hmstr:match("^(%-?)(%d+):(%d+):?(%d*)")
  if not (h and m) then error(fmt("Bad hm2sec string %s",hmstr)) end
  return (sg == '-' and -1 or 1)*(tonumber(h)*3600+tonumber(m)*60+(tonumber(s) or 0)+(tonumber(offs or 0))*60)
end

-- toTime("10:00")     -> 10*3600+0*60 secs
-- toTime("10:00:05")  -> 10*3600+0*60+5*1 secs
-- toTime("t/10:00")    -> (t)oday at 10:00. midnight+10*3600+0*60 secs
-- toTime("n/10:00")    -> (n)ext time. today at 10.00AM if called before (or at) 10.00AM else 10:00AM next day
-- toTime("+/10:00")    -> Plus time. os.time() + 10 hours
-- toTime("+/00:01:22") -> Plus time. os.time() + 1min and 22sec
-- toTime("sunset")     -> todays sunset in relative secs since midnight, E.g. sunset="05:10", =>toTime("05:10")
-- toTime("sunrise")    -> todays sunrise
-- toTime("sunset+10")  -> todays sunset + 10min. E.g. sunset="05:10", =>toTime("05:10")+10*60
-- toTime("sunrise-5")  -> todays sunrise - 5min
-- toTime("t/sunset+10")-> (t)oday at sunset in 'absolute' time. E.g. midnight+toTime("sunset+10")

function toTime(time)
  if type(time) == 'number' then return time end
  local p = time:sub(1,2)
  if p == '+/' then return hm2sec(time:sub(3))+os.time()
  elseif p == 'n/' then
    local t1,t2 = midnight()+hm2sec(time:sub(3),true),os.time()
    return t1 > t2 and t1 or t1+24*60*60
  elseif p == 't/' then return  hm2sec(time:sub(3))+midnight()
  elseif p == 'h/' then
    local t1,t2 = hm2sec(time:sub(3))//60,os.date("*t")
    local t0 = t2.min*60+t2.sec
    t2.min,t2.sec = 0,0
    local th = os.time(t2)
    return (t1 >= t0 and th+t1 or th+t1+3600)
  else return hm2sec(time) end
end
fibaro.toTime = toTime
fibaro.midnight = midnight

do -- fastEncode
  local function encTsort(a,b) return a[1] < b[1] end
  local sortKeys = {"type","device","deviceID","id","value","oldValue","val","key","arg","event","events","msg","res"}
  local sortOrder,sortF={},nil
  for i,s in ipairs(sortKeys) do sortOrder[s]="\n"..string.char(i+64).." "..s end
  local function encEsort(a,b)
    a,b=a[1],b[1]; a,b = sortOrder[a] or a, sortOrder[b] or b
    return a < b
  end
  function table.maxn(t) local c=0 for _ in pairs(t) do c=c+1 end return c end
  local encT={}
  encT['nil'] = function(n,out) out[#out+1]='nil' end
  function encT.number(n,out) out[#out+1]=tostring(n) end
  function encT.userdata(u,out) out[#out+1]=tostring(u) end
  function encT.thread(t,out) out[#out+1]=tostring(t) end
  encT['function'] = function(f,out) out[#out+1]=tostring(f) end
  function encT.string(str,out) out[#out+1]='"' out[#out+1]=str out[#out+1]='"' end
  function encT.boolean(b,out) out[#out+1]=b and "true" or "false" end
  function encT.table(t,out)
    local mt = getmetatable(t) if t and t.__tostring then return tostring(t) end
    if next(t)==nil then return "{}" -- Empty table
    elseif t[1]==nil then -- key value table
      local r = {}; for k,v in pairs(t) do r[#r+1]={k,v} end table.sort(r,sortF)
      out[#out+1]='{'
      local e = r[1]
      out[#out+1]=e[1]; out[#out+1]='='; encT[type(e[2])](e[2],out)
      for i=2,table.maxn(r) do local e = r[i]; out[#out+1]=','; out[#out+1]=e[1]; out[#out+1]='='; encT[type(e[2])](e[2],out) end
      out[#out+1]='}'
    else -- array table
      out[#out+1]='['
      encT[type(t[1])](t[1],out)
      for i=2,table.maxn(t) do out[#out+1]=',' encT[type(t[ i])](t[i],out) end
      out[#out+1]=']'
    end
  end
  
  function encode(o,sort)
    local out = {}
    sortF = (not sort) and encEsort or encTsort
    encT[type(o)](o,out)
    return table.concat(out)
  end
  json.fastEncode = encode -- If someone else needs it...
end

local function createEventEngine()
  local self = {}
  local HANDLER = '%EVENTHANDLER%'
  local BREAK = '%BREAK%'
  self.BREAK = BREAK
  local handlers = {}
  
  local function coerce(x,y) local x1 = tonumber(x) if x1 then return x1,tonumber(y) else return x,y end end
  local constraints = {}
  constraints['=='] = function(val) return function(x) x,val=coerce(x,val) return x == val end end
  constraints['<>'] = function(val) return function(x) return tostring(x):match(val) end end
  constraints['>='] = function(val) return function(x) x,val=coerce(x,val) return x >= val end end
  constraints['<='] = function(val) return function(x) x,val=coerce(x,val) return x <= val end end
  constraints['>'] = function(val) return function(x) x,val=coerce(x,val) return x > val end end
  constraints['<'] = function(val) return function(x) x,val=coerce(x,val) return x < val end end
  constraints['~='] = function(val) return function(x) x,val=coerce(x,val) return x ~= val end end
  constraints[''] = function(_) return function(x) return x ~= nil end end
  
  local function compilePattern2(pattern)
    if type(pattern) == 'table' then
      if pattern._var_ then return end
      for k,v in pairs(pattern) do
        if type(v) == 'string' and v:sub(1,1) == '$' then
          local var,op,val = v:match("$([%w_]*)([<>=~]*)(.*)")
          var = var =="" and "_" or var
          local c = constraints[op](tonumber(val) or val)
          pattern[k] = {_var_=var, _constr=c, _str=v}
        else compilePattern2(v) end
      end
    end
    return pattern
  end
  
  local function compilePattern(pattern)
    pattern = compilePattern2(copy(pattern))
    if pattern.type and type(pattern.id)=='table' and not pattern.id._constr then
      local m = {}; for _,id in ipairs(pattern.id) do m[id]=true end
      pattern.id = {_var_='_', _constr=function(val) return m[val] end, _str=pattern.id}
    end
    return pattern
  end
  self.compilePattern = compilePattern
  
  local function match(pattern0, expr0)
    local matches = {}
    local function unify(pattern,expr)
      if pattern == expr then return true
      elseif type(pattern) == 'table' then
        if pattern._var_ then
          local var, constr = pattern._var_, pattern._constr
          if var == '_' then return constr(expr)
          elseif matches[var] then return constr(expr) and unify(matches[var],expr) -- Hmm, equal?
          else matches[var] = expr return constr(expr) end
        end
        if type(expr) ~= "table" then return false end
        for k,v in pairs(pattern) do if not unify(v,expr[k]) then return false end end
        return true
      else return false end
    end
    return unify(pattern0,expr0) and matches or false
  end
  self.match = match
  
  local function invokeHandler(rule,event,vars)
    local status, res = pcall(rule.action,event,vars) -- call the associated action
    if not status then
      fibaro.error(__TAG,fmt("in %s: %s - disabling subscription",rule,res))
      rule._disabled = true -- disable rule to not generate more errors
    else return res end
  end
  
  --local toTime = self.toTime
  function self.post(ev,t,log,hook,customLog)
    local now = os.time()
    t = type(t)=='string' and toTime(t) or t or 0
    if t < 0 then return elseif t < now then t = t+now end
    if debugFlags.post and (type(ev)=='function' or not ev._sh) then
      (customLog or fibaro.trace)(__TAG,fmt("Posting %s at %s %s",tostring(ev),os.date("%c",t),type(log)=='string' and ("("..log..")") or ""))
    end
    if type(ev) == 'function' then
      return setTimeout(function() ev(ev) end,1000*(t-now),log),t
    elseif type(ev)=='table' and type(ev.type)=='string' then
      if not getmetatable(ev) then setmetatable(ev,EventMT) end
      return setTimeout(function() if hook then hook() end self.handleEvent(ev) end,1000*(t-now),log),t
    else
      error("post(...) not event or fun;"..tostring(ev))
    end
  end
  
  function self.cancel(id) clearTimeout(id) end
  
  local toHash,fromHash={},{}
  fromHash['device'] = function(e) return {"device"..e.id..e.property,"device"..e.id,"device"..e.property,"device"} end
  fromHash['global-variable'] = function(e) return {'global-variable'..e.name,'global-variable'} end
  fromHash['quickvar'] = function(e) return {"quickvar"..e.id..e.name,"quickvar"..e.id,"quickvar"..e.name,"quickvar"} end
  fromHash['profile'] = function(e) return {'profile'..e.property,'profile'} end
  fromHash['weather'] = function(e) return {'weather'..e.property,'weather'} end
  fromHash['custom-event'] = function(e) return {'custom-event'..e.name,'custom-event'} end
  fromHash['deviceEvent'] = function(e) return {"deviceEvent"..e.id..e.value,"deviceEvent"..e.id,"deviceEvent"..e.value,"deviceEvent"} end
  fromHash['sceneEvent'] = function(e) return {"sceneEvent"..e.id..e.value,"sceneEvent"..e.id,"sceneEvent"..e.value,"sceneEvent"} end
  toHash['device'] = function(e) return "device"..(e.id or "")..(e.property or "") end
  toHash['global-variable'] = function(e) return 'global-variable'..(e.name or "") end
  toHash['quickvar'] = function(e) return 'quickvar'..(e.id or "")..(e.name or "") end
  toHash['profile'] = function(e) return 'profile'..(e.property or "") end
  toHash['weather'] = function(e) return 'weather'..(e.property or "") end
  toHash['custom-event'] = function(e) return 'custom-event'..(e.name or "") end
  toHash['deviceEvent'] = function(e) return 'deviceEvent'..(e.id or "")..(e.value or "") end
  toHash['sceneEvent'] = function(e) return 'sceneEvent'..(e.id or "")..(e.value or "") end
  
  local MTrule = { __tostring = function(self) return fmt("SourceTriggerSub:%s",self.event.type) end }
  function self.addEventHandler(pattern,fun)
    if not isEvent(pattern) then error("Bad event pattern, needs .type field") end
    assert(type(fun)=='func'..'tion', "Second argument must be Lua func")
    local cpattern = compilePattern(pattern)
    local rule,hashKeys = {[HANDLER]=cpattern, event=pattern, action=fun},{}
    if toHash[pattern.type] and pattern.id and type(pattern.id) == 'table' then
      local oldid=pattern.id
      for _,id in ipairs(pattern.id) do
        pattern.id = id
        hashKeys[#hashKeys+1] = toHash[pattern.type](pattern)
        pattern.id = oldid
      end
    else hashKeys = {toHash[pattern.type] and toHash[pattern.type](pattern) or pattern.type} end
    for _,hashKey in ipairs(hashKeys) do
      handlers[hashKey] = handlers[hashKey] or {}
      local rules,fn = handlers[hashKey],true
      for _,rs in ipairs(rules) do -- Collect handlers with identical patterns. {{e1,e2,e3},{e1,e2,e3}}
        if equal(cpattern,rs[1].event) then
          rs[#rs+1] = rule
          fn = false break
        end
      end
      if fn then rules[#rules+1] = {rule} end
    end
    rule.enable = function() rule._disabled = nil return rule end
    rule.disable = function() rule._disabled = true return rule end
    return rule
  end
  
  function self.removeEventHandler(rule)
    assert(type(rule)=='table' and rule[HANDLER],'Bad argument to removeEventHandler')
    local pattern,fun = rule.event,rule.action
    local hashKey = toHash[pattern.type] and toHash[pattern.type](pattern) or pattern.type
    local rules,i,j= handlers[hashKey] or {},1,1
    while j <= #rules do
      local rs = rules[j]
      while i <= #rs do
        if rs[i].action==fun then
          table.remove(rs,i)
        else i=i+i end
      end
      if #rs==0 then table.remove(rules,j) else j=j+1 end
    end
  end
  
  local callbacks = {}
  function self.registerCallback(fun) callbacks[#callbacks+1] = fun end
  
  function self.handleEvent(ev,firingTime)
    for _,cb in ipairs(callbacks) do cb(ev) end
    
    local hasKeys = fromHash[ev.type] and fromHash[ev.type](ev) or {ev.type}
    for _,hashKey in ipairs(hasKeys) do
      for _,rules in ipairs(handlers[hashKey] or {}) do -- Check all rules of 'type'
        local i,m=1,nil
        for j=1,#rules do
          if not rules[j]._disabled then    -- find first enabled rule, among rules with same head
            m = match(rules[i][HANDLER],ev) -- and match against that rule
            break
          end
        end
        if m then                           -- we have a match
          for j=i,#rules do                 -- executes all rules with same head
            local rule=rules[j]
            if not rule._disabled then
              if invokeHandler(rule, ev, m) == BREAK then return end
            end
          end
        end
      end
    end
  end
  
  -- This can be used to "post" an event into this QA... Ex. fibaro.call(ID,'RECIEVE_EVENT',{type='myEvent'})
  function QuickApp.RECIEVE_EVENT(_,ev)
    assert(isEvent(ev),"Bad argument to remote event")
    local time = ev.ev._time
    ev,ev.ev._time = ev.ev,nil
    if time and time+5 < os.time() then fibaro.warning(__TAG,fmt("Slow events %s, %ss",tostring(ev),os.time()-time)) end
  end
  
  function self.postRemote(uuid,id,ev)
    if ev == nil then
      id,ev = uuid,id
      assert(tonumber(id) and isEvent(ev),"Bad argument to postRemote")
      ev._from,ev._time = plugin.mainDeviceId,os.time()
      fibaro.call(id,'RECIEVE_EVENT',{type='EVENT',ev=ev}) -- We need this as the system converts "99" to 99 and other "helpful" conversions
    else
      -- post to slave box in the future ? 
    end
  end
  
  return self
end -- createEventEngine

local _GLOBAL = false

local function quickVarEvent(d,_,post)
  local old={}; for _,v in ipairs(d.oldValue) do old[v.name] = v.value end
  for _,v in ipairs(d.newValue) do
    if not equal(v.value,old[v.name]) then
      post({type='quickvar', id=d.id, name=v.name, value=v.value, old=old[v.name]})
    end
  end
end

-- There are more, but these are what I seen so far...
--[[
{type='alarm', property='armed', id = <partitionId>, value=<boolean>}
{type='alarm', property='breached', id = <partitionId>, value=<boolean>}
{type='alarm', property='homeArmed', value=<boolean>
{type='alarm', property='homeBreached', value=<boolean>
{type='weather',property=<string>, value=<number>, old=<number>}
{type='global-variable', name=<string>, value=<string>, old=<string>}
{type='quickvar', id=<number>, name=<string>, value=<value>, old=<value>}
{type='device', id=<number>, property=<string>, value=<value>, old=<value>}
{type='device', id=<number>, property='centralSceneEvent', value={keyId=<number>, keyAttribute=<number>}}
{type='device', id=<number>, property='sceneActivationEvent', value={sceneId=<number>}}
{type='device', id=<number>, property='accessControlEvent', value=<table>}
{type='custom-event', name=<string>, value=<string>}
{type='deviceEvent', id=<number>, value='removed'}
{type='deviceEvent', id=<number>, value='changedRoom'}
{type='deviceEvent', id=<number>, value='created'}
{type='deviceEvent', id=<number>, value='modified'}
{type='deviceEvent', id=<number>, value='crashed', error=<string>}
{type='sceneEvent', id=<number>, value='started'}
{type='sceneEvent', id=<number>, value='finished'}
{type='sceneEvent', id=<number>, value='instance', instance=<value>}
{type='sceneEvent', id=<number>, value='removed'}
{type='sceneEvent', id=<number>, value='modified'}
{type='sceneEvent', id=<number>, value='created'}
{type='onlineEvent', value=<boolean>}
{type='profile',property='activeProfile',value=<string>, old=<string>}
{type='ClimateZone', id=<number>, type=<string>, value=<string>, old=<string>}
{type='ClimateZoneSetpoint', id=<number>, type=<string>, value=<number>, old=<number>}
{type='notification', id=<number>, value='created'}
{type='notification', id=<number>, value='removed'}
{type='notification', id=<number>, value='updated'}
{type='room', id=<number>, value='created'}
{type='room', id=<number>, value='removed'}
{type='room', id=<number>, value='modified'}
{type='section', id=<number>, value='created'}
{type='section', id=<number>, value='removed'}
{type='section', id=<number>, value='modified'}
{type='location',id=<number>,property=<string>,value=<string>,timestamp=<number>}
{type='user',id=<number>,value='action',data=<value>}
{type='system',value='action',data=<value>}
--]]
local EventTypes = {
  AlarmPartitionArmedEvent = function(d,_,post) post({type='alarm', property='armed', id = d.partitionId, value=d.armed}) end,
  AlarmPartitionBreachedEvent = function(d,_,post) post({type='alarm', property='breached', id = d.partitionId, value=d.breached}) end,
  AlarmPartitionModifiedEvent = function(d,_,post)  end,
  HomeArmStateChangedEvent = function(d,_,post) post({type='alarm', property='homeArmed', value=d.newValue}) end,
  HomeDisarmStateChangedEvent = function(d,_,post) post({type='alarm', property='homeArmed', value=not d.newValue}) end,
  HomeBreachedEvent = function(d,_,post) post({type='alarm', property='homeBreached', value=d.breached}) end,
  WeatherChangedEvent = function(d,_,post) post({type='weather',property=d.change, value=d.newValue, old=d.oldValue}) end,
  GlobalVariableChangedEvent = function(d,_,post)
    if d.variableName == GlobalSourceTriggerGV then
      if _GLOBAL then
        local stat,va = pcall(json.decode,d.newValue)
        if not stat then return end
        va._transID = nil
        post(va)
      end
    else
      post({type='global-variable', name=d.variableName, value=d.newValue, old=d.oldValue})
    end
  end,
  GlobalVariableAddedEvent = function(d,_,post) post({type='global-variable', name=d.variableName, value=d.value, old=nil}) end,
  DevicePropertyUpdatedEvent = function(d,_,post)
    if d.property=='quickAppVariables' then quickVarEvent(d,_,post)
    else
      post({type='device', id=d.id, property=d.property, value=d.newValue, old=d.oldValue})
    end
  end,
  CentralSceneEvent = function(d,_,post)
    d.id,d.icon = d.id or d.deviceId,nil
    post({type='device', property='centralSceneEvent', id=d.id, value={keyId=d.keyId, keyAttribute=d.keyAttribute}})
  end,
  SceneActivationEvent = function(d,_,post)
    d.id = d.id or d.deviceId
    post({type='device', property='sceneActivationEvent', id=d.id, value={sceneId=d.sceneId}})
  end,
  AccessControlEvent = function(d,_,post)
    post({type='device', property='accessControlEvent', id=d.id, value=d})
  end,
  CustomEvent = function(d,_,post)
    local value = api.get("/customEvents/"..d.name)
    post({type='custom-event', name=d.name, value=value and value.userDescription})
  end,
  PluginChangedViewEvent = function(d,_,post) post({type='PluginChangedViewEvent', value=d}) end,
  WizardStepStateChangedEvent = function(d,_,post) post({type='WizardStepStateChangedEvent', value=d})  end,
  UpdateReadyEvent = function(d,_,post) post({type='updateReadyEvent', value=d}) end,
  DeviceRemovedEvent = function(d,_,post)  post({type='deviceEvent', id=d.id, value='removed'}) end,
  DeviceChangedRoomEvent = function(d,_,post)  post({type='deviceEvent', id=d.id, value='changedRoom'}) end,
  DeviceCreatedEvent = function(d,_,post)  post({type='deviceEvent', id=d.id, value='created'}) end,
  DeviceModifiedEvent = function(d,_,post) post({type='deviceEvent', id=d.id, value='modified'}) end,
  PluginProcessCrashedEvent = function(d,_,post) post({type='deviceEvent', id=d.deviceId, value='crashed', error=d.error}) end,
  SceneStartedEvent = function(d,_,post)   post({type='sceneEvent', id=d.id, value='started'}) end,
  SceneFinishedEvent = function(d,_,post)  post({type='sceneEvent', id=d.id, value='finished'})end,
  SceneRunningInstancesEvent = function(d,_,post) post({type='sceneEvent', id=d.id, value='instance', instance=d}) end,
  SceneRemovedEvent = function(d,_,post)  post({type='sceneEvent', id=d.id, value='removed'}) end,
  SceneModifiedEvent = function(d,_,post)  post({type='sceneEvent', id=d.id, value='modified'}) end,
  SceneCreatedEvent = function(d,_,post)  post({type='sceneEvent', id=d.id, value='created'}) end,
  OnlineStatusUpdatedEvent = function(d,_,post) post({type='onlineEvent', value=d.online}) end,
  ActiveProfileChangedEvent = function(d,_,post)
    post({type='profile',property='activeProfile',value=d.newActiveProfile, old=d.oldActiveProfile})
  end,
  ClimateZoneChangedEvent = function(d,_,post) --ClimateZoneChangedEvent
    if d.changes and type(d.changes)=='table' then
      for _,c in ipairs(d.changes) do
        c.type,c.id='ClimateZone',d.id
        post(c)
      end
    end
  end,
  ClimateZoneSetpointChangedEvent = function(d,_,post) d.type = 'ClimateZoneSetpoint' post(d,_,post) end,
  NotificationCreatedEvent = function(d,_,post) post({type='notification', id=d.id, value='created'}) end,
  NotificationRemovedEvent = function(d,_,post) post({type='notification', id=d.id, value='removed'}) end,
  NotificationUpdatedEvent = function(d,_,post) post({type='notification', id=d.id, value='updated'}) end,
  RoomCreatedEvent = function(d,_,post) post({type='room', id=d.id, value='created'}) end,
  RoomRemovedEvent = function(d,_,post) post({type='room', id=d.id, value='removed'}) end,
  RoomModifiedEvent = function(d,_,post) post({type='room', id=d.id, value='modified'}) end,
  SectionCreatedEvent = function(d,_,post) post({type='section', id=d.id, value='created'}) end,
  SectionRemovedEvent = function(d,_,post) post({type='section', id=d.id, value='removed'}) end,
  SectionModifiedEvent = function(d,_,post) post({type='section', id=d.id, value='modified'}) end,
  QuickAppFilesChangedEvent = function(_) end,
  ZwaveDeviceParametersChangedEvent = function(_) end,
  ZwaveNodeAddedEvent = function(_) end,
  RefreshRequiredEvent = function(_) end,
  DeviceFirmwareUpdateEvent = function(_) end,
  GeofenceEvent = function(d,_,post) post({type='location',id=d.userId,property=d.locationId,value=d.geofenceAction,timestamp=d.timestamp}) end,
  DeviceActionRanEvent = function(d,e,post)
    if e.sourceType=='user' then
      post({type='user',id=e.sourceId,value='action',data=d})
    elseif e.sourceType=='system' then
      post({type='system',value='action',data=d})
    end
  end,
}

EventMT = { __tostring = function(ev)
  local s = encode(ev)
  return fmt("#%s{%s}",ev.type,s:match(",(.*)}") or "") end
}

class 'SourceTriggerSubscriber'
function SourceTriggerSubscriber:__init()
  self.refresh = RefreshStateSubscriber()
  self.eventEngine = createEventEngine()
  self.ignore = {}
  local function post(event,firingTime)
    if self.ignore[event.type] then return end
    setmetatable(event,EventMT)
    if debugFlags.sourceTrigger then fibaro.trace(__TAG,fmt("SourceTrigger: %s",tostring(event) // (debugFlags.trunc or 80))) end
    self.eventEngine.handleEvent(event,firingTime)
  end
  local function filter(ev)
    if debugFlags.refreshEvent then
      fibaro.trace(__TAG,fmt("RefreshEvent: %s:%s",ev.type,encode(ev.data)) // (debugFlags.trunc or 80))
    end
    return true
  end
  local function handler(ev)
    if EventTypes[ev.type] then
      EventTypes[ev.type](ev.data,ev,post)
    end
  end
  self.refresh:subscribe(filter,handler)
end
function SourceTriggerSubscriber:run() self.refresh:run() end
function SourceTriggerSubscriber:stop() self.refresh:stop() end
function SourceTriggerSubscriber:global(flag) _GLOBAL = flag end
function SourceTriggerSubscriber:subscribe(event,handler) --> subscription
  assert(isEvent(event),"Bad event argument to subscribe")
  assert(type(handler)=='function',"Bad handler argument to subscribe")
    return self.eventEngine.addEventHandler(event,handler)
  end
  function SourceTriggerSubscriber:unsubscribe(subscription)
    self.eventEngine.removeEventHandler(subscription)
  end
  function SourceTriggerSubscriber:enableSubscription(subscription)
    subscription.enable()
  end
  function SourceTriggerSubscriber:disableSubscription(subscription)
    subscription.disable()
  end
  function SourceTriggerSubscriber:post(event,time,log,hook,customLog)
    assert(isEvent(event),"Bad event argument to post")
    return self.eventEngine.post(event,time,log,hook,customLog)
  end
  function SourceTriggerSubscriber:registerCallback(fun)
    assert(type(fun)=='function',"Bad callback argument to registerCallback")
      return self.eventEngine.registerCallback(fun)
    end
    function SourceTriggerSubscriber:cancel(ref)
      return self.eventEngine.cancel(ref)
    end
    function SourceTriggerSubscriber:postRemote(id,event)
      assert(isEvent(event),"Bad event argument to postRemote")
      assert(type(id)=='number',"Bad deviceId argument to postRemote")
      return self.eventEngine.postRemote(id,event)
    end
    function SourceTriggerSubscriber:postGlobal(event)
      assert(isEvent(event),"Bad event argument to postGlobal")
      if not self._globalGV then
        self._globalGV = true
        api.post("/globalVariables",{name=GlobalSourceTriggerGV, isEnum=false, isReadOnly=false, value=""})
      end
      local ev = {} for k,v in pairs(event) do ev[k]=v end
      ev.transID = math.random(1000000,9999999) -- could do QA id + transNr...
      ev._from = plugin.mainDeviceId
      fibaro.setGlobalVariable(GlobalSourceTriggerGV,(json.encode(ev)))
    end
    function SourceTriggerSubscriber:ignoreTrigger(tr)
      if type(tr)~='table' then tr = {tr} end
      for _,t in ipairs(tr) do self.ignore[t]=true end
    end
    
    --[[
    -- Usage:
    
    local st = SourceTriggerSubscriber()
    st:subscribe({type='device',id={46,47},property='value'},
    function(ev) fibaro.trace(__TAG,fmt("Device %s changed to %s",ev.id,ev.value))
    end)
    st:run()
    
    --]]
    --------------------- SourceTrigger engine ---------------------