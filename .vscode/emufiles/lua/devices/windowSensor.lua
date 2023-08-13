--%%name=WindowSensor
--%%type=com.fibaro.doorSensor

function QuickApp:turnOn(delay)
    self:debug("Turned on")
    self:updateProperty("value",true)
   self:updateProperty("state",true)
   if delay then 
    setTimeout(function() self:turnOff() end, delay)
   end
end

function QuickApp:turnOff(delay)
    self:debug("Turned off")
    self:updateProperty("value",false)
    self:updateProperty("state",false)
    if delay then 
        setTimeout(function() self:turnOn() end, delay)
       end
end

function QuickApp:onInit()
end