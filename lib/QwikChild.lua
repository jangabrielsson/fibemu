do
  local VERSION = "1.2"
  print("QwikAppChild library v"..VERSION)
  local childID = 'ChildID'
  local classID = 'ClassName'
  
  local children = {}
  local createChild = QuickApp.createChildDevice
  function QuickApp:initChildDevices() end
  QuickApp.debugQwikAppChild = true
  
  class 'QwikAppChild'(QuickAppChild)
  
  local fmt = string.format
  
  local function getVar(deviceId,key)
    local res, stat = api.get("/plugins/" .. deviceId .. "/variables/" .. key)
    if stat ~= 200 then return nil end
    return res.value
  end
  local function setVar(deviceId,key,val,hidden)
    local data = { name = key, value = val, isHidden = hidden }
    local _, stat = api.put("/plugins/" .. deviceId .. "/variables/" .. key, data)
    if stat > 206 then
      local _, stat = api.post("/plugins/" .. deviceId .. "/variables", data)
      return stat
    end
  end
  
  local UID = nil
  function QwikAppChild:__init(device)
    QuickAppChild.__init(self, device)
    local uid = UID or self:internalStorageGet(childID) or ""
    self._uid = uid
    self._className = self:internalStorageGet(classID) or ""
    children[uid]=self
    self._sid = tonumber(uid:match("(%d+)$"))
  end
  
  function QuickApp:createChildDevice1(uid, props, className)
    __assert_type(props, 'table')
    local deviceClass = _G[className]
    local store = props.store or {}
    local room = props.room
    props.room = nil
    props.store = nil
    props.parentId = self.id
    props.initialInterfaces = props.initialInterfaces or {}
    table.insert(props.initialInterfaces, 'quickAppChild')
    local device, res = api.post("/plugins/createChildDevice", props)
    assert(res == 200, "Can't create child device " .. tostring(res) .. " - " .. json.encode(props))
    for k,v in pairs(store) do
      setVar(device.id,k,v,true)
    end
    setVar(device.id,childID,uid,true)
    setVar(device.id,classID,className,true)
    if room then api.put("/devices/"..device.id,{roomID=room}) end
    deviceClass = deviceClass or QuickAppChild
    local child = deviceClass(device)
    child.parent = self
    self.childDevices[device.id] = child
    return child
  end
  
  function QuickApp:createChildDevice0(uid,props,interfaces,className)
    __assert_type(uid,'string')
    __assert_type(className,'string')
    props.initialProperties = props.initialProperties or {}
    props.initialInterfaces = interfaces
    UID = uid
    local c = self:createChildDevice1(uid,props,className)
    UID = nil
    if not c then return end
    return c
  end
  
  function QuickApp:getChildrenUidMap()
    local cdevs,map = api.get("/devices?parentId="..self.id) or {},{}
    for _,child in ipairs(cdevs) do
      local uid = getVar(child.id,childID)
      local className = getVar(child.id,classID)
      if uid then map[uid]={id=child.id,className=className} end
    end
    return map
  end
  
  function QuickApp:loadExistingChildren(chs)
    __assert_type(chs,'table')
    local rerr = false
    local stat,err = pcall(function()
      self.children = children
      local cdevs,n = api.get("/devices?parentId="..self.id) or {},0 -- Pick up all my children
      for _,child in ipairs(cdevs) do
        local uid = getVar(child.id,childID)
        local className = getVar(child.id,classID)
        local childObject = nil
        if chs[uid] then
          if QuickApp.debugQwikAppChild then
            self:debug(fmt("Loading existing child UID:'%s'",uid))
          end
          local stat,err = pcall(function()
            childObject = _G[className] and _G[className](child) or QuickAppChild(child)
            self.childDevices[child.id] = childObject
            childObject.parent = self
          end)
          if not stat then
            self:error(fmt("loadExistingChildren:%s child UID:%s",err,uid))
            rerr=true
          end
        end
      end
    end)
    if not stat then rerr=true self:error("loadExistingChildren:"..err) end
    return rerr
  end
  
  function QuickApp:createMissingChildren(children)
    local stat,err = pcall(function()
      local chs,k = {},0
      for uid,data in pairs(children) do
        local m = uid:sub(1,1)=='i' and 100 or 0
        k = k + 1
        chs[#chs+1]={uid=uid,id=m+tonumber(uid:match("(%d+)$") or k),data=data}
      end
      table.sort(chs,function(a,b) return a.id<b.id end)
      for _,ch in ipairs(chs) do
        if not self.children[ch.uid] then -- not loaded yet
          if QuickApp.debugQwikAppChild then
            self:debug(fmt("Creating missing child UID:'%s'",ch.uid))
          end
          local props = {
            name = ch.data.name,
            type = ch.data.type,
            initialProperties = ch.data.properties,
          }
          self:createChildDevice0(ch.uid,props,ch.data.interfaces,ch.data.className)
        end
      end
    end)
    if not stat then self:error("createMissingChildren:"..err) end
  end
  
  function QuickApp:removeUndefinedChildren(children)
    local cdevs = api.get("/devices?parentId="..self.id)
    for _,child in ipairs(cdevs) do
      if not self.childDevices[child.id] then
        if QuickApp.debugQwikAppChild then
          self:debug(fmt("Deleting undefined child ID:%s",child.id))
        end
        api.delete("/plugins/removeChildDevice/" .. child.id)
      end
    end
  end
  
  function QuickApp:initChildren(children)
    if self:loadExistingChildren(children) then return end
    self:createMissingChildren(children)
    self:removeUndefinedChildren(children) -- Remove child devices not loaded/created
  end
end