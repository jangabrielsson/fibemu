function property(get,set)
    return {__PROP=true,get=get,set=set}
  end
  
  local function setupProps(cl,t,k,v)
    local props = {}
    function cl.__index(t,k)
      if props[k] then return props[k].get(t)
      else return rawget(cl,k) end
    end
    function cl.__newindex(t,k,v)
      if type(v)=='table' and v.__PROP then
        props[k]=v
      elseif props[k] then props[k].set(t,v)
      else rawset(t,k,v) end
    end
    cl.__newindex(t,k,v)
    return props
  end
  
  function class(name)
    local cl,fmt,index,props = {},string.format,0,nil
    cl.__index = cl
    local cl2 = {}
    cl2.__index = cl
    cl2.__newindex = cl
    function cl.__newindex(t,k,v)
      if type(v)=='table' and v.__PROP and not props then props=setupProps(cl,t,k,v)
      else rawset(t,k,v) end
    end
    local pname = fmt("class %s",name)
    function cl2.__tostring() return pname end
    function cl.__tostring(obj) return fmt("[obj:%s:%s]",name,obj.___index) end
    function cl2.__call(_,...)
      index = index + 1
      local obj = setmetatable({___index=index},cl)
      local init = rawget(cl,'__init')
      if init then init(obj,...) end
      return obj
    end
    _G[name] = setmetatable({ __org = cl },cl2)
    return function(parent)
      setmetatable(cl,parent.__org)
    end
  end