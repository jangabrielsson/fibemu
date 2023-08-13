local fibemu = fibaro.fibemu

local emuDevices = {
    "com.fibaro.binarySwitch",
    "com.fibaro.binarySensor",
    "com.fibaro.multilevelSwitch",
    "com.fibaro.multilevelSensor",
    "com.fibaro.temperatureSensor",
    "com.fibaro.humiditySensor",
    "com.fibaro.doorSensor",
    "com.fibaro.windowSensor",
}
local create = {}
local files = json.decode(fibemu.pyhooks.listDir(fibemu.config.path.."lua/devices"))
for _,name in ipairs(files) do
    local path = fibemu.config.path
    local nf = name:gsub("%.lua","")
    create[nf] = function(args)
        return fibaro.fibemu.install(path.."lua/devices/"..name,args)
    end
end

local getRemoteLogRef
local function getRemoteLog(delay)
    delay = delay or 1000
    assert(type(delay) == 'number', "Delay needs to be a number > 500")
    if delay < 500 then delay = 500 end
    local timestamp
    local function loop()
        local msg = api.get("/debugMessages?from=" .. timestamp, "hc3") -- fetch new logs from the HC3
        if msg and msg.messages then
            for i = #msg.messages, 1, -1 do
                local m = msg.messages[i]
                timestamp = m.timestamp
                __fibaro_add_debug_message(m.tag, m.message, m.type) -- and add them the vscode log
            end
            timestamp = msg.timestamp and msg.timestamp or timestamp
        end
    end
    if not getRemoteLogRef then
        timestamp = os.orgtime()
        getRemoteLogRef = setInterval(loop, delay)
    end
end

fibaro.fibemu.create = create
fibaro.fibemu.getRemoteLog = getRemoteLog

fibaro.fibemu.profiler = os.dofile(fibemu.config.path.."lua/profiler.lua")
function fibaro.fibemu.profiler.log(n)
    print(fibaro.fibemu.profiler.report(n or 30))
end