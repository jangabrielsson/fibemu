do
  local VERSION = "2.0"

  print("QwikAppChild library v"..VERSION)
  local childID = 'ChildID'
  local classID = 'ClassName'
  local callbacksID = 'uiCallbacks'
  
  function QuickApp:initChildDevices() end
  QuickApp.children = {}
  fibaro.debugFlags = fibaro.debugFlags or {}
  fibaro.debugFlags.qwikchild = true
  local fmt = string.format
  local function ERRORF(f,...) fibaro.error(__TAG,fmt(f,...)) end
  local function DEBUGF(f,...)
    if  fibaro.debugFlags['qwikchild'] then fibaro.debug(__TAG,fmt(f,...)) end 
  end

  -- arrayify table. Ensures that empty array is json encoded as "[]"
  local function arrayify(t) 
    if type(t)=='table' then json.util.InitArray(t) end 
    return t
  end
  
  local function traverse(o,f)
    if type(o) == 'table' and o[1] then
      for _,e in ipairs(o) do traverse(e,f) end
    else f(o) end
  end

  -- Convert UI table to new uiView format
  local function UI2NewUiView(UI)
    local uiView = {}
    for _,row in ipairs(UI) do
      local urow = {
        style = { weight = "1.0"},
        type = "horizontal",
      }
      row = #row==0 and {row} or row
      local weight = ({'1.0','0.5','0.25','0.33','0.20'})[#row]
      local uels = {}
      for _,el in ipairs(row) do
        local name = el.button or el.slider or el.label or el.select or el.switch or el.multi
        local typ = el.button and 'button' or el.slider and 'slider' or 
        el.label and 'label' or el.select and 'select' or el.switch and 'switch' or el.multi and 'multi'
        local function mkBinding(name,action,fun,actionName)
          local r = {
            params = {
              actionName = 'UIAction',
              args = {action,name,'$event.value'}
            },
            type = "deviceAction"
          }
          return {r}
        end 
        local uel = {
          eventBinding = {
            onReleased = (typ=='button' or typ=='switch') and mkBinding(name,"onReleased",typ=='switch' and "$event.value" or nil,el.onReleased) or nil,
            onLongPressDown = (typ=='button' or typ=='switch') and mkBinding(name,"onLongPressDown",typ=='switch' and "$event.value" or nil,el.onLongPressDown) or nil,
            onLongPressReleased = (typ=='button' or typ=='switch') and mkBinding(name,"onLongPressReleased",typ=='switch' and "$event.value" or nil,el.onLongPressReleased) or nil,
            onToggled = (typ=='select' or typ=='multi') and mkBinding(name,"onToggled","$event.value",el.onToggled) or nil,
            onChanged = typ=='slider' and mkBinding(name,"onChanged","$event.value",el.onChanged) or nil,
          },
          max = el.max,
          min = el.min,
          step = el.step,
          name = el[typ],
          options = arrayify(el.options),
          values = arrayify(el.values) or ((typ=='select' or typ=='multi') and arrayify({})) or nil,
          value = el.value,
          style = { weight = weight},
          type = typ=='multi' and 'select' or typ,
          selectionType = (typ == 'multi' and 'multi') or (typ == 'select' and 'single') or nil,
          text = el.text,
          visible = true,
        }
        arrayify(uel.options)
        arrayify(uel.values)
        if not next(uel.eventBinding) then 
          uel.eventBinding = nil 
        end
        uels[#uels+1] = uel
      end
      urow.components = uels
      uiView[#uiView+1] = urow
    end
    return uiView
  end
  
  -- Converts UI table to uiCallbacks table
  local function UI2uiCallbacks(UI)
    local cbs = {}
    traverse(UI,
    function(e)
      local typ = e.button and 'button' or e.switch and 'switch' or e.slider and 'slider' or e.select and 'select' or e.multi and 'multi'
      local name = e[typ]
      if typ=='button' or typ=='switch' then
        cbs[#cbs+1]={callback=e.onReleased or "",eventType='onReleased',name=name}
        cbs[#cbs+1]={callback=e.onLongPressDown or "",eventType='onLongPressDown',name=name}
        cbs[#cbs+1]={callback=e.onLongPressReleased or "",eventType='onLongPressReleased',name=name}
      elseif typ == 'slider' then
        cbs[#cbs+1]={callback=e.onChanged or "",eventType='onChanged',name=name}
      elseif typ == 'select' then
        cbs[#cbs+1]={callback=e.onToggled or "",eventType='onToggled',name=name}
      elseif typ == 'multi' then
        cbs[#cbs+1]={callback=e.onToggled or "",eventType='onToggled',name=name}
      end
    end)
    return cbs
  end
  
  -- Intercept UIEvents and call appropriate childQA
  function QuickApp:setupUIhandler()
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

  -- Get/Set internalStorage var for childQA
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
  class 'QwikAppChild'(QuickAppChild)
  function QwikAppChild:__init(device)
    QuickAppChild.__init(self, device)
    local uid = UID or self:internalStorageGet(childID) or ""
    self._className = self:internalStorageGet(classID) or ""
    local uiCallbacks = self:internalStorageGet(callbacksID) or {}
    self.properties.uiCallbacks = uiCallbacks
    self._uid = uid
    quickApp.children[uid]=self -- register child in QuickApp
    self.uiCallbacks = {}
    self:registerUICallbacks()
    self._sid = tonumber(tostring(uid):match("(%d+)$"))
  end
  
  function QuickApp:_createChildDevice(uid, props, className)
    __assert_type(props, 'table')
    local store = props.store or {}
    local room = props.room
    props.room = nil
    props.store = nil
    props.parentId = self.id
    table.insert(props.initialInterfaces, 'quickAppChild')
    local uiCallbacks = props.initialProperties.uiCallbacks
    local device, res = api.post("/plugins/createChildDevice", props)
    assert(res == 200, "Can't create child device " .. tostring(res) .. " - " .. json.encode(props))
    setVar(device.id,childID,uid,true)
    setVar(device.id,classID,className,true)
    if uiCallbacks then setVar(device.id,"uiCallbacks",uiCallbacks,true) end
    for k,v in pairs(store) do 
      setVar(device.id,k,v,true)
    end
    if room then api.put("/devices/"..device.id,{roomID=room}) end
    local deviceClass = _G[className] or QuickAppChild
    local child = deviceClass(device)
    child.parent = self
    self.childDevices[device.id] = child
    return child
  end
  
  local allChildren = {}

  function QuickApp:createChild(uid,props,className,UI)
    __assert_type(uid,'string')
    __assert_type(className,'string')
    quickApp = self
    self:setupUIhandler()
    if not next(allChildren) then
      local devs = api.get("/devices?parentId="..self.id) or {}
      for _,dev in ipairs(devs) do
        local uid = getVar(dev.id,childID)
        if uid then allChildren[uid] = dev.id end
      end
    end
    local id = allChildren[uid]
    if id then
      self.childDevices[id] = nil
      self.children[uid] = nil
      DEBUGF("Deleting existing child ID:%s, UID:'%s'",id,uid)
      api.delete("/plugins/removeChildDevice/" .. id)
    end
    props.initialProperties = props.properties or {}
    props.initialInterfaces = props.interfaces or {}
    if UI then
      __assert_type(UI,'table')
      local uiView = UI2NewUiView(UI)
      local uiCallbacks = UI2uiCallbacks(UI)
      props.initialProperties.uiView = uiView
      props.initialProperties.uiCallbacks = uiCallbacks
    end
    UID = uid
    local c = self:_createChildDevice(uid,props,className)
    UID = nil
    if not c then return end
    DEBUGF("Created new child ID:%s, UID:'%s'",c.id,uid)
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

  local function loadExisting(self,childrenDefs)
    __assert_type(childrenDefs,'table')
    self:setupUIhandler()
    local cdevs,n,gerr = api.get("/devices?parentId="..self.id) or {},0,nil -- Pick up all my children
    for _,child in ipairs(cdevs) do
      local uid = getVar(child.id,childID)
      if uid then allChildren[uid] = child.id end
      if uid and (childrenDefs==nil or childrenDefs[uid]) then
        local className = getVar(child.id,classID) or ""
        DEBUGF("Loading existing child UID:'%s'",uid) 
        local stat,err = pcall(function()
          local deviceClass = _G[className] or QuickAppChild
          local childObject = deviceClass(child) -- Init
          self.childDevices[child.id] = childObject
          childObject.parent = self
        end)
        if not stat then
          ERRORF("loadExistingChildren:%s child ID:%s, UID:'%s'",err,child.id,uid)
          gerr = err
        else
          n=n+1
        end
      end
    end
    return gerr,n
  end
  
  function QuickApp:loadExistingChildren(childrenDefs)
    quickApp = self
    local stat,err = pcall(loadExisting,self,childrenDefs)
    if not stat then ERRORF("loadExistingChildren: %s",err) end
  end

  local function createMissing(self,childrenDefs)
    local chs,k = {},0
    -- Try to create children in uid alphabetical order
    for uid,data in pairs(childrenDefs) do
      local m = uid:sub(1,1)=='i' and 100 or 0; k = k + 1
      chs[#chs+1]={uid=uid,id=m+tonumber(uid:match("(%d+)$") or k),data=data}
    end
    table.sort(chs,function(a,b) return a.id<b.id end)

    for _,ch in ipairs(chs) do
      if not self.children[ch.uid] then -- not loaded yet
        DEBUGF("Creating missing child UID:'%s'",ch.uid)
        local UI = ch.data.UI
        local uid = ch.uid
        local className = ch.data.className
        local props = {
          name = ch.data.name,
          type = ch.data.type,
          properties = ch.data.properties,
          interfaces = ch.data.interfaces,
          store = ch.data.store,
          room = ch.data.room,
        }
        local child = self:createChild(uid,props,className,UI)
      end
    end
  end
  
  function QuickApp:createMissingChildren(children)
    __assert_type(children,'table')
    local stat,err = pcall(createMissing,self,children)
    if not stat then ERRORF("createMissingChildren: %s",err) end
  end

  function QuickApp:removeUndefinedChildren(childrenDefs)
    for uid,id in ipairs(allChildren) do
      if not childrenDefs[uid] then
        DEBUGF("Deleting undefined child ID:%s, UID:%s",id,uid)
        api.delete("/plugins/removeChildDevice/" .. id)
      end
    end
  end
  
  function QuickApp:initChildren(children)
    if self:loadExistingChildren(children) then return end
    self:createMissingChildren(children)
    self:removeUndefinedChildren(children) -- Remove child devices not loaded/created
  end
  
end

--[[
Usage:
  local children = {
    i1 = {
      name='ChildA',
      type='com.fibaro.binarySensor',
      properties={...},
      interfaces={...},
      store={<key>=<value>,...},
      room=<roomID>,
      UI=<UI>,
    },
    i2 = {
      name='ChildB',
      type='com.fibaro.binarySensor',
      properties={...},
      interfaces={...},
      store={<key>=<value>,...},
      room=<roomID>,
      UI=<UI>,
    },
  }
  
  self:initChildren(children)
  -- Will load existing children defined in table.
  -- Will create missing children defined in table.
  -- Will remove existing children not defined in table.

  Alt.
  self:loadExistingChildren()
  -- Load existing children
  self:createChild(uid,props,className,UI)
  -- props = {
  --   name = 'ChildA',
  --   type = 'com.fibaro.binarySensor',
  --   properties = {...},
  --   interfaces = {...},
  --   store = {<key>=<value>,...},
  --   room = <roomID>,
  -- }
--]]
