fibaro.debugFlags = fibaro.debugFlags or {}
local fmt = string.format
local debugFlags = fibaro.debugFlags

local function setDefaults(flag,value)
  if debugFlags[flag]==nil then debugFlags[flag]=value end
end

setDefaults('propWarn',true)

function fibaro.restartQA(id)
  __assert_type(id,"number")
  return api.post("/plugins/restart",{deviceId=id or plugin.mainDeviceId})
end

function fibaro.getQAVariable(id,name)
  __assert_type(id,"number")
  __assert_type(name,"string")
  local props = (api.get("/devices/"..(id or plugin.mainDeviceId)) or {}).properties or {}
  for _, v in ipairs(props.quickAppVariables or {}) do
    if v.name==name then return v.value end
  end
end

function fibaro.setQAVariable(id,name,value)
  __assert_type(id,"number")
  __assert_type(name,"string")
  return fibaro.call(id,"setVariable",name,value)
end

function fibaro.getAllQAVariables(id)
  __assert_type(id,"number")
  local props = (api.get("/devices/"..(id or plugin.mainDeviceId)) or {}).properties or {}
  local res = {}
  for _, v in ipairs(props.quickAppVariables or {}) do
    res[v.name]=v.value
  end
  return res
end

function fibaro.isQAEnabled(id)
  __assert_type(id,"number")
  local dev = api.get("/devices/"..(id or plugin.mainDeviceId))
  return (dev or {}).enabled
end

function fibaro.setQAValue(device, property, value)
  fibaro.call(device, "updateProperty", property, (json.encode(value)))
end

function fibaro.enableQA(id,enable)
  __assert_type(id,"number")
  __assert_type(enable,"boolean")
  return api.post("/devices/"..(id or plugin.mainDeviceId),{enabled=enable==true})
end

function QuickApp.debug(_,...) fibaro.debug(nil,...) end
function QuickApp.trace(_,...) fibaro.trace(nil,...) end
function QuickApp.warning(_,...) fibaro.warning(nil,...) end
function QuickApp.error(_,...) fibaro.error(nil,...) end
function QuickApp.debugf(_,...) fibaro.debugf(nil,...) end
function QuickApp.tracef(_,...) fibaro.tracef(nil,...) end
function QuickApp.warningf(_,...) fibaro.warningf(nil,...) end
function QuickApp.errorf(_,...) fibaro.errorf(nil,...) end

-- Like self:updateView but with formatting. Ex self:setView("label","text","Now %d days",days)
function QuickApp:setView(elm,prop,str,...)
  local str = fmt(str,...)
  self:updateView(elm,prop,str)
end

-- Get view element value. Ex. self:getView("mySlider","value")
function QuickApp:getView(elm,prop)
  assert(type(elm)=='string' and type(prop)=='string',"Strings expected as arguments")
  local function find(s)
    if type(s) == 'table' then
      if s.name==elm then return s[prop]
      else for _,v in pairs(s) do local r = find(v) if r then return r end end end
    end
  end
  return find(api.get("/plugins/getView?id="..self.id)["$jason"].body.sections)
end

-- Change name of QA. Note, if name is changed the QA will restart
function QuickApp:setName(name)
  if self.name ~= name then api.put("/devices/"..self.id,{name=name}) end
  self.name = name
end

-- Set log text under device icon - optional timeout to clear the message
function QuickApp:setIconMessage(msg,timeout)
  if self._logTimer then clearTimeout(self._logTimer) self._logTimer=nil end
  self:updateProperty("log", tostring(msg))
  if timeout then 
    self._logTimer=setTimeout(function() self:updateProperty("log",""); self._logTimer=nil end,1000*timeout) 
  end
end

-- Disable QA. Note, difficult to enable QA...
function QuickApp:setEnabled(bool)
  local d = __fibaro_get_device(self.id)
  if d.enabled ~= bool then api.put("/devices/"..self.id,{enabled=bool}) end
end

-- Hide/show QA. Note, if state is changed the QA will restart
function QuickApp:setVisible(bool) 
  local d = __fibaro_get_device(self.id)
  if d.visible ~= bool then api.put("/devices/"..self.id,{visible=bool}) end
end

function QuickApp.post(_,...) return fibaro.post(...) end
function QuickApp.event(_,...) return fibaro.event(...) end
function QuickApp.cancel(_,...) return fibaro.cancel(...) end
function QuickApp.postRemote(_,...) return fibaro.postRemote(...) end
function QuickApp.publish(_,...) return fibaro.publish(...) end
function QuickApp.subscribe(_,...) return fibaro.subscribe(...) end

