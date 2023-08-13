--%%name=TemperatureSensor
--%%type=com.fibaro.temperatureSensor

function QuickApp:setValue(val)
    self:updateProperty("value",val)
end

function QuickApp:onInit()
end