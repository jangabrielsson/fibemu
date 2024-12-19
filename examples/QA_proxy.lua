--%%name=Proxy test
--%%type=com.fibaro.binarySwitch
--%%proxy="My Proxy"
--%%debug=refresh:false
--%%file=lib/QwikChild.lua,child;
--%%u={slider='slider_ID_0',text='slider',onChanged='fopp'}

class 'MyBinarySwitch'(QwikAppChild)
function MyBinarySwitch:__init(device)
  QwikAppChild.__init(self, device)
  self:trace("MyBinarySwitch",self.id)
end
function MyBinarySwitch:turnOn()
  self:updateProperty("value",true)
  self:trace("turnOn",self.id)
end
function MyBinarySwitch:turnOff()
  self:updateProperty("value",false)
  self:trace("turnOff",self.id)
end

local children = {
  id1 = { name = "Child1", type = "com.fibaro.binarySwitch", className = "MyBinarySwitch" },
  id2 = { name = "Child2", type = "com.fibaro.binarySwitch", className = "MyBinarySwitch" },
}
function QuickApp:onInit()
  self:debug("onInit",self.name,self.id)
  self:initChildren(children)
  self:updateView("slider_ID_0","value","50")
  self:updateProperty("value",true)
end

function QuickApp:fopp(ev)
  print("BARF",ev.values[1])
end

function QuickApp:foo(a,b,c) print(a,b,c) end

function QuickApp:plonk() print("PLONK") end