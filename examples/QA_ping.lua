--%%name=Ping

local dev = fibaro.fibemu.install("examples/QA_pong.lua")

function QuickApp:onInit()
    self:debug("onInit",self.name,self.id)
    fibaro.sleep(100)
    self:ping(dev.id)
end

function QuickApp:ping(from)
    self:debug("ping",from)
    fibaro.sleep(3000)
    fibaro.call(from,'pong',self.id)
end