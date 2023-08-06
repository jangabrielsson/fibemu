--[[
    Simple QA with UI elements
    Open browser at http://127.0.0.1:5004/ to interact with this app
--]]

--%%name=QA0
--%%debug=permissions:false,refresh_resource:true
--%% debug=autoui:true

--%%u={{button='turnOn', text='On', onReleased='turnOn'},{button='turnOff', text='Off', onReleased='turnOff'}}
--%%u={{button='t1', text='A', onReleased='t1'},{button='t2', text='B', onReleased='t1'},{button='t3', text='C', onReleased='t1'},{button='t4', text='D', onReleased='t1'},{button='t5', text='E', onReleased='t1'}}
--%%u={button='test', text='Test', onReleased='testFun'}
--%%u={{button='test', text='A', onReleased='testA'},{button='test', text='B', onReleased='testB'}}
--%%u={slider="slider", max="80", onChanged='sliderA'}
--%%u={label="lblA", text='This is a text'}
 
function QuickApp:onInit()
    self:debug("Started",self.id)
    self:setVariable("test","HELLO")
    fibaro.setGlobalVariable("A","HELLO")
    setInterval(function()
        self:updateView("lblA","text",os.date())
    end, 1000)
    fibaro.fibemu.install("examples/devices/binarySwitch.lua",6000)
    fibaro.fibemu.install("examples/devices/binarySensor.lua",6001)
    fibaro.fibemu.install("examples/devices/multilevelSwitch.lua",6002)
    fibaro.fibemu.install("examples/devices/multilevelSensor.lua",6003)
end

function QuickApp:testFun()
    self:debug("Test pressed")
end
function QuickApp:testA()
    self:debug("A pressed")
end
function QuickApp:testB()
    self:debug("B pressed")
end
function QuickApp:sliderA(ev)
    self:debug("Slide A",ev.values[1])
end

function QuickApp:turnOn()
    self:debug("Turned on")
    self:updateProperty("value",true)
    setTimeout(function() self:updateView("slider","value","10") end, 1000)
    setTimeout(function() self:updateView("slider","value","90") end, 5000)
end

function QuickApp:turnOff()
    self:debug("Turned off")
    self:updateProperty("value",false)
end