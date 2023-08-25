--[[
    Simple QA with UI elements
    creating and using a proxy QA on the HC3.
    First time run it creates a proxy QA on the HC3 with the
    UI defined in the %%u section - if any.
    If proxy already exists it will use the UI from the proxy QA on the HC3.
    This way the UI is defined and edited in the QA on the HC3.
    The proxy QA will send all events back to the emulated QA.
    The emulated QA will take on the ID of the proxy QA.
--]]

--%%name=My QA2
--%%type=com.fibaro.binarySwitch
--%%debug=permissions:false,refresh_resource:true

--%%u={{button='t1', text='A', onReleased='t1'},{button='t2', text='B', onReleased='t1'},{button='t3', text='C', onReleased='t1'},{button='t4', text='D', onReleased='t1'},{button='t5', text='E', onReleased='t1'}}
--%%u={button='test', text='Test', onReleased='testFun'}
--%%u={{button='test', text='A', onReleased='testA'},{button='test', text='B', onReleased='testB'}}
--%%u={slider="slider", max="80", onChanged='sliderA'}
--%%u={label="lblA", text='This is a text'}

function QuickApp:onInit()
    self:debug("Started", self.id)
    self:setVariable("test", "HELLO")
    fibaro.setGlobalVariable("A", "HELLO")
    setInterval(function()
        self:updateView("lblA", "text", os.date())
    end, 1000)
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
    self:debug("Slide A", ev.values[1])
end

function QuickApp:turnOn()
    self:debug("Turned on")
    self:updateProperty("value", true)
    setTimeout(function() self:updateView("slider", "value", "10") end, 1000)
    setTimeout(function() self:updateView("slider", "value", "90") end, 5000)
end

function QuickApp:turnOff()
    self:debug("Turned off")
    self:updateProperty("value", false)
end