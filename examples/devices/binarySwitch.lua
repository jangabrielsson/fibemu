--%%name=BinarySwitch
--%%type=com.fibaro.binarySwitch

function QuickApp:turnOn()
    self:debug("Turned on")
    self:updateProperty("value",true)
   self:updateProperty("state",true)
end

function QuickApp:turnOff()
    self:debug("Turned off")
    self:updateProperty("value",false)
    self:updateProperty("state",false)
end

function QuickApp:onInit()
end