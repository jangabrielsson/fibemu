local emuDevices = {
    "com.finaro.binarySwitch",
    "com.finaro.binarySensor",
    "com.finaro.multilevelSwitch",
    "com.finaro.multilevelSensor",
    "com.finaro.temperatureSensor",
    "com.finaro.humiditySensor",
}
local create = {}
for _,d in ipairs(emuDevices) do
    local name = d:match("com%.finaro%.(.*)")
    create[name] = function(args)
        fibaro.fibemu.install("examples/devices/"..name..".lua",args)
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

fibaro.create = fibaro.fibemu.create
fibaro.getRemoteLog = fibaro.fibemu.getRemoteLog

