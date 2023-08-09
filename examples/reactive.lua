

local brightness = Ref(0)
local value = Ref(0)
local state = Ref(false)

function Button:turnOn()
    self:debug("turnON")
    if not success(httpGet("http://x.y.z/temp")) then
        self:debug("Error")
    else value.v = true end
end

function Button:turnOn()
    self:debug("Test pressed")
    QA.props.value = true
    myTemp.value = httpGet("http://x.y.z/temp").temp
end

function Slider:dimmer(value)
    self:debug("Slide", value)
end

Labels.label1.text = "Hello {{QA.value and 'On' or 'Off'}}"
Labels.temp.text = "Temperature {{myTemp}}"

function QA:onInit(enabled)
    QA.props.value = value
    QA.props.state = state
end

-----------------------------------
class 'Button'
class 'Slider'
class 'QA'
function QuickApp:onInit()
    qa = QA()
    setTimeout(function() qa:start() end, 1000)
end

