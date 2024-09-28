fibaro._MODULES = fibaro._MODULES or {}
local _MODULES = fibaro._MODULES
_MODULES.trace={ author = "jan@gabrielsson.com", version = '0.4', depends={}, init = function()
    local _,_ = fibaro.debugFlags,string.format
  end
} -- Trace functions

