--%%name=MultilevelSwitch
--%%type=com.fibaro.multilevelSwitch

local value = 0
function QuickApp:turnOn()
    self:debug("Turned on")
    self:updateProperty("state", true)
end

function QuickApp:turnOff()
    self:debug("Turned off")
    self:updateProperty("value", 0)
    self:updateProperty("state", false)
end

function QuickApp:setValue(newValue)
    if type(newValue) == 'table' then newValue = tonumber(newValue.values[1]) end
    value = newValue
    if self.properties.state then
        self:debug("Set value", newValue)
        self:updateProperty("value", newValue)
        self:updateProperty("state", newValue > 0)
        self:updateView("__value", "value", tostring(newValue))
    end
end

local ref
local step = 10
function QuickApp:startLevelIncrease()
    if ref then clearInterval(ref) end
    self:debug("Start level increase")
    ref = setInterval(function()
        print("I",value)
        if value+step >= 100 then
            self:setValue(100)
            clearInterval(ref)
            return
        end
        self:setValue(value+step)
    end, 1000)
end

function QuickApp:startLevelDecrease()
    if ref then clearInterval(ref) end
    self:debug("Start level decrease")
    ref = setInterval(function()
        if value-step <= 0 then
            print("D",value)
            self:setValue(0)
            clearInterval(ref)
            return
        end
        self:setValue(value-step)
    end, 1000)
end

function QuickApp:stopLevelChange()
    if ref then
        self:debug("Stop level change")
        clearInterval(ref)
        ref = nil
    end
end

function QuickApp:onInit()
    self:turnOff()
end
