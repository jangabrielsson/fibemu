--%%name=MultilevelSwitch
--%%type=com.fibaro.multilevelSwitch
--%%remote=devices:1236

local value = 0
function QuickApp:turnOn()
    self:debug("Turned on")
    self:setValue(value > 0 and value or 50)
end

function QuickApp:turnOff()
    self:debug("Turned off")
    local v = value
    self:setValue(0)
    value = v
end

function QuickApp:setValue(newValue)
    if type(newValue) == 'table' then newValue = tonumber(newValue.values[1]) end -- event or int
    value = newValue
    self:debug("Set value", value)
    self:updateProperty("value", value)
    self:updateProperty("state", value > 0)
    --self:updateView("__value", "value", tostring(value))
end

local ref
local step = 10
function QuickApp:startLevelIncrease()
    if ref then clearInterval(ref) end
    self:debug("Start level increase")
    ref = setInterval(function()
        print("I", value)
        if value + step >= 99 then
            self:setValue(99)
            clearInterval(ref)
            return
        end
        self:setValue(value + step)
    end, 1000)
end

function QuickApp:startLevelDecrease()
    if ref then clearInterval(ref) end
    self:debug("Start level decrease")
    ref = setInterval(function()
        if value - step <= 0 then
            print("D", value)
            self:setValue(0)
            clearInterval(ref)
            return
        end
        self:setValue(value - step)
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
