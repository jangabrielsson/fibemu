fibaro.debugFlags = fibaro.debugFlags or {}
local debugFlags = fibaro.debugFlags
local exports = {
  BROADCASTVAR = "HC3BROADCAST"
}

local Event
local _trigger = {}
local _builtin = {}
local _handler = {}
local _eMap = {}
local post,handleEvent,trueFor,again
local fmt = string.format
local function DEBUG(tag,...) if debugFlags[tag] then fibaro.debug(__TAG,fmt(...)) end end
fibaro.DEBUG = fibaro.DEBUG or DEBUG

---@diagnostic disable-next-line: undefined-field
assert(os.hms2sec,"Please load lib/OS.lua before lib/Event.lua")
---@diagnostic disable-next-line: undefined-field
local hms2sec,midnight = os.hms2sec,os.midnight
---@diagnostic disable-next-line: undefined-field
local encode = table.encode or json.encode

local function toTime(time)
  if type(time) == 'number' then return time end
  local p = time:sub(1,2)
  if p == '+/' then return hms2sec(time:sub(3))+os.time()
  elseif p == 'n/' then
    local t1,t2 = midnight()+hms2sec(time:sub(3),true),os.time()
    return t1 > t2 and t1 or t1+24*60*60
  elseif p == 't/' then return  hms2sec(time:sub(3))+midnight()
  elseif p == 'h/' then
    local t1,t2 = hms2sec(time:sub(3))//60,os.date("*t")
    local t0 = t2.min*60+t2.sec
    t2.min,t2.sec = 0,0
    local th = os.time(t2)
    return (t1 >= t0 and th+t1 or th+t1+3600)
  elseif p == 'm/' then
    local t1,t2 = tonumber(time:sub(3)),os.date("*t")
    return 60-t2.sec+t1+os.time()
  else return hms2sec(time) end
end
local equal = table.equal
if not equal then
  function equal(e1,e2)
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
end
local function copy(t) local r = {}; for k,v in pairs(t) do r[k]=v end return r end
local function timeStr(time) 
  if type(time) == 'string' then time = toTime(time) end
  if time < 35*24*3600 then time=time+os.time() end
  return os.date("%H:%M:%S",time)
end


local cronItems = {}
local cronRef,nxt = nil,0
local function addCronItem(event) -- {type='cron',id=k, time='* * * * *'}
---@diagnostic disable-next-line: undefined-field
  local dateTest = os.dateTest(event.time)
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

local function isEvent(e) return type(e) == 'table' and type(e.type)=='string' end
local eventMT = {
  __tostring = function(e) 
    local s = encode(e,nil,true)
    s = s:match(",(.*)")
    return s and fmt("#%s{%s",e.type,s) or fmt("#%s{}",e.type)
  end
}
local function addEventMT(event) if not getmetatable(event) then setmetatable(event,eventMT) end return event end

local managedEvent = {}
function managedEvent.timer(k,event)
  event = addEventMT(copy(event))
  event.id = k
  fibaro.DEBUG('post',"post %s at %s",event,timeStr(event.time))
  local t = toTime(event.time)
  post({type='schedule',event=event,_sh=true},event.time)
  return event
end
function managedEvent.cron(k,event)
  event = addEventMT(copy(event))
  event.id = k
  addCronItem(event)
  return event
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
toHash['timer'] = function(e) return 'timer'..(e.id or "")..(e.time or "") end
toHash['cron'] = function(e) return 'cron'..(e.id or "")..(e.time or "") end

fromHash['device'] = function(e) return {"device"..e.id..e.property,"device"..e.id,"device"..e.property,"device"} end
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
  post = function(_,event,time) return post(event,time) end,
  cancel = function(_,ref) return fibaro.cancel(ref) end,
  enable = function(k) return fibaro.enable(k.id) end,
  disable = function(k) return fibaro.disable(k.id) end,
  timer = function(k,t,f,...)
    local args = {...}
    return k:post({type='function',fun=function() f(table.unpack(args)) end},t) 
  end,
  debugf = function(_,...) debugfun(fibaro.debug,...) end,
  tracef = function(_,...) debugfun(fibaro.trace,...) end,
  warningf = function(_,...) debugfun(fibaro.warning,...) end,
  errorf = function(_,...) debugfun(fibaro.error,...) end,
}

local function createHandler(k,f)
  return setmetatable({
    id = k,
  },{
    __index = function(t,k) return handlerMT[k] end,
    __call = function(t,e,match) f(t,e,match) end
  })
end

Event = setmetatable({},{
    __index = function(t,k)
      if _builtin[k] then return _builtin[k] end
      return function(...)
        local es = {...}
        if not es[1] then es = {es} end
        _trigger[k]=es
        for _,e in ipairs(es) do addEvent(k,e) end
      end
    end,
    __newindex = function(t,k,f)
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

function post(event,time,silent)
  assert(isEvent(event),"Event expected")
  addEventMT(event)
  local now = os.time()
  time = toTime(time or 0)
  time = time < 72*3600 and now+time or time
  time = time-now
  if time < 0 then return nil end
  if not (event._sh or silent) then fibaro.DEBUG('post',"post %s at %s",event,timeStr(time)) end
  return setTimeout(function() handleEvent(event) end,1000*time)
end

fibaro.post = post

function fibaro.cancel(ref) clearTimeout(ref) end

local function isEnabled(k) return not _handler[k]._disabled end
function fibaro.enable(k) _handler[k]._disabled = nil end
function fibaro.disable(k) _handler[k]._disabled = true end

function fibaro.remove(k)
  
end

Event.scheduler{type='schedule'}
function Event:scheduler(event)
  if isEnabled(event.event.id) then
    post(event.event,0,true) 
    fibaro.DEBUG('post',"post %s at %s",event.event,timeStr(event.event.time)) 
  end
  post(event,event.event.time)
end

Event.func{type='function'}
function Event:func(event) event.fun() end

local function enableBroadcast()
  assert(fibaro._APP.trigger,"Please load lib/Trigger.lua before lib/Event.lua")
  local count = 0
  if api.get("/globalVariables/"..exports.BROADCASTVAR) == nil then
    api.post("/globalVariables", {name=exports.BROADCASTVAR, value=""})
  end
  fibaro._APP.trigger.GlobalSourceTriggerGV = exports.BROADCASTVAR
  function exports.broadcast(event)
    count = count+1
    event._transID = "B"..quickApp.id..count
    fibaro.setGlobalVariable(exports.BROADCASTVAR, json.encode(event))
  end
end

exports.Event = Event
exports.addEventMT = addEventMT
exports.enableBroadcast = enableBroadcast

fibaro._APP = fibaro._APP or {}
fibaro._APP.event = exports
