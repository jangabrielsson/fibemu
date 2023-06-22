local emu,resources,devices,util = nil,nil,nil,nil

local function init(config,libs)
    resources = libs.resources
    devices = libs.devices
    emu = libs.emu
    util = libs.util
end

class 'FakeDevice'
function FakeDevice:__init(type,id)
    self.dev = devices.getDeviceStruct(type)
    self.dev.id = id
    self.id = id
    self.tag = "DEVICE"..id
    DIR[id] = { fname = "<fake>", dev = self.dev, files = {}, name = self.dev.name, tag = self.tag }
    self.qa = DIR[id]
    resources.createDevice(self.dev)
end

function FakeDevice:debug(fmt, ...) util.debug(emu.debugFlags, self.tag, format(fmt, ...), "DEBUG") end

function FakeDevice:debug(...) util.debug({color=true}, self.tag, string.format(...), "DEBUG") end 

local actions = {}
function actions.turnOn(self,task) 
    resources.updateDeviceProp({propertyName='value',id=self.id,value=true}) 
end
function actions.turnOff(self,task)
    resources.updateDeviceProp({propertyName='value',id=id,value=true}) 
end
function actions.setValue(self,task)
    resources.updateDeviceProp({propertyName='value',id=id,value=task.args[1]})
end

function FakeDevice:run()
    local function runner()
        self:debug("ID:%s type:%s",self.dev.id,self.dev.type)
        while true do
            local task = coroutine.yield(0)
            if task.type == 'onAction' then
                if actions[task.actionName] then
                    actions[task.actionName](self,task)
                else
                    self:debug("onAction:%s not implemented",task.actionName)
                end
            end
        end
    end
    self.qa.f = coroutine.wrap(runner)
    self.qa.f()
end

local function createDevice(type,id)
    local f = FakeDevice(type,id)
    f:run()
end

return { init = init, FakeDevice = FakeDevice, createDevice = createDevice }