function QuickApp:setVersion(model,serial,version)
  local m = model..":"..serial.."/"..version
  if __fibaro_get_device_property(self.id,'model') ~= m then
    quickApp:updateProperty('model',m) 
  end
end

function fibaro.deleteFile(deviceId,file)
  local name = type(file)=='table' and file.name or file
  return api.delete("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files/"..name)
end

function fibaro.updateFile(deviceId,file,content)
  if type(file)=='string' then
    file = {isMain=false,type='lua',isOpen=false,name=file,content=""}
  end
  file.content = type(content)=='string' and content or file.content
  return api.put("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files/"..file.name,file) 
end

function fibaro.updateFiles(deviceId,list)
  if #list == 0 then return true end
  return api.put("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files",list) 
end

function fibaro.createFile(deviceId,file,content)
  if type(file)=='string' then
    file = {isMain=false,type='lua',isOpen=false,name=file,content=""}
  end
  file.content = type(content)=='string' and content or file.content
  return api.post("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files",file) 
end

function fibaro.getFile(deviceId,file)
  local name = type(file)=='table' and file.name or file
  return api.get("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files/"..name) 
end

function fibaro.getFiles(deviceId)
  local res,code = api.get("/quickApp/"..(deviceId or plugin.mainDeviceId).."/files")
  return res or {},code
end

function fibaro.copyFileFromTo(fileName,deviceFrom,deviceTo)
  deviceTo = deviceTo or plugin.mainDeviceId
  local copyFile = fibaro.getFile(deviceFrom,fileName)
  assert(copyFile,"File doesn't exists")
  fibaro.addFileTo(copyFile.content,fileName,deviceTo)
end

function fibaro.addFileTo(fileContent,fileName,deviceId)
  deviceId = deviceId or plugin.mainDeviceId
  local file = fibaro.getFile(deviceId,fileName)
  if not file then
    local _,res = fibaro.createFile(deviceId,{   -- Create new file
    name=fileName,
    type="lua",
    isMain=false,
    isOpen=false,
    content=fileContent
  })
  if res == 200 then
    fibaro.debug(nil,"File '",fileName,"' added")
  else quickApp:error("Error:",res) end
elseif file.content ~= fileContent then
  local _,res = fibaro.updateFile(deviceId,{   -- Update existing file
  name=file.name,
  type="lua",
  isMain=file.isMain,
  isOpen=file.isOpen,
  content=fileContent
})
if res == 200 then
  fibaro.debug(nil,"File '",fileName,"' updated")
else fibaro.error(nil,"Error:",res) end
else
  fibaro.debug(nil,"File '",fileName,"' not changed")
end
end

function fibaro.getFQA(deviceId) return api.get("/quickApp/export/"..deviceId) end

function fibaro.putFQA(content) -- Should be .fqa json
  if type(content)=='table' then content = json.encode(content) end
  return api.post("/quickApp/",content)
end

-- Add interfaces to QA. Note, if interfaces are added the QA will restart
function QuickApp:addInterfaces(interfaces)
  assert(type(interfaces) == "table")
  local d, map, i2, res = __fibaro_get_device(self.id), {}, {}, {}
  for _, i in ipairs(d.interfaces or {}) do map[i] = true end
  for _, i in ipairs(interfaces) do i2[i] = true end
  for j, _ in pairs(i2) do if map[j] then i2[j]=nil end end
  for j,_ in pairs(i2) do res[#res+1]=j end
  if res[1] then
    api.post("/plugins/interfaces", { action = 'add', deviceId = self.id, interfaces = res })
  end
end

local _updateProperty = QuickApp.updateProperty
function QuickApp:updateProperty(prop,value)
  local _props = self.properties
  if _props==nil or _props[prop] ~= nil then
    return _updateProperty(self,prop,value)
  elseif debugFlags.propWarn then self:warningf("Trying to update non-existing property - %s",prop) end
end

function QuickApp.setChildIconPath(_,childId,path)
  api.put("/devices/"..childId,{properties={icon={path=path}}})
end

--Ex. self:callChildren("method",1,2) will call MyClass:method(1,2)
function QuickApp:callChildren(method,...)
  for _,child in pairs(self.childDevices or {}) do 
    if child[method] then 
      local stat,res = pcall(child[method],child,...)  
      if not stat then self:debug(res,2) end
    end
  end
end

function QuickApp:removeAllChildren()
  for id,_ in pairs(self.childDevices or {}) do self:removeChildDevice(id) end
end

function QuickApp:numberOfChildren()
  local n = 0
  for _,_ in pairs(self.childDevices or {}) do n=n+1 end
  return n
end