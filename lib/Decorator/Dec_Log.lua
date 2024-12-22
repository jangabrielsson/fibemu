fibaro.DECORATE = fibaro.DECORATE or {}
local fmt = string.format
local function trace(...)
  fibaro.trace(__TAG,fmt(...)) 
end

function QuickApp:Log_decorator(f,info,args)
  fibaro.DECORATE._DEBUG("Decorating Log",info.name)
  local L = args:match("%s*level%s*=%s*(%w+)") or "DEBUG"
  fibaro.DECORATE._DEBUG(" Level",L)
  local n = 0
  return function(...)
    n = n+1
    local p = {...}
    local args = {select(info.method and 2 or 1,...)}
    local params = {}
    for _,s in ipairs(args) do
      if type(s)=='table' then
        params[#params+1] = fibaro.DECORATE._ENCODEFAST(s)
      elseif type(s)=='string' then
        params[#params+1] = '"'..s..'"'
      else
        params[#params+1] = tostring(s)
      end
    end
    trace("Call[%s]:%s(%s)",n,info.name,#params>0 and table.concat(params,',') or "")
    return f(...)
  end
end
