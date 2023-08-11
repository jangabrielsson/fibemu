--[[
    Simple QA with UI elements
    Open browser at http://127.0.0.1:5004/ to interact with this app
--]]

--%%name=QA0
--%%type=com.fibaro.doorSensor
--%%debug=permissions:false,refresh_resource:true
--%% debug=autoui:true

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
    fibaro.create.binarySwitch()
    fibaro.create.binarySensor()
    fibaro.create.multilevelSwitch()
    fibaro.create.multilevelSensor()
    fibaro.create.temperatureSensor()
    fibaro.create.humiditySensor()

    setTimeout(function()
        fibaro.call(5004, "updateProperty", "batteryLevel", 50)
        fibaro.call(5004, "updateProperty", "dead", true)
    end, 5000)

    --local h = api.get('/devices/hierarchy')
    local function printHierarchy(h)
        local res = {}
        local function pr(h, level)
            if not h then return end
            level = level or 0
            res[#res+1]=string.format("%s>%s",string.rep('-', level), h.type)
            if h.children then
                for _, c in ipairs(h.children) do
                    pr(c, level + 2)
                end
            end
        end
        pr(h,0)
        --table.sort(res)
        print("Hierarchy:".."\n"..table.concat(res, "\n"))
    end

    --printHierarchy(h)
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
