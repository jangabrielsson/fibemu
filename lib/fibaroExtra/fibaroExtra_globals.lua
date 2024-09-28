fibaro._MODULES = fibaro._MODULES or {} -- Global
local _MODULES = fibaro._MODULES
_MODULES.globals={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local _,_ = fibaro.debugFlags,string.format
    --Exported: Returns all global variables
    function fibaro.getAllGlobalVariables() 
      return table.map(function(v) return v.name end,api.get("/globalVariables")) 
    end

    --Exported: Create a global variable
    function fibaro.createGlobalVariable(name,value,options)
      __assert_type(name,"string")
      if not fibaro.existGlobalVariable(name) then 
        value = tostring(value)
        local args = table.copy(options or {})
        args.name,args.value=name,value
        return api.post("/globalVariables",args)
      end
    end

    --Exported: Delete a global variable
    function fibaro.deleteGlobalVariable(name) 
      __assert_type(name,"string")
      return api.delete("/globalVariables/"..name) 
    end

    --Exported: Check if a global variable exists
    function fibaro.existGlobalVariable(name)
      __assert_type(name,"string")
      return api.get("/globalVariables/"..name) and true 
    end

    --Exported: Get the type of a global variable <enum,readOnly>
    function fibaro.getGlobalVariableType(name)
      __assert_type(name,"string")
      local v = api.get("/globalVariables/"..name) or {}
      return v.isEnum,v.readOnly
    end

    --Exported: Get the modification time of a global variable
    function fibaro.getGlobalVariableLastModified(name)
      __assert_type(name,"string")
      return (api.get("/globalVariables/"..name) or {}).modified 
    end
  end
} -- Globals

