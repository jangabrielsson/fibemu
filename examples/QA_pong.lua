--%%name=Pong
local timestamp

function QuickApp:onInit()
    self:debug("onInit",self.name,self.id)
end

function QuickApp:pong(from)
    self:debug("pong",from)
    fibaro.call(from,'ping',self.id)
end