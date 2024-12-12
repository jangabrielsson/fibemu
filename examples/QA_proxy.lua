--%%name=Proxy test
--%%type=com.fibaro.binarySwitch
--%%proxy="My Proxy"
--%%debug=refresh:false
--%%file=.vscode/emufiles/lua/proxy.lua,proxy;
--%%u={slider='slider_ID_0',text='slider',onChanged='fopp'}

function QuickApp:onInit()
  self:debug("onInit",self.name,self.id)
  self:updateView("slider_ID_0","value","50")
  self:updateProperty("value",true)
end

function QuickApp:fopp(ev)
  print("BARF",ev.values[1])
end

function QuickApp:foo(a,b,c) print(a,b,c) end

function QuickApp:plonk() print("PLONK") end