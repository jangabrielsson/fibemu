local pconfig = ...
local luapath = pconfig.path .. "lua/"
local function doload(fname) return dofile(luapath .. fname) end

local RESTART_TIME = 5000 -- 5s wait before restarting QA

doload("json.lua")
doload("net.lua")

local util = doload("utils.lua")
local devices = doload("device.lua")
local resources = doload("resources.lua")
local refreshStates = doload("refreshState.lua")
local files = doload("file.lua")

local timers = util.timerQueue()
local format = string.format

local lldebugger
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    print("Waiting for debugger to attach...")
    local dname = os.getenv("LOCAL_LUA_DEBUGGER_FILEPATH")
    assert(dname, "Please set LOCAL_LUA_DEBUGGER_FILEPATH")
    local file = io.open(dname, "r")
    assert(file, "Could not open " .. dname)
    local data = file:read("*all")
    lldebugger = load(data)()
    lldebugger.start()
    print("Debugger attached")
else
    print("Not waiting for debugger")
end

local config
do
    local f = io.open("config.json", "r")
    if not f then
        print("No config.json")
        config = {}
    else
        config = json.decode(f:read("*all"))
        f:close()
    end
    for k, v in pairs(pconfig) do if config[k] == nil then config[k] = v end end
    config.creds = util.basicAuthorization(config.user or "", config.password or "")
end

config.lcl = config['local'] or false
os.milliclock = config.hooks.clock
local clock = config.hooks.clock
os.http = config.hooks.http

QA, DIR = { config = config, fun = {} }, {}

local libs = { 
    devices = devices, resources = resources, files = files, refreshStates = refreshStates, lldebugger = lldebugger,
    emu = QA
}
os.refreshStates = config.hooks.refreshStates
config.hooks = nil
devices.init(config, luapath.."devices.json", libs)
resources.init(config, libs)
refreshStates.init(config, libs)
files.init(config, libs)

resources.refresh(true)
if not config.lcl then refreshStates.start() end

function QA.syslog(typ, fmt, ...)
    util.debug({ color = true }, typ, format(fmt, ...), "SYS")
end

function QA.syslogerr(typ, fmt, ...)
    util.debug({ color = true }, typ, format(fmt, ...), "SYSERR")
end

local function systemTimer(fun, ms, msg)
    local t = clock() + ms / 1000
    return timers.add(-1, t, fun, { type = 'timer', fun = fun, ms = t, log = "system"..(msg and msg or "") })
end

