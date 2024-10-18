----------- Child class
do
  local childID = 'ChildID'
  local classID = 'ClassName'
  local defChildren

  local children = {}
  local undefinedChildren = {}
  local createChild = QuickApp.createChildDevice
  class 'QwikAppChild'(QuickAppChild)

  local fmt = string.format

  local function getVar(deviceId,key)
    local res, stat = api.get("/plugins/" .. deviceId .. "/variables/" .. key)
    if stat ~= 200 then return nil end
    return res.value
  end
  
  local function setupUIhandler(self)
    if not self.UIHandler then
      function self:UIHandler(event)
        local obj = self
        if self.id ~= event.deviceId then obj = (self.childDevices or {})[event.deviceId] end
        if not obj then return end
        local elm,etyp = event.elementName, event.eventType
        local cb = obj.uiCallbacks or {}
        if obj[elm] then return obj:callAction(elm, event) end
        if cb[elm] and cb[elm][etyp] and obj[cb[elm][etyp]] then return obj:callAction(cb[elm][etyp], event) end
        if obj[elm.."Clicked"] then return obj:callAction(elm.."Clicked", event) end
        self:warning("UI callback for element:", elm, " not found-")
      end
    end
  end

  local UID = nil
  function QwikAppChild:__init(device)
    QuickAppChild.__init(self, device)
    self:debug(fmt("Instantiating ID:%s '%s'",device.id,device.name))
    local uid = UID or self:internalStorageGet(childID) or ""
    self._uid = uid
    --if defChildren[uid] then
      children[uid]=self               -- Keep table with all children indexed by uid. uid is unique.
    --else                               -- If uid not in our children table, we will remove this child
    --  undefinedChildren[#undefinedChildren+1]=self.id
    --end
    self._sid = tonumber(uid:match("(%d+)$"))
  end

  function QuickApp:createChildDevice(uid,props,interfaces,className)
    __assert_type(uid,'string')
    __assert_type(className,'string')
    props.initialProperties = props.initialProperties or {}
    props.initialInterfaces = interfaces
    --self:debug("Creating device ",props.name)
    UID = uid
    local c = createChild(self,props,_G[className])
    UID = nil
    if not c then return end
    c:internalStorageSet(childID,uid,true)
    c:internalStorageSet(classID,className,true)
    return c
  end

  function QuickApp:loadExistingChildren(chs)
    __assert_type(chs,'table')
    local rerr = false
    local stat,err = pcall(function()
      defChildren = chs
      self.children = children
      function self.initChildDevices() end
      local cdevs,n = api.get("/devices?parentId="..self.id) or {},0 -- Pick up all my children
      for _,child in ipairs(cdevs) do
        local uid = getVar(child.id,childID)
        local className = getVar(child.id,classID)
        print(child.id,uid,className)
        local childObject = nil
        local stat,err = pcall(function()
          childObject = _G[className] and _G[className](child) or QuickAppChild(child)
          self.childDevices[child.id]=childObject
          childObject.parent = self
        end)
        if not stat then
          self:error("loadExistingChildren:"..err)
          rerr=true
        end
      end
    end)
    if not stat then rerr=true self:error("loadExistingChildren:"..err) end
    return rerr
  end

  function QuickApp:createMissingChildren()
    local stat,err = pcall(function()
      local chs,k = {},0
      for uid,data in pairs(defChildren) do
        local m = uid:sub(1,1)=='i' and 100 or 0
        k = k + 1
        chs[#chs+1]={uid=uid,id=m+tonumber(uid:match("(%d+)$") or k),data=data}
      end
      table.sort(chs,function(a,b) return a.id<b.id end)
      for _,ch in ipairs(chs) do
        if not self.children[ch.uid] then
          local props = {
            name = ch.data.name,
            type = ch.data.type,
            initialProperties = ch.data.properties,
          }
          self:createChildDevice(ch.uid,props,ch.data.interfaces,ch.data.className)
        end
      end
    end)
    if not stat then self:error("createMissingChildren:"..err) end
  end

  function QuickApp:removeUndefinedChildren()
    for _,deviceId in ipairs(undefinedChildren) do -- Remove children not in children table
      self:removeChildDevice(deviceId)
    end
  end

  function QuickApp:initChildren(children)
    setupUIhandler(self)
    if self:loadExistingChildren(children) then return end
    self:createMissingChildren()
    self:removeUndefinedChildren()
  end
end