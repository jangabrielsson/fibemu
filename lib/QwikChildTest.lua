--%%name=QwikChildTest
--%%type=com.fibaro.genericDevice
--%%file=lib/QwikChild.lua,QwikChild;

class 'MyChild'(QwikAppChild)
function MyChild:__init(device) 
  QwikAppChild.__init(self, device)
  self:debug("Instantiating object",device.name)
end

function MyChild:turnOn()
  self:debug("Turning on",self.name)
end

function MyChild:turnOff()
  self:debug("Turning off",self.name)
end

local children = {
  child1 = { name = "Child 1", type='com.fibaro.binarySwitch', className = "MyChild"},
  child2 = { name = "Child 2", type='com.fibaro.binarySwitch', className = "MyChild"},
}

function QuickApp:onInit()
  self:debug("QwikChildTest")
  self:initChildren(children)

  local childDeviceId1 = self.children['child1'].id
  fibaro.call(childDeviceId1, "turnOn")
end