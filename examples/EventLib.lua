local _trigger = {}
local _builtin = {}
local _handler = {}
local _eMap = {}
local post,handleEvent,trueFor,again,toTime,transformEvent
local _inited = false
local Event

fibaro.debugFlags = fibaro.debugFlags or {}

local fmt = string.format
local function map(f, t) local r = {}; for _,v in ipairs(t) do r[#r+1]= f(v) end  return r end
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
local function append(a,...) 
  local r = copy(a); 
  for _,b in ipairs({...}) do 
    for _,v in ipairs(b) do r[#r+1]=v end 
  end
return r end

local function color(col,c) return fmt('<font color="%s">%s</font>',col or 'white',c) end
local function timeStr(time) 
  if type(time) == 'string' then time = toTime(time) end
  if time < 35*24*3600 then time=time+os.time() end
  return os.date("%H:%M:%S",time)
end

local function DEBUG(tag,...) 
  if fibaro.debugFlags[tag] then fibaro.trace(__TAG,color('skyblue',fmt(...))) end 
end
local function color(col,str) return fmt('<font color="%s">%s</font>',col,str) end

---------------- Lua Table to String ---------------
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

local function encode(o,sort)
  local out = {}
  sortF = (not sort) and encEsort or encTsort
  encT[type(o)](o,out)
  return table.concat(out)
end

---------------- SunCalc -----------------
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
  local sunrise = fmt("%.2d:%.2d", rise_time.hour, rise_time.min)
  local sunset = fmt("%.2d:%.2d", set_time.hour, set_time.min)
  local sunrise_t = fmt("%.2d:%.2d", rise_time_t.hour, rise_time_t.min)
  local sunset_t = fmt("%.2d:%.2d", set_time_t.hour, set_time_t.min)
  return sunrise, sunset, sunrise_t, sunset_t
end

----------------- Cron ------------------
local function dateTest(dateStr0)
  local days = {sun=1,mon=2,tue=3,wed=4,thu=5,fri=6,sat=7}
  local months = {jan=1,feb=2,mar=3,apr=4,may=5,jun=6,jul=7,aug=8,sep=9,oct=10,nov=11,dec=12}
  local last,month = {31,28,31,30,31,30,31,31,30,31,30,31},nil

  local function seq2map(seq) local s = {} for _,v in ipairs(seq) do s[v] = true end return s; end

  local function flatten(seq,res) -- flattens a table of tables
    res = res or {}
    if type(seq) == 'table' then for _,v1 in ipairs(seq) do flatten(v1,res) end else res[#res+1] = seq end
    return res
  end

  local function _assert(test,msg,...) if not test then error(fmt(msg,...),3) end end

  local function expandDate(w1,md)
    local function resolve(id)
      local res
      if id == 'last' then month = md res=last[md] 
      elseif id == 'lastw' then month = md res=last[md]-6 
      else res= type(id) == 'number' and id or days[id] or months[id] or tonumber(id) end
      _assert(res,"Bad date specifier '%s'",id) return res
    end
    local step = 1
    local w,m = w1[1],w1[2]
    local start,stop = w:match("(%w+)%p(%w+)")
    if (start == nil) then return resolve(w) end
    start,stop = resolve(start), resolve(stop)
    local res,res2 = {},{}
    if w:find("/") then
      if not w:find("-") then -- 10/2
        step=stop; stop = m.max
      else step=(w:match("/(%d+)")) end
    end
    step = tonumber(step)
    _assert(start>=m.min and start<=m.max and stop>=m.min and stop<=m.max,"illegal date intervall")
    while (start ~= stop) do -- 10-2
      res[#res+1] = start
      start = start+1; if start>m.max then start=m.min end  
    end
    res[#res+1] = stop
    if step > 1 then for i=1,#res,step do res2[#res2+1]=res[i] end; res=res2 end
    return res
  end

  local function parseDateStr(dateStr) --,last)
    local seq = string.split(dateStr," ")   -- min,hour,day,month,wday
    local lim = {{min=0,max=59},{min=0,max=23},{min=1,max=31},{min=1,max=12},{min=1,max=7},{min=2000,max=3000}}
    for i=1,6 do if seq[i]=='*' or seq[i]==nil then seq[i]=tostring(lim[i].min).."-"..lim[i].max end end
    seq = map(function(w) return string.split(w,",") end, seq)   -- split sequences "3,4"
    local month0 = os.date("*t",os.time()).month
    seq = map(function(t) local m = table.remove(lim,1);
        return flatten(map(function (g) return expandDate({g,m},month0) end, t))
      end, seq) -- expand intervalls "3-5"
    return map(seq2map,seq)
  end
  local sun,offs,day,sunPatch = dateStr0:match("^(sun%a+) ([%+%-]?%d+)")
  if sun then
    sun = sun.."Hour"
    dateStr0=dateStr0:gsub("sun%a+ [%+%-]?%d+","0 0")
    sunPatch=function(dateSeq)
      local h,m = (fibaro.getValue(1,sun)):match("(%d%d):(%d%d)")
      dateSeq[1]={[(tonumber(h)*60+tonumber(m)+tonumber(offs))%60]=true}
      dateSeq[2]={[math.floor((tonumber(h)*60+tonumber(m)+tonumber(offs))/60)]=true}
    end
  end
  local dateSeq = parseDateStr(dateStr0)
  return function(currDate) -- Pretty efficient way of testing dates...
    local t = currDate or os.date("*t",os.time())
    if month and month~=t.month then dateSeq=parseDateStr(dateStr0) end -- Recalculate 'last' every month
    if sunPatch and (month and month~=t.month or day~=t.day) then sunPatch(dateSeq) day=t.day end -- Recalculate sunset/sunrise
    return
    dateSeq[1][t.min] and    -- min     0-59
    dateSeq[2][t.hour] and   -- hour    0-23
    dateSeq[3][t.day] and    -- day     1-31
    dateSeq[4][t.month] and  -- month   1-12
    dateSeq[5][t.wday] or false      -- weekday 1-7, 1=sun, 7=sat
  end
end

local cronItems = {}
local cronRef,nxt = nil,0
local function addCronItem(event) -- {type='cron',id=k, time='* * * * *'}
  local dateTest = dateTest(event.time)
  cronItems[dateTest] = event
  local function loop()
    local date = os.date("*t",os.time())
    for dateTest,event in pairs(cronItems) do
      if dateTest(date) then post(event) end
    end
    nxt = nxt + 60
    cronRef = setTimeout(loop,1000*(nxt-os.time()))
  end
  if cronRef == nil then
    nxt = (os.time() // 60 + 1) *60
    cronRef = setTimeout(loop,1000*(nxt-os.time())) 
  end
end 

------------------ Time ---------------------------------
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
  if not (h and m) then error(fmt("Bad hm2sec string %s",hmstr)) end
  return (sg == '-' and -1 or 1)*(tonumber(h)*3600+tonumber(m)*60+(tonumber(s) or 0)+(tonumber(offs or 0))*60)
end

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
  elseif p == 'm/' then
    local t1,t2 = tonumber(time:sub(3)),os.date("*t")
    return 60-t2.sec+t1+os.time()
  else return hm2sec(time) end
end
------------------

local function isEvent(e) return type(e) == 'table' and type(e.type)=='string' end
local eventMT = {
  --__eq = function(e1,e2) return equal(e1,e2) end,
  __tostring = function(e) return fmt("#%s{%s",e.type,encode(e):match(",(.*)")) end
}
local function addEventMT(event) if not getmetatable(event) then setmetatable(event,eventMT) end return event end

local managedEvent = {}
function managedEvent.timer(k,event)
  event = addEventMT(copy(event))
  event.id = k
  DEBUG('post',"post %s at %s",event,timeStr(event.time))
  local t = toTime(event.time)
  if event.aligned and type(event.time) == 'string' and event.time:sub(1,2) == '+/' then
    local t0 = toTime(event.time:sub(3))
    t = ((t-t0) // t0 + 1)*t0
  end
  --if event.aligned then print("ALIGN",os.date("%c",t)) end
  post({type='schedule',event=event,_sh=true},t)
  return event
end
function managedEvent.cron(k,event)
  event = addEventMT(copy(event))
  event.id = k
  addCronItem(event)
  return event
end
function _builtin:_managedEvent(typ,fun)
  assert(type(typ)=='string',"Type expected")
  assert(type(fun)=='function',"Function expected")
  managedEvent[typ] = fun
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

local function compilePattern(pattern)
  if type(pattern) == 'table' then
    if pattern._var_ then return end
    for k,v in pairs(pattern) do
      if type(v) == 'string' and v:sub(1,1) == '$' then
        local var,op,val = v:match("$([%w_]*)([<>=~]*)(.*)")
        var = var =="" and "_" or var
        assert(constraints[op],"Unknown constraint: "..tostring(op))
        local c = constraints[op](tonumber(val) or val)
        pattern[k] = {_var_=var, _constr=c, _str=v}
      else compilePattern(v) end
    end
  end
  return pattern
end

local function unify(pattern,expr,matches)
  if pattern == expr then return true
  elseif type(pattern) == 'table' then
    if pattern._var_ then
      local var, constr = pattern._var_, pattern._constr
      if var == '_' then return constr(expr)
      elseif matches[var] then return constr(expr) and unify(matches[var],expr,matches) -- Hmm, equal?
      else matches[var] = expr return constr(expr) end
    end
    if type(expr) ~= "table" then return false end
    for k,v in pairs(pattern) do if not unify(v,expr[k],matches) then return false end end
    return true
  else return false end
end

local toHash,fromHash={},{}
toHash['device'] = function(e) return "device"..(e.id or "")..(e.property or "") end
toHash['global-variable'] = function(e) return 'global-variable'..(e.name or "") end
toHash['quickvar'] = function(e) return 'quickvar'..(e.id or "")..(e.name or "") end
toHash['profile'] = function(e) return 'profile'..(e.property or "") end
toHash['weather'] = function(e) return 'weather'..(e.property or "") end
toHash['custom-event'] = function(e) return 'custom-event'..(e.name or "") end
toHash['deviceEvent'] = function(e) return 'deviceEvent'..(e.id or "")..(e.value or "") end
toHash['sceneEvent'] = function(e) return 'sceneEvent'..(e.id or "")..(e.value or "") end
toHash['sceneEvent'] = function(e) return 'sceneEvent'..(e.id or "")..(e.value or "") end
toHash['timer'] = function(e) return 'timer'..(e.id or "")..(e.time or "") end
toHash['cron'] = function(e) return 'cron'..(e.id or "")..(e.time or "") end

fromHash['device'] = function(e)
  if not e.property then return {"device"..e.id,"device"} 
  else return {"device"..e.id..e.property,"device"..e.id,"device"..e.property,"device"} end
end
fromHash['global-variable'] = function(e) return {'global-variable'..e.name,'global-variable'} end
fromHash['quickvar'] = function(e) return {"quickvar"..e.id..e.name,"quickvar"..e.id,"quickvar"..e.name,"quickvar"} end
fromHash['profile'] = function(e) return {'profile'..e.property,'profile'} end
fromHash['weather'] = function(e) return {'weather'..e.property,'weather'} end
fromHash['custom-event'] = function(e) return {'custom-event'..e.name,'custom-event'} end
fromHash['deviceEvent'] = function(e) return {"deviceEvent"..e.id..e.value,"deviceEvent"..e.id,"deviceEvent"..e.value,"deviceEvent"} end
fromHash['sceneEvent'] = function(e) return {"sceneEvent"..e.id..e.value,"sceneEvent"..e.id,"sceneEvent"..e.value,"sceneEvent"} end
fromHash['timer'] = function(e) return {"timer"..e.id..e.time} end
fromHash['cron'] = function(e) return {"cron"..e.id..e.time} end

local function addEvent(k,event)
  assert(isEvent(event),"Event expected")
  addEventMT(event)
  if managedEvent[event.type] then event = managedEvent[event.type](k,event) or event end
  local pattern = copy(event)
  compilePattern(pattern)
  local key = toHash[event.type] and toHash[event.type](event) or event.type
  local em = _eMap[key] or {}; _eMap[key]=em
  for _,eventGroup in ipairs(em) do
    if equal(event,eventGroup.event) then table.insert(eventGroup.handlers, k) return end
  end
  em[#em+1] = {event=event, pattern=pattern, handlers={k}}
end

local function lookupEvent(e,handler)
  local keys = fromHash[e.type] and fromHash[e.type](e) or {e.type}
  for _,key in ipairs(keys) do
    local em = _eMap[key]
    if em then
      for _,eventGroup in ipairs(em) do
        local match = {}
        if unify(eventGroup.pattern,e,match) then
          for _,k in ipairs(eventGroup.handlers) do
            handler(k,match)
          end
        end
      end
    end
  end
end

---------------------------------
local function init()
  Event:post({type='QAstart', _sh=true})
end

local eventTransformers = {}
function _builtin:_transformEvent(typ,fun)
  assert(type(typ)=='string',"Type expected")
  assert(type(fun)=='function',"Function expected")
  eventTransformers[typ] = eventTransformers[typ] or {}
  table.insert(eventTransformers[typ],fun)
end

function transformEvent(event) -- single event -> list of events
  local tr = eventTransformers[event.type or ""]
  if not tr then return {event} end
  for _,fun in ipairs(tr) do
    local nevent = fun(event)
    if nevent then return append(table.unpack(map(transformEvent,nevent))) end
  end
  return {event}
end

function trueFor(self,time,cond)
  if self._trueForRef==true then 
    self._trueForRef = nil
    return true 
  end
  if not cond then
    if self._trueForRef then 
      fibaro.cancel(self._trueForRef)
      self._trueForRef = nil
      self._trueForEvent = nil
      self._trueForMatch = nil
      return false 
    end
  else
    if self._trueForRef then 
      self._trueForEvent = self._event
      self._trueForMatch = self._match
      return false
    else
      self._trueForTime  = time
      self._trueForEvent = self._event
      self._trueForMatch = self._match
      local function success()
        self._trueForRef = true
        _handler[self.id](self._trueForEvent,self._trueForMatch)
      end
      self._trueForRef = setTimeout(success,1000*time)
      return false
    end
  end
end

function again(self,n)
  n = n or math.maxinteger
  self._trueForAgain = self._trueForAgain or 0
  if self._trueForAgain >= n-1 then return self._trueForAgain+1 end
  self._trueForAgain = self._trueForAgain + 1
  local function success()
    self._trueForRef = true
    _handler[self.id](self._trueForEvent,self._trueForMatch)
  end
  self._trueForRef = setTimeout(success,1000*self._trueForTime)
  return self._trueForAgain
end

local function debugfun(f,...)
  local args = {...}
  if #args==1 then f(__TAG,args[1])
  else f(__TAG,fmt(...)) end
end

local handlerMT = {
  again = again, 
  trueFor = trueFor,
  post = function(k,event,time)
    local timers = k._timers
    if not timers then timers = {}; k._timers=timers end
    local ref
    ref = post(event,time,nil,function(event) timers[ref]=nil end)
    timers[ref] = true
  end,
  cancel = function(k,ref) 
    fibaro.cancel(ref) 
    local timers = k._timers
    if timers then timers[ref] = nil end  
  end,
  cancelAll = function(k) 
    local timers = k._timers
    if timers then for t,_ in pairs(timers) do k:cancel(t) end  return true end
  end,
  enable = function(k) return fibaro.enable(k.id) end,
  disable = function(k) k:cancelAll(); return fibaro.disable(k.id) end,
  timer = function(k,t,f,...)
    local args = {...}
    return k:post({type='function',fun=f, args=args},t) 
  end,
  debug = function(self,...) fibaro.debug(__TAG,self._tag,...) end,
  trace = function(self,...) fibaro.trace(__TAG,self._tag,...) end,
  warning = function(self,...) fibaro.warning(__TAG,self._tag,...) end,
  error = function(self,...) fibaro.error(__TAG,self._tag,...) end,
  debugf = function(self,fmt,...) debugfun(fibaro.debug,(self._tag or "")..fmt,...) end,
  tracef = function(self,fmt,...) debugfun(fibaro.trace,(self._tag or "")..fmt,...) end,
  warningf = function(self,fmt,...) debugfun(fibaro.warning,(self._tag or "")..fmt,...) end,
  errorf = function(self,fmt,...) debugfun(fibaro.error,(self._tag or "")..fmt,...) end,
}

local function createHandler(k,f)
  local ht = { id = k }
  return setmetatable({},{
    __newindex = function(t,k,v)
      if k == '_tag' and v~=nil then v = "["..color(ht._tagColor or 'green',v).."] " end
      ht[k] = v
    end,
    __index = function(t,k) return ht[k]==nil and handlerMT[k] or ht[k] end,
    __call = function(t,e,match) f(t,e,match) end
  })
end

local anonEvent = 1;
local anonEventName = "event:"
Event = setmetatable({},{
    __index = function(t,k)
      if k == '_' then k = anonEventName..anonEvent end
      if _builtin[k] then return _builtin[k] end
      if not _inited then init() end
      return function(...)
        local es = {...}
        if not es[1] then es = {es} end
        es = append(table.unpack(map(transformEvent,es)))
        if _trigger[k] then _trigger[k]=append(_trigger[k],es) 
        else _trigger[k]=es end
        map(function(e) addEvent(k,e) end, es)
      end
    end,
    __newindex = function(t,k,f)
      if k == '_' then k = anonEventName..anonEvent; anonEvent = anonEvent + 1 end
      assert(not _builtin[k],"Can't redefine builtin Event function:"..k)
      assert(_trigger[k],"Event not defined for: "..tostring(k))
      assert(not _handler[k],"Handler already defined for: "..tostring(k))
      _handler[k]=createHandler(k,f)
    end,
    __call = function(t,k,event,f)
      t[k](event)
      _handler[k]=createHandler(k,f)
    end
  })

function handleEvent(event)
  addEventMT(event)
  lookupEvent(event,function(k,match) 
    local handler = _handler[k]
    if handler._disabled then return end
    handler.date = os.date("*t")
    handler._event = event
    handler._match = match
    return handler(event,match) 
  end)
end

function post(event,time,silent,guard)
  assert(isEvent(event),"Event expected")
  addEventMT(event)
  local now = os.time()
  time = toTime(time or 0)
  time = time < 72*3600 and now+time or time
  time = time-now
  if time < 0 then return nil end
  if not (event._sh or silent) then DEBUG('post',"post %s at %s",event,timeStr(time)) end
  local handler = handleEvent
  if guard then handler = function(event) guard(event) return handleEvent(event) end end
  return setTimeout(function() handler(event) end,1000*time)
end

fibaro.post = post

function fibaro.cancel(ref) clearTimeout(ref) end

local function isEnabled(k) return not _handler[k]._disabled end
function fibaro.enable(k) _handler[k]._disabled = nil end
function fibaro.disable(k) _handler[k]._disabled = true end

function fibaro.remove(k)
  
end

function _builtin:post(...) return post(...) end
function _builtin:cancel(...) return clearTimeout(...) end
function _builtin:cancelAll(k) return _handler[k]:cancelAll() end
function _builtin:enable(k) _handler[k]._disabled = nil end
function _builtin:disable(k) _handler[k]._disabled = true end
function _builtin:remove(...) print("Not implemented") end
function _builtin:attachRefreshstate(...)
  assert(fibaro._APP.trigger,"Trigger lib not included")
  function fibaro._APP.trigger.post(event) 
    if event.type=='device' and event.property=='icon' then return end
    Event:post(event)
  end
  fibaro._APP.trigger.start()
end

Event:_transformEvent('device',
function(event)
  if type(event.id)=='table' then
    local res = {}
    for _,id in ipairs(event.id) do
      local nevent = copy(event)
      nevent.id = id
      res[#res+1] = nevent
    end
    return res
  else return false end
end)

Event.scheduler{type='schedule'}
function Event:scheduler(event)
  if isEnabled(event.event.id) then
    post(event.event,0,true) 
    DEBUG('post',"post %s at %s",event.event,timeStr(event.event.time)) 
  end
  post(event,event.event.time)
end
Event.func{type='function'}
function Event:func(event) 
  local stat,err = pcall(event.fun,table.unpack(event.args or {}))
  if not stat then fibaro.error(err) end
end

local Event2
do
  local ID,FID = nil,nil
  local key = {}
  local props,dprops = {},{tag='_tag',tagColor='_tagColor',debug='_debug'}
  local builtin = {}
  function key.id(t,k,v) FID=v; ID = v=="_" and (anonEventName..anonEvent) or v; props = {} end
  function key.handler(t,k,v) 
    Event[FID] = v
    for k,v in pairs(props) do if k~='tag' then _handler[ID][dprops[k]] = v end end
    _handler[ID]._tag = props.tag and tostring(props.tag) or props.tag==nil and ID or nil
    if props.debug then
      fibaro.trace(__TAG,color('yellow',ID.." defined"))
    end
    ID=nil  
  end
  Event2 = setmetatable({},{
    __index = function(t,k)
      return builtin[k]
    end,
    __newindex = function(t,k,v)
      if key[k] then 
        if k=='id' then assert(ID==nil,"Event: not closed previous Event declaration:"..(ID or ""))
        else assert(ID~=nil,"Event: no Event.id declared") end
        key[k](t,k,v) 
        return 
      elseif dprops[k] then props[k]=v; return end
      error("Invalid Event key: "..k,2)
    end,
    __call = function(t,event)
      Event[ID](event)
    end
  }
)
function builtin:post(event,time) return Event:post(event,time) end
function builtin:cancel(ref) return Event:cancel(ref) end
function builtin:cancelAll(k) return Event:cancelAll(k) end
function builtin:enable(k) return Event:enable(k) end
function builtin:disable(k) return Event:disable(k) end
function builtin:remove(...) Event:remove(...) end
function builtin:attachRefreshstate() return Event:attachRefreshstate() end
end

-------------------------------------
Event_basic = Event
Event_std = Event2
