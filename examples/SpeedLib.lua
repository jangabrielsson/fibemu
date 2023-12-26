local traceCalls = { 'call', 'getVariable', 'setVariable','alarm','alert', 'emitCustomEvent', 'scene','profile' }
local nonSpeedCalls = { 'call','alarm','alert', 'scene', 'profile' }
local function LOG(str) fibaro.trace(__TAG,str) end
local fmt = string.format 

local nonSpeedApis = { 'put','delete' }
for _,name in ipairs(traceCalls) do
  local fun = fibaro[name]
  fibaro[name] = function(...)
    local stat = {true}
    if not nonSpeedCalls[name] or (not fibaro.__speedTime) then
      stat = {pcall(fun,...)}
    end
    if not stat[1] then error(stat[2]) end
    if fibaro.debugFlags.fibaro then
      local args = {...}
      local str = string.format("Fibaro call: fibaro.%s(%l) = %l",name,args,{table.unpack(stat,2)})
      LOG(str)
    end
    return table.unpack(stat,2)
  end 
end

for _,name in ipairs({'get','post','put','delete'}) do
  local fun = api[name]
  api[name] = function(...)
    local stat = {true,{},200}
    if not nonSpeedApis[name] or not fibaro.__speedTime then
      stat = {pcall(fun,...)}
    end
    if not stat[1] then error(stat[2]) end
    if fibaro.debugFlags.api then 
      local args = {...}
      for i=1,#args do if type(args[i])=='table' then args[i]=json.encode(args[i]) end end
      local str = string.format("API call: api.%s(%l) = %,40l",name,args,{json.encode(stat[2]),tostring(stat[3])})
      LOG(str) 
    end
    return table.unpack(stat,2)
  end 
end

local timeOffset = 0

local oldTime,oldDate = os.time,os.date

function os.time(t) return t and oldTime(t) or oldTime()+timeOffset end
function os.date(s,b) return (not b) and oldDate(s,os.time()) or oldDate(s,b) end

function fibaro.setTime(str) -- str = "mm/dd/yyyy-hh:mm:ss"
  local function tn(s, v) return tonumber(s) or v end
  local d, hour, min, sec = str:match("(.-)%-?(%d+):(%d+):?(%d*)")
  local month, day, year = d:match("(%d*)/?(%d*)/?(%d*)")
  local t = os.date("*t")
  t.year, t.month, t.day = tn(year, t.year), tn(month, t.month), tn(day, t.day)
  t.hour, t.min, t.sec = tn(hour, t.hour), tn(min, t.min), tn(sec, 0)
  local t1 = os.time(t)
  local t2 = os.date("*t", t1)
  if t.isdst ~= t2.isdst then
      t.isdst = t2.isdst
      t1 = oldTime(t)
  end
  timeOffset = t1 - oldTime()
end

local runTimers,speedHours = nil,0
function fibaro.speedTime(hours)
  speedHours = hours
  local startTime = os.time()*1000
  timeOffset = 0
  local endTime = startTime + hours*60*60*1000
  local function milliseconds() return startTime+timeOffset end
  function os.time(t) return t and oldTime(t) or math.floor(0.5+milliseconds()/1000) end
  function os.date(s,b) return (not b) and oldDate(s,os.time()) or oldDate(s,b) end
  local oldSetTimeout,oldSetInterval = setTimeout,setInterval
  local timerQueue = {}
  function setTimeout(f,t)
    t = milliseconds() + t
    local ref = {f=f,t=t}
    for i,e in ipairs(timerQueue) do
      if e.t >  t then table.insert(timerQueue,i,ref) return ref end
    end
    timerQueue[#timerQueue+1] = ref
    return ref
  end
  function runTimers()
    local now = milliseconds()
    while timerQueue[1] and timerQueue[1].t <= now do
      local e = table.remove(timerQueue,1)
      e.f()
    end
    if now > endTime then
      fibaro.warning(__TAG," SpeedTime ended")
      timerQueue = {}
      fibaro.__speedTime = false
      os.time,os.date = oldTime,oldDate
      setTimeout,setInterval = oldSetTimeout,oldSetInterval
      return
    end
    if #timerQueue > 0 then
      local t = timerQueue[1].t - now
      if t < 0 then t = 0 end
      timeOffset = timeOffset + t
      oldSetTimeout(runTimers,0)
    else
      oldSetTimeout(runTimers,10)
    end
  end
  function clearTimeout(ref)
    for i,e in ipairs(timerQueue) do
      if e == ref then table.remove(timerQueue,i) return end
    end
  end
  fibaro.__speedTime = true
end
fibaro.runTimers = function() 
  fibaro.warning(__TAG,fmt(" SpeedTime started (%shours)",speedHours))
  if runTimers then runTimers() end
end