--%%remote=globalVariables:A,B
--%%remote=devices:763
--%%debug=permissions:false,refresh_resource:true

--%%file=../TQAE/lib/fibaroExtra.lua,fibaroExtra;

--%%u={{button='turnOn', text='On', onReleased='turnOn'},{button='turnOff', text='Off', onReleased='turnOff'}}
--%%u={{button='t1', text='A', onReleased='t1'},{button='t2', text='B', onReleased='t1'},{button='t3', text='C', onReleased='t1'},{button='t4', text='D', onReleased='t1'},{button='t5', text='E', onReleased='t1'}}
--%%u={button='test', text='Test', onReleased='testFun'}
--%%u={{button='test', text='A', onReleased='testA'},{button='test', text='B', onReleased='testB'}}
--%%u={slider="slider", max="80", onChanged='sliderA'}
--%%u={label="lblA", text='This is a text'}

function QuickApp:onInit()
    self:debug("Started",self.id)
    self:setVariable("test","HELLO")
    IP = fibaro.getIPaddress()
    print(IP)
    setTimeout(function() self:updateView("lblA","text","FOO") end, 5000)

    class 'MyChild'(QuickerAppChild)
    function MyChild:__init(args)
        QuickerAppChild.__init(self, args)
        self:debug("Child init",self.id)
    end
    function MyChild:turnOn()
        self:debug("Child turned on")
    end

    child = MyChild{
        uid = 'x',
        name = 'MyChild',
        type = 'com.fibaro.binarySwitch',
    }

    setTimeout(function() fibaro.call(5001,"turnOn") end, 1000)
end

print("TIME")
setTimeout(function() print("TIMEOUT") end, 1000)
print("START")
fibaro.sleep(2000)
print("STOP")

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
    self:updateProperty("value",true)
end

function QuickApp:turnOff()
    self:updateProperty("value",false)
end