--%%name=ZombieTest
--%%type=com.fibaro.binarySwitch
--%%zombie=1492

--%%u={label='l1', text='ABC'}

function QuickApp:turnOn()
  print("turnOn")
end

function QuickApp:turnOff()
  print("turnOn")
end

function QuickApp:testFun(a,b)
  print("a+b=",a+b)
end

function QuickApp:onInit()
  print("Zombie test")
  self.rid = self.zombieId or self.id
  --api.post("/plugins/updateView", { deviceId = self.id, componentName = 'l1', propertyName = 'text', newValue = 'DEF' })
  self:updateProperty('value',true)
  self:setVariable('v1',"123")
end
