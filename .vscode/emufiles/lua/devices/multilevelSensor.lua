--%%name=MultilevelSensor
--%%type=com.fibaro.multilevelSensor

function QuickApp:setValue(val)
    self:updateProperty("value",val)
    self:updateProperty("state",val > 0)
end

function QuickApp:onInit()
end