fibaro.DECORATE = fibaro.DECORATE or {}
local _setup = false
local private = {}

local function setup()
  local c = QuickApp.callAction
  function QuickApp:callAction(name,...)
    if private[name] then
      self:warning("callAction: Private blocked: " .. tostring(name))
      return
    end
    return c(self,name,...)
  end
  _setup = true
end

function QuickApp:Private_decorator(f,info,args)
  if not _setup then setup() end
  local q,name = info.name:match("(.-):([%w_]+)")
  if q~="QuickApp" then 
    fibaro.error(__TAG,"Private decorator must be on QuickApp method")
    return
  end
  fibaro.DECORATE._DEBUG("Annotating Private",info.name,args)
  private[name]=true
  return f
end
