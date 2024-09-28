fibaro._MODULES = fibaro._MODULES or {} -- Global
local _MODULES = fibaro._MODULES
_MODULES.customEvents={ author = "jan@gabrielsson.com", version = '0.41', depends={'base'},
  init = function()
    local _,_ = fibaro.debugFlags,string.format
    --Exported: Returns all custom events
    function fibaro.getAllCustomEvents() 
      return table.map(function(v) return v.name end,api.get("/customEvents") or {}) 
    end

    --Exported: Create a custom event
    function fibaro.createCustomEvent(name,userDescription) 
      __assert_type(name,"string" )
      return api.post("/customEvents",{name=name,userDescription=userDescription or ""})
    end

    --Exported: Delete a custom event
    function fibaro.deleteCustomEvent(name) 
      __assert_type(name,"string" )
      return api.delete("/customEvents/"..name) 
    end

    --Exported: Check if a custom event exists
    function fibaro.existCustomEvent(name) 
      __assert_type(name,"string" )
      return api.get("/customEvents/"..name) and true 
    end
  end 
} -- Custom events