function string.split(str, sep)
    local fields, s = {}, sep or "%s"
    str:gsub("([^" .. s .. "]+)", function(c) fields[#fields + 1] = c end)
    return fields
end

local function createEnvironment(id)
    local qa = DIR[id]
    local env,dev = {},qa.dev
    local debugFlags, fmt = {}, string.format
    debugFlags.color = true
    qa.env = env

    local function setTimer(f, ms, log)
        assert(type(f) == 'function', "setTimeout first arg need to be function")
        assert(type(ms) == 'number', "setTimeout second arg need to be a number")
        local t = clock() + ms / 1000
        return timers.add(id, t, DIR[id].f, { type = 'timer', fun = f, ms = t, log = log or "" })
    end
    local function clearTimer(ref)
        assert(type(ref) == 'number', "clearTimeout ref need to be number")
        timers.remove(ref)
    end

    local funs = {
        "os", "pairs", "ipairs", "select", "print", "math", "string", "pcall", "xpcall", "table", "error",
        "next", "json", "tostring", "tonumber", "assert", "unpack", "utf8", "collectgarbage", "type",
        "setmetatable", "getmetatable", "rawset", "rawget", "coroutine" -- extra stuff
    }
    for _, k in ipairs(funs) do env[k] = _G[k] end
    env._G = env

    env.setTimeout = setTimer
    env.clearTimeout = clearTimer

    function env.__fibaroSleep(ms) end

    function env.__fibaro_get_global_variable(name) return resources.getResource("globalVariables", name) end

    function env.__fibaro_get_device(id) return resources.getResource("devices", id) end

    function env.__fibaro_get_devices() return util.toarray(resources.getResource("devices") or {}) end

    function env.__fibaro_get_room(id) return resources.getResource("rooms", id) end

    function env.__fibaro_get_scene(id) return resources.getResource("scenes", id) end

    function env.__fibaro_get_device_property(id, prop)
        local d = resources.getResource("devices", id)
        if d then
            local pv = (d.properties or {})[prop]
            return { value = pv, modified = d.modified or 0 }
        end
    end

    function env.__fibaro_get_breached_partitions() end

    function env.__fibaro_add_debug_message(tag, str, typ)
        assert(str, "Missing tag for debug")
        util.debug(debugFlags, tag, str, typ)
    end

    env.plugin = { mainDeviceId = dev.id }
    env.__TAG = "QUICKAPP" .. dev.id

    for _, l in ipairs({ "json.lua", "class.lua", "net.lua", "fibaro.lua", "quickApp.lua" }) do
        local fn = luapath .. l
        QA.syslog("Loading","Library " .. fn)
        local stat, res = pcall(function() loadfile(fn, "t", env)() end)
        if not stat then
            QA.syslogerr("Loading","%s - %s", fn, res)
            qa.env = nil
            return
        end
    end

    env.fibaro.debugFlags = debugFlags
    env.fibaro.config = config
    if debugFlags.dark or config.dark then util.fibColors['TEXT'] = util.fibColors['TEXT'] or 'white' end
    return env
end

local function runner(fc, id)
    local qa = DIR[id]
    qa.f = fc
    if not createEnvironment(id) then return end
    local env = qa.env
    if not files.loadFiles(id) then return end

    local errfun = env.fibaro.error
    local debugFlags = env.fibaro.debugFlags

    local function log(fmt, ...) util.debug(debugFlags, env.__TAG, format(fmt, ...), "SYS") end
    local function logerr(fmt, ...) env.fibaro.error(env.__TAG, format("Error : %s", format(fmt, ...))) end

    local function checkErr(str, f, ...)
        local ok, err = pcall(f, ...)
        if not ok then env.fibaro.error(env.__TAG, format("%s Error: %s", str, err)) end
    end

    collectgarbage("collect")
    for _, qf in ipairs(qa.files) do
        log("Running %s", qf.fname)
        local stat, err = pcall(qf.qa) -- Start QA
        if not stat then
            logerr("Running %s - %s - restarting in 5s", qf.fname, err)
            QA.restart(id, RESTART_TIME)
        end
    end

    local stat, err = pcall(function()
        local qo = env.QuickApp(qa.dev)
        env.quickApp = qo
    end)
    if not stat then
        logerr(":onInit() %s - restarting in 5s", err)
        QA.restart(id, RESTART_TIME)
    end

    local ok, err
    while true do -- QA coroutine loop
        local task = coroutine.yield({ type = 'next', log = "X" })
        ::foo:: if task.type == 'timer' then ok, err = pcall(task.fun) if not ok then errfun(env.__TAG, format("%s Error: %s", "timer", err)) end task = coroutine.yield({ type = 'next' }) goto foo
            -- if task.type == 'timer' then
            --     checkErr("setTimeout", task.fun)
        elseif task.type == 'onAction' then
            checkErr("onAction", env.onAction, id, task)
        elseif task.type == 'UIEvent' then
            checkErr("UIEvent", env.onUIEvent, id, task)
        end
    end
end

local function createQArunner(runner, id)
    local c = coroutine.create(runner)
    local function t(task)
        local res, task = coroutine.resume(c, task)
        --print("X",task.type,task.log,coroutine.status(c))
        if task.type == 'timer' then
            timers.add(id, clock() + task.ms, t, task)
            coroutine.resume(c)
        end
    end
    local stat, res = coroutine.resume(c, t, id) -- Start QA
    if not stat then print(res) end
end

function QA.install(fname, id)
    local qa = files.installQA(fname, id)
    if qa then
        QA.restart(qa.dev.id)
    end
end

function QA.restart(id, delay)
    if DIR[id] then
        delay = delay or 0
        systemTimer(function() createQArunner(runner,id) end, delay, " restart:"..delay)
    end
end

function QA.delete(id)
    if DIR[id] then
        timers.removeId(id)
        DIR[id] = nil
    end
    resources.removeDevice(id)
end

local eventHandler = {}

function eventHandler.onAction(event)
    local id = event.deviceId
    if not DIR[id] then return end
    timers.add(id, 0, DIR[id].f,
        { type = 'onAction', deviceId = id, actionName = event.actionName, args = event.args })
end

function eventHandler.uiEvent(event)
    local id = event.deviceId
    if not DIR[id] then return end
    timers.add(id, clock(), DIR[id].f,
        {
            type = 'UIEvent',
            deviceId = id,
            elementName = event.elementName,
            eventType = event.eventType,
            values = event.values or {}
        })
end

function eventHandler.updateView(event)
    print("UV", json.encode(event))
end

function eventHandler.refreshStates(event)
    refreshStates.newEvent(event.event)
end

function QA.onEvent(event) -- dispatch to event handler
    event = json.decode(event)
    local h = eventHandler[event.type]
    if h then h(event) else print("Unknown event", event.type) end
end

function QA.loop()
    local t, c, task = timers.peek()
    local cl = clock()
    --if t then print("loop",task.type,t-cl,task.log or "") else print("loop") end
    if t then
        local diff = t - cl
        if diff <= 0 then
            timers.pop()
            c(task)
            return 0
        else
            return diff
        end
    end
    return 0.5
end

QA.syslog("BOOT","Lua loader started")