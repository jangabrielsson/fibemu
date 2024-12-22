fibaro.debugFlags = fibaro.debugFlags or {}
fibaro.DECORATE = fibaro.DECORATE or {}
local format = string.format

local debugFlags = fibaro.debugFlags

--Exported: copies a table
local function copy(obj)
  if type(obj) == 'table' then
    local res = {} for k,v in pairs(obj) do res[k] = copy(v) end
    return res
  else return obj end
end

--Exported: compares two tables
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

local function midnight() local t = os.date("*t"); t.hour,t.min,t.sec = 0,0,0; return os.time(t) end

local function hm2sec(hmstr,ns)
  local offs,sun
  sun,offs = hmstr:match("^(%a+)([+-]?%d*)")
  if sun and (sun == 'sunset' or sun == 'sunrise') then
    if ns then
      local sunrise,sunset = sunCalc(os.time()+24*3600)
      hmstr,offs = sun=='sunrise' and sunrise or sunset, tonumber(offs) or 0
    else
      hmstr,offs = fibaro.getValue(1,sun.."Hour"), tonumber(offs) or 0
    end
  end
  local sg,h,m,s = hmstr:match("^(%-?)(%d+):(%d+):?(%d*)")
  if not (h and m) then error("Bad hm2sec string "..hmstr) end
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

local function toTime(time)
  if type(time) == 'number' then return time end
  local p = time:sub(1,2)
  if p == '+/' then return hm2sec(time:sub(3))+os.time()
  elseif p == 'n/' then
    local t1,t2 = midnight()+hm2sec(time:sub(3),true),os.time()
    return t1 > t2 and t1 or t1+24*60*60
  elseif p == 't/' then return  hm2sec(time:sub(3))+midnight()
  else return hm2sec(time) end
end

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

local function sunCalc(time)
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
  local sunrise = format("%.2d:%.2d", rise_time.hour, rise_time.min)
  local sunset = format("%.2d:%.2d", set_time.hour, set_time.min)
  local sunrise_t = format("%.2d:%.2d", rise_time_t.hour, rise_time_t.min)
  local sunset_t = format("%.2d:%.2d", set_time_t.hour, set_time_t.min)
  return sunrise, sunset, sunrise_t, sunset_t
end

------------------------------------------------------------
--- Triggers
------------------------------------------------------------
local em,handlers = { sections = {}, stats={tried=0,matched=0}},{}
em.BREAK, em.TIMER, em.RULE = '%%BREAK%%', '%%TIMER%%', '%%RULE%%'
em._handlers = handlers
local handleEvent,invokeHandler
local function isEvent(e) return type(e)=='table' and e.type end
local function isRule(e) return type(e)=='table' and e[em.RULE] end

-- This can be used to "post" an event into this QA... Ex. fibaro.call(ID,'RECIEVE_EVENT',{type='myEvent'})
function QuickApp.RECIEVE_EVENT(_,ev)
  assert(isEvent(ev),"Bad argument to remote event")
  local time = ev.ev._time
  ev,ev.ev._time = ev.ev,nil
  if time and time+5 < os.time() then fibaro.warning(__TAG,format("Slow events %s, %ss",tostring(ev),os.time()-time)) end
  fibaro.post(ev)
end

function fibaro.postRemote(uuid,id,ev)
  if ev == nil then
    id,ev = uuid,id
    assert(tonumber(id) and isEvent(ev),"Bad argument to postRemote")
    ev._from,ev._time = plugin.mainDeviceId,os.time()
    fibaro.call(id,'RECIEVE_EVENT',{type='EVENT',ev=ev}) -- We need this as the system converts "99" to 99 and other "helpful" conversions
  else
    -- post to slave box in the future
  end
end

local function post(ev,t,log,hook,customLog)
  local now = os.time()
  t = type(t)=='string' and toTime(t) or t or 0
  if t < 0 then return elseif t < now then t = t+now end
  if debugFlags.post and (type(ev)=='function' or not ev._sh) then 
    (customLog or fibaro.trace)(__TAG,format("Posting %s at %s %s",tostring(ev),os.date("%c",t),type(log)=='string' and ("("..log..")") or "")) end
    if type(ev) == 'function' then
      return setTimeout(function() ev(ev) end,1000*(t-now),log),t
    elseif isEvent(ev) then
      return setTimeout(function() if hook then hook() end handleEvent(ev) end,1000*(t-now),log),t
    else
      error("post(...) not event or function;"..tostring(ev))
      end
    end
    fibaro.post = post 
    
    -- Cancel post in the future
    function fibaro.cancel(ref) clearTimeout(ref) end
    
    local function transform(obj,tf)
      if type(obj) == 'table' then
        local res = {} for l,v in pairs(obj) do res[l] = transform(v,tf) end 
        return res
      else return tf(obj) end
    end
    
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
    em.coerce = coerce
    
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
      assert(pattern)
      if pattern.type and type(pattern.id)=='table' and not pattern.id._constr then
        local m = {}; for _,id in ipairs(pattern.id) do m[id]=true end
        pattern.id = {_var_='_', _constr=function(val) return m[val] end, _str=pattern.id}
      end
      return pattern
    end
    em.compilePattern = compilePattern
    
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
    em.match = match
    
    function invokeHandler(env)
      local t = os.time()
      env.last,env.rule.time = t-(env.rule.time or 0),t
      local status, res = pcall(env.rule.action,env) -- call the associated action
      if not status then
        if type(res)=='string' and not debugFlags.extendedErrors then res = res:gsub("(%[.-%]:%d+:)","") end
        fibaro.errorf(nil,"in %s: %s",env.rule.doc,res)
        env.rule._disabled = true -- disable rule to not generate more errors
        em.stats.errors=(em.stats.errors or 0)+1
      else return res end
    end
    
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
    
    local function comboToStr(r)
      local res = { r.doc }
      for _,s in ipairs(r.subs) do res[#res+1]="   "..tostring(s) end
      return table.concat(res,"\n")
    end
    local function rule2str(rule) return rule.doc end
    
    local function map(f,l,s) s = s or 1; local r={} for i=s,table.maxn(l) do r[#r+1] = f(l[i]) end return r end
    local function mapF(f,l,s) s = s or 1; local e=true for i=s,table.maxn(l) do e = f(l[i]) end return e end
    
    local function comboEvent(e,action,rl,doc)
      local rm = {[em.RULE]=e, action=action, doc=doc, subs=rl}
      rm.enable = function() mapF(function(e0) e0.enable() end,rl) return rm end
      rm.disable = function() mapF(function(e0) e0.disable() end,rl) return rm end
      rm.tag = function(t) mapF(function(e0) e0.tag(t) end,rl) return rm end
      rm.start = function(event) invokeHandler({rule=rm,event=event}) return rm end
      rm.__tostring = comboToStr
      return rm
    end
    
    local registered 
    function fibaro.event(pattern,fun,doc)
      if fibaro.registerSourceTriggerCallback and not registered then registered=true fibaro.registerSourceTriggerCallback(handleEvent) end
      doc = doc or format("Event(%s) => ..",fibaro.DECORATE._ENCODEFAST(pattern))
      if type(pattern) == 'table' and pattern[1] then 
        return comboEvent(pattern,fun,map(function(es) return fibaro.event(es,fun) end,pattern),doc) 
      end
      if isEvent(pattern) then
        if pattern.type=='device' and pattern.id and type(pattern.id)=='table' then
          return fibaro.event(map(function(id) local e1 = copy(pattern); e1.id=id return e1 end,pattern.id),fun,doc)
        end
      else error("Bad event pattern, needs .type field") end
      assert(type(fun)=='function',"Second argument must be Lua function")
        local cpattern = compilePattern(pattern)
        local hashKey = toHash[pattern.type] and toHash[pattern.type](pattern) or pattern.type
        handlers[hashKey] = handlers[hashKey] or {}
        local rules = handlers[hashKey]
        local rule,fn = {[em.RULE]=cpattern, event=pattern, action=fun, doc=doc}, true
        for _,rs in ipairs(rules) do -- Collect handlers with identical patterns. {{e1,e2,e3},{e1,e2,e3}}
          if equal(cpattern,rs[1].event) then 
            rs[#rs+1] = rule
            fn = false break 
          end
        end
        if fn then rules[#rules+1] = {rule} end
        rule.enable = function() rule._disabled = nil fibaro.post({type='ruleEnable',rule=rule,_sh=true}) return rule end
        rule.disable = function() rule._disabled = true fibaro.post({type='ruleDisable',rule=rule,_sh=true}) return rule end
        rule.start = function(event) invokeHandler({rule=rule, event=event, p={}}) return rule end
        rule.tag = function(t) rule._tag = t or __TAG; return rule end
        rule.__tostring = rule2str
        if em.SECTION then
          local s = em.sections[em.SECTION] or {}
          s[#s+1] = rule
          em.sections[em.SECTION] = s
        end
        if em.TAG then rule._tag = em.TAG end
        return rule
      end
      
      function fibaro.removeEvent(pattern,fun)
        if fun==nil then return fibaro.removeEvent2(pattern) end
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
      
      function fibaro.removeEvent2(rule)
        for k,rules in pairs(handlers) do
          for i,r0 in ipairs(rules) do
            for j,r in ipairs(r0) do
              if r == rule then table.remove(r0,i) end
            end
            if #r0==0 then table.remove(rules,i) end
          end
          if #rules==0 then handlers[k]=nil end
        end
      end
      
      local function ruleHandler2string(e)
        return format("%s => %s",tostring(e.event),tostring(e.rule))
      end
      
      function handleEvent(ev)
        local hasKeys = fromHash[ev.type] and fromHash[ev.type](ev) or {ev.type}
        for _,hashKey in ipairs(hasKeys) do
          for _,rules in ipairs(handlers[hashKey] or {}) do -- Check all rules of 'type'
            local i,m=1,nil
            em.stats.tried=em.stats.tried+1
            for j=1,#rules do
              if not rules[j]._disabled then    -- find first enabled rule, among rules with same head
                m = match(rules[i][em.RULE],ev) -- and match against that rule
                break
              end
            end
            if m then                           -- we have a match
              for j=i,#rules do                 -- executes all rules with same head
                local rule=rules[j]
                if not rule._disabled then 
                  em.stats.matched=em.stats.matched+1
                  if invokeHandler({event = ev, p=m, rule=rule, __tostring=ruleHandler2string}) == em.BREAK then return end
                end
              end
            end
          end
        end
      end
      
      local function handlerEnable(t,handle)
        if type(handle) == 'string' then table.mapf(em[t],em.sections[handle] or {})
        elseif isRule(handle) then handle[t]()
        elseif type(handle) == 'table' then table.mapf(em[t],handle) 
        else error('Not an event handler') end
        return true
      end
      
      function em.enable(handle,opt)
        if type(handle)=='string' and opt then 
          for s,e in pairs(em.sections or {}) do 
            if s ~= handle then handlerEnable('disable',e) end
          end
        end
        return handlerEnable('enable',handle) 
      end
      function em.disable(handle) return handlerEnable('disable',handle) end
      
      ------------------------------------------------------------
      --- Triggers
      ------------------------------------------------------------
      local trigger = {
        GlobalSourceTriggerGV = "gkjhkjdfhgjhdsfgjhsdfgjhfdkj"
      }
      
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
          if d.variableName == trigger.GlobalSourceTriggerGV then
            local stat,va = pcall(json.decode,d.newValue)
            if not stat then return end
            va._transID = nil
            post(va)
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
      
      local refresh = RefreshStateSubscriber()
      local function filter(ev) return trigger.filter(ev) end
      
      local function handler(ev)
        if EventTypes[ev.type] then
          EventTypes[ev.type](ev.data,ev,trigger.post)
        end
      end
      refresh:subscribe(filter,handler)
      
      trigger.start = function()  end
      trigger.stop = function() refresh:stop() end
      trigger.filter = function(ev) return true end
      trigger.post = function(ev)  end
      
      ------------------------------------------------------------
      --- Event annotation
      ------------------------------------------------------------
      
      local _setup = nil
      
      trigger.post = post
      function QuickApp:post(ev) 
        return trigger.post(ev)
      end
      
      local function setup() trigger.start() end
      
      local function getVar(name)
        name = name:split(".")
        local v = _G
        for _,s in ipairs(name) do
          v = v[s]
          if v==nil then break end
        end
        if v == nil then fibaro.warning(__TAG,"No value for variable "..name) end
        return v
      end
      
      local function parseE(args)
        local e,org = {},args
        repeat
          args = args:match("%s*(.*)$")
          if args=="" then break end
          local key,rest = args:match("(%w+)%s*=(.*)")
          local pre,val,val2 = nil,nil,nil
          if not key then fibaro.error(__TAG,"Bad annotation args",org) break end
          if rest:match('^%s*"') then
            pre,val = rest:match('(%s*)(%b""),?')
            val2 = val:sub(2,-2)
          elseif rest:match("^%s*'") then
            pre,val = rest:match("(%s*)(%b''),?")
            val2 = val:sub(2,-2)
          else
            pre,val = rest:match("(%s*)([^,]+)")
            if tonumber(val) then
              val2 = tonumber(val)
            else
              if val == '*' then val = '$_' end
              local var,op,con = val:match("$([%w_]*)([<>=~]*)(.*)")
              if var then val2 = val
              else val2 = getVar(val) end
            end
          end
          args = rest:sub(#pre+#val+2)
          e[key] = val2
        until false
        return e
      end
      
      function QuickApp:Event_decorator(f,info,args)
        if not _setup then setup() end
        fibaro.DECORATE._DEBUG("Decorating Event %s %s",info.name,args)
        local pattern = parseE(args)
        fibaro.DECORATE._DEBUG(" Pattern %s %s",info.name,fibaro.DECORATE._ENCODEFAST(pattern))
        local function handler(env,vars)
          local params = {}
          for _,p in ipairs(info.args) do
            params[#params+1] = p =='_event' and env.event or env.event[p]
          end
          f(table.unpack(params))
        end
        fibaro.event(pattern,handler)
        return f
      end