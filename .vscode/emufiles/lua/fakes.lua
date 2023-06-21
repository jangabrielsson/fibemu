local emu,resources,devices = nil,nil,nil

local function init(config,libs)
    resources = libs.resources
    devices = libs.devices
    emu = libs.emu
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

function FakeDevice:debug(...) print(self.tag,...) end 

function FakeDevice:run()
    local function runner()
        self:debug("ID:",self.id,"type",self.dev.type)
        while true do
            local task = coroutine.yield(0)
            if task.type == 'onAction' then
                print(json.encode(task))
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