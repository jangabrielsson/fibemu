--%%name=ZombieTest
--%%type=com.fibaro.binarySwitch
--%%zombie=1492

--%%u={label='l1', text='ABC'}

function QuickApp:turnOn()
  print("turnOn1")
end

function QuickApp:turnOff()
  print("turnOff1")
end

function QuickApp:testFun(a,b)
  print("a+b=",a+b)
end

class 'MyBinarySwitch' (QuickAppChild)
function MyBinarySwitch:__init(device)
  QuickAppChild.__init(self, device)
  self:trace("MyBinarySwitch:__init")
end

function MyBinarySwitch:turnOn()
  self:updateProperty('value',true)
  print("turnOn")
end
function MyBinarySwitch:turnOff()
  self:updateProperty('value',false)
  print("turnOff")
end 

function QuickApp:onInit()
  print("Zombie test")
  self.rid = self.zombieId or self.id
  --api.post("/plugins/updateView", { deviceId = self.id, componentName = 'l1', propertyName = 'text', newValue = 'DEF' })
  --self:updateProperty('value',true)
  --self:setVariable('v1',"123")
  --api.get(string.format("/plugins/callUIEvent?deviceID=%s&eventType=onReleased&elementName=__turnon&value=null",self.zombieId))
  -- local d = self:createChildDevice({
  --   name = "ZombieChild",
  --   type = "com.fibaro.binarySwitch",
  --   initialProperties = {},
  --   initialInterfaces = {}
  --   },QuickAppChild)    
    -- print(d.id)
  self:initChildDevices({
    ["com.fibaro.binarySwitch"] = MyBinarySwitch,
  })
end
