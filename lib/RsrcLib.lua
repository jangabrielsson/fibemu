local Event = Event_std

local globs = {}
local gprops = {
  value = function(t,k) return fibaro.getGlobalVariable(t._gd.name) end
}
local GLOBMT = {
  __index = function(t,k)
    if gprops[k] then return gprops[k](t,k)
    else return t._gd[k] end
  end,
  __newindex = function (t, k, v)
    if k=='watch' then
      Event.id='_'
      Event{type='global-variable',name=t._gd.name}
      function Event:handler(event)
        v(self,event.value,event.old,t)
      end
    else t._gd[k]=v end
  end,
  __tostring = function(t) return t._gd.name end
}
function GLOB(name)
  if globs[name] then return globs[name] end
  local gd = { name = name }
  local g = setmetatable({_gd = gd},GLOBMT)
  globs[name] = g
  return g
end

local devs = {}
local DEVMT = {
  __index = function(t,k)
    return t._dd.rsrc[k] or t._dd.rsrc.properties[k]
  end,
  __newindex = function (t, k, v)
    local p = k:match('watch_(%w+)')
    if p then
      Event.id='_'
      Event{type='device',id=t._dd.id,property=p}
      function Event:handler(event)
        v(self,event,t)
      end
    else t._dd[k]=v end
  end,
  __tostring = function(t) return t._dd.name end
}
function DEV(id)
  if devs[id] then return devs[id] end
  local dd = { id = id, rsrc = api.get("/devices/"..id) }
  assert(dd.rsrc,"No such device:"..tostring(id))
  local d = setmetatable({_dd = dd},DEVMT)
  devs[id] = d
  return d
end