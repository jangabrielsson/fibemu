QuickApp._betterQAversions="0.5"
QuickApp.debugFlags = QuickApp.debugFlags or {}
QuickApp.translations = QuickApp.translations or {}
QuickApp.language = nil

local fmt = string.format
function QuickApp:debugf(f,...) self:debug(fmt(f,...)) end
function QuickApp:tracef(f,...) self:trace(fmt(f,...)) end
function QuickApp:warningf(f,...) self:warning(fmt(f,...)) end
function QuickApp:errorf(f,...) self:error(fmt(f,...)) end

local function getVariable(self,name)
  __assert_type(name, "string")
  for key,value in pairs(self.properties.quickAppVariables) do
    if value.name == name then return value.value end
  end
end

local function setVariable(self, name, value) 
  for k,variable in pairs(self.properties.quickAppVariables) do
    if variable.name == name then
      if value == nil then
        table.remove(self.properties.quickAppVariables,k)
      else variable.value = value end
      self:updateProperty('quickAppVariables', self.properties.quickAppVariables)
      return
    end
  end
  if value == nil then return end
  table.insert(self.properties.quickAppVariables, {name=name, value=value})
  self:updateProperty('quickAppVariables', self.properties.quickAppVariables)
end

local _init = QuickApp.__init

function QuickApp:__init(...)
  local _onInit = self.onInit
  function self:onInit()
    quickApp = self
    self.qvar = setmetatable({},{
      __index = function(t,k) return getVariable(self,k) end,
      __newindex = function(t,k,v) return setVariable(self,k,v) end,   
    })
    self.storage = setmetatable({},{
      __index = function(key) return self:internalStorageGet(key) end,
      __newindex = function(key,val)
        if val == nil then self:internalStorageRemove(key)
        else self:internalStorageSet(key,val) end
      end
    })
    if self.language == nil then
      self.language = api.get("/settings/info").defaultLanguage
    end
    self.lng = setmetatable({},{
      __index = function(t,k)
        local lang = self.language or "en"
        local dict = self.translations[lang]
        if not dict then self:warningf("Language not found: ",lang) return k end
        if not dict[k] then self:warningf("Translation[%s].%s not found",lang,k) return k end
        return dict[k]
      end,
      __newindex = function(t,k,v)
        local lang = self.language or "en"
        self.translations[lang] = self.translations[lang] or {}
        self.translations[lang][k] = v
      end,
    })
    local dev = __fibaro_get_device(self.id)
    if not dev.enabled then
      if self.__disabled then pcall(self.__disabled,self) end
      self:debug("QA ",self.name," disabled")
      function self.actionHandler() end -- Disable external calls
      function self.UIHandler() end -- Disable UI events
      return
    end
    if _onInit then _onInit(self) end
  end
  _init(self,...)
end