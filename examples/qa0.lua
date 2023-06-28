--%%remote=globalVariables:A,B
--%%remote=devices:763
--%%debug=permissions:false,refresh_resource:true

--%%file=../TQAE/lib/fibaroExtra.lua,fibaroExtra;

--%%u={{button='t1', text='A', onReleased='t1'},{button='t2', text='B', onReleased='t1'},{button='t3', text='C', onReleased='t1'},{button='t4', text='D', onReleased='t1'},{button='t5', text='E', onReleased='t1'}}
--%%u={button='test', text='Test', onReleased='testFun'}
--%%u={{button='test', text='A', onReleased='testA'},{button='test', text='B', onReleased='testB'}}
--%%u={slider="slider", onChanged='sliderA'}
--%%u={label="lblA", text='THis is a text'}

function QuickApp:onInit()
    self:debug("Started",self.id)
    self:setVariable("test","HELLO")
    IP = fibaro.getIPaddress()
    print(IP)
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