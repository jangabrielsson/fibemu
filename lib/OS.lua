local fmt = string.format 
local sunCalc

local function hms2sec(str)
  local h,m,s = str:match("(%d%d):(%d%d):?(%d*)")
  return 3600*h+60*m+(s or 0)
end

local function epoch(args)
  local t = os.date("*t")
  for k,v in pairs(args) do t[k] = v end
  return os.time(t)
end

local function midnight() return epoch{hour=0,min=0,sec=0,isdst=false} end
local function now() return os.time()-midnight() end

local function setTimer(fun,time,rep,log)
  local nxt = epoch{hour=0,min=0,sec=0,isdst=false}+hms2sec(time)
  local function logt(t) if log then print(os.date("Next run %c",t)) end return t end
  local ref = {}
  if nxt < os.time() then nxt = nxt + 24*3600 end
  local function loop()
    fun()
    nxt = nxt + 24*3600
    if rep then ref[1] = setTimeout(loop,1000*(logt(nxt)-os.time())) end
  end
  ref[1] = setTimeout(loop,1000*(logt(nxt)-os.time()))
  return ref
end

local function clearTimer(ref)
  if type(ref)=='table' and ref[1] then  clearTimeout(ref[1]) end
end

------------------ sunCalc ------------------
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

function sunCalc(time)
  local hc3Location = api.get("/settings/location") or {}
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

------------------ dateTest ------------------
local function map(f,l) local r={} for i,v in ipairs(l) do r[i]=f(v) end return r end
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

------------------------

local exports = {
  epoch = epoch,
  now = now,
  midnight = midnight,
  hms2sec = hms2sec,
  sunCalc = sunCalc,
  dateTest = dateTest,
  setTimer = setTimer,
  clearTimer = clearTimer,
  weekNumber = function(tm) return tonumber(os.date("%V",tm)) end
}

--export to os.*
for k,v in pairs(exports) do os[k] = v end

--[[
os.setTime("09:59:55")

setTimer(function()
    print("Hello World")
end, "10:00:00", true, true)
--]]