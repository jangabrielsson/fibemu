--%%name=HumiditySensor
--%%type=com.fibaro.humiditySensor

function QuickApp:setValue(val)
    self:updateProperty("value",val)
end

function QuickApp:onInit()
end