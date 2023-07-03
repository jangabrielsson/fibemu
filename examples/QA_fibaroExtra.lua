--[[
    QA using fibaroExtra to create child object
    Open browser at http://127.0.0.1:5004/ to interact with this app
    fibaroExtra.lua is expected to be avaible in ../TQAE/lib/fibaroExtra.lua
    relative to this project
--]]

--%%name=QA_fibaroExtra
--%%debug=refresh_resource:true
--%%debug=http:true,hc3_http:true

--%%file=../TQAE/lib/fibaroExtra.lua,fibaroExtra;

--%%u={{button='turnOn', text='On', onReleased='turnOn'},{button='turnOff', text='Off', onReleased='turnOff'}}
--%%u={{button='t1', text='A', onReleased='t1'},{button='t2', text='B', onReleased='t1'},{button='t3', text='C', onReleased='t1'},{button='t4', text='D', onReleased='t1'},{button='t5', text='E', onReleased='t1'}}
--%%u={button='test', text='Test', onReleased='testFun'}
--%%u={{button='test', text='A', onReleased='testA'},{button='test', text='B', onReleased='testB'}}
--%%u={slider="slider", max="80", onChanged='sliderA'}
--%%u={label="lblA", text='This is a text'}

function QuickApp:onInit()
    self:debug("Started",self.id)

    class 'MyChild'(QuickerAppChild)
    function MyChild:__init(args)
        QuickerAppChild.__init(self, args)
        self:debug("Child init",self.id)
    end
    function MyChild:turnOn()
        self:debug("Child turned on")
    end
    function MyChild:turnOff()
        self:debug("Child turned off")
    end

    local child = MyChild{
        uid = 'x',
        name = 'MyChild',
        type = 'com.fibaro.binarySwitch',
    }

    setTimeout(function() fibaro.call(child.id,"turnOn") end, 1000)

    self:event({type='device'},function() end)
end
