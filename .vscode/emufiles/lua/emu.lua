local pconfig = ...
local luapath = pconfig.path .. "lua/"
local function doload(fname) return dofile(luapath .. fname) end

local RESTART_TIME = 5000 -- 5s wait before restarting QA

doload("json.lua")
doload("net.lua")
doload("class.lua")

local util = doload("utils.lua")
local devices = doload("device.lua")
local resources = doload("resources.lua")
local refreshStates = doload("refreshState.lua")
local files = doload("file.lua")
local fakes = doload("fakes.lua")

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

local config = pconfig
config.creds = util.basicAuthorization(config.user or "", config.password or "")

config.lcl = config['local'] or false
os.milliclock = config.hooks.clock
local clock = config.hooks.clock
os.http,os.httpAsync = config.hooks.http,config.hooks.httpAsync
local hooks = config.hooks
config.hooks = nil

QA, DIR = { config = config, fun = {}, debug={} }, {}
local debugFlags = QA.debug
debugFlags.color = true
debugFlags.refresh = true

local libs = { 
    devices = devices, resources = resources, files = files, refreshStates = refreshStates, lldebugger = lldebugger,
    emu = QA, util = util, binser = doload("binser.lua"), ui = doload("ui.lua"),
}

os.refreshStates = hooks.refreshStates
devices.init(config, luapath.."devices.json", libs)
resources.init(config, libs)
refreshStates.init(config, libs)
files.init(config, libs)
fakes.init(config, libs)
util.init(config, libs)

--resources.refresh(true)
if not config.lcl then refreshStates.start() end

function QA.syslog(typ, fmt, ...)
    util.debug({ color = true }, typ, format(fmt, ...), "SYS")
end

QA.syslog('boot',"Fibemu v%s",config.version)
QA.syslog('boot',"Web UI : %s",config.webURL)
QA.syslog('boot',"API Doc: %s",config.apiDocURL)
QA.syslog('boot',"API EP : %s",config.apiURL)

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
    local debugFlags, fmt = qa.debug, string.format
    if debugFlags.color == nil then debugFlags.color = true end
    qa.env = env

    local function setTimer(f, ms, log)
        assert(type(f) == 'function', "setTimeout first arg must be function")
        assert(type(ms) == 'number', "setTimeout second arg must be a number")
        local t = clock() + ms / 1000
        return timers.add(id, t, DIR[id].f, { type = 'timer', fun = f, ms = t, log = log or "" })
    end
    local function clearTimer(ref)
        assert(type(ref) == 'number', "clearTimeout arg must be number")
        timers.remove(ref)
    end

    os.debug = debug
    local funs = {
        "os", "pairs", "ipairs", "select", "print", "math", "string", "pcall", "xpcall", "table", "error",
        "next", "json", "tostring", "tonumber", "assert", "unpack", "utf8", "collectgarbage", "type",
        "setmetatable", "getmetatable", "rawset", "rawget", "coroutine" -- extra stuff
    }

    for _, k in ipairs(funs) do env[k] = _G[k] end
    env._G = env

    env.setTimeout = setTimer
    env.clearTimeout = clearTimer

    function env.__fibaroSleep(ms)
    end

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
        if qa.debug.libraryfiles then
            QA.syslog(qa.tag,"Loading library " .. fn)
        end
        local stat, res = pcall(function() loadfile(fn, "t", env)() end)
        if not stat then
            QA.syslogerr(qa.tag,"%s - %s", fn, res)
            qa.env = nil
            return
        end
    end

    env.fibaro.debugFlags = debugFlags
    env.fibaro.config = config
    env.fibaro.createDevice = fakes.createDevice
    if debugFlags.dark or config.dark then util.fibColors['TEXT'] = util.fibColors['TEXT'] or 'white' end
    return env
end

local remotes = {} -- resources that we access on the HC3

local function addFlags(perms,flags)
    for typ,vals in pairs(perms) do
        flags[typ] = flags[typ] or {patterns={},ids={}}
        local ep = flags[typ]
        if ep == true then break end
        for _,v in ipairs(vals) do
            if v == '*' then flags[typ] = true break end
            if type(v)=='string' and v:sub(1,1)=="$" then
                ep.patterns[#ep.patterns+1] = v:sub(2)
            else
                ep.ids[v] = true
            end
        end
    end
end

local function checkRsrcFlag(typ,id, flags)
    local p = flags[typ]
    local r = resources.getResource(typ,id)
    if r and r._local then return true end
    if p == nil then return false end
    if p == true then return true end
    if #p.patterns > 0 then
        local id2 = tostring(id)
        for _,v in ipairs(p.patterns) do
            if id2:match(v) then return true end
        end
    end
    if flags[typ].ids[id] then return true end
end

QA.isLocal = function(typ,id) return not checkRsrcFlag(typ,id,remotes) end
QA.isRemote = function(typ,id) return checkRsrcFlag(typ,id,remotes) end

local function runner(fc, id)
    local qa = DIR[id]
    qa.f = fc
    local debugFlags = { color = true }

    addFlags(qa.remotes,remotes)

    if not createEnvironment(id) then return end
    local env = qa.env
    if not files.loadFiles(id) then return end

    local errfun = env.fibaro.error
    debugFlags = env.fibaro.debugFlags

    local function log(fmt, ...) util.debug(debugFlags, env.__TAG, format(fmt, ...), "SYS") end
    local function logerr(fmt, ...) env.fibaro.error(env.__TAG, format("Error : %s", format(fmt, ...))) end

    local function checkErr(str, f, ...)
        local ok, err = pcall(f, ...)
        if not ok then env.fibaro.error(env.__TAG, format("%s Error: %s", str, err)) end
    end

    collectgarbage("collect")
    for _, qf in pairs(qa.files) do
        log("Running '%s'", qf.name)
        local stat, err = pcall(qf.qa) -- Start QA
        if not stat then
            logerr("Running '%s' - %s - restarting in 5s", qf.name, err)
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

local function cresume(co,...)
    local output = {coroutine.resume(co,...)}
    if output[1] == false then
      return false, output[2], debug.traceback(co)
    end
    return table.unpack(output)
  end

local function createQArunner(runner, id)
    local c = coroutine.create(runner)
    local function t(task)
        local res, task = cresume(c, task)
        --print("X",task.type,task.log,coroutine.status(c))
        if task.type == 'timer' then
            timers.add(id, clock() + task.ms, t, task)
            cresume(c)
        end
    end
    local stat, res = cresume(c, t, id) -- Start QA
    if not stat then print(res) end
end

local function killQA(id)
    local qa = DIR[id]
    if qa then
        timers.removeId(id)
        if qa.env then qa.env.fibaro.__dead = true end
    end
end

------- QA functions called fibenv.py -------
-- Simple call arguments so no need to encode as json

function QA.runFile(fname)
    local env = {}
    for k,v in pairs(_G) do if v ~= _G then env[k] = v end end
    for _, l in ipairs({ "json.lua", "class.lua", "net.lua", "fibaro.lua"}) do
        local fn = luapath .. l
        local stat, res = pcall(function() loadfile(fn, "t", env)() end)
    end
    env.fibaro.debugFlags = debugFlags
    local stat, res = pcall(function() loadfile(fname, "t", env)() end)
    if not stat then QA.syslogerr("initfile","Error: %s", res) end
end

function QA.install(fname, id)
    local qa = files.installQA(fname, id)
    if qa then
        QA.restart(qa.dev.id)
    end
end

function QA.installFQA(data, roomId)
    local qa = files.installFQA(data, roomId)
    if qa then
        QA.restart(qa.dev.id)
    end
end

function QA.restart(id, delay)
    if DIR[id] then
        delay = delay or 0
        killQA(id)
        systemTimer(function() createQArunner(runner,id) end, delay, " restart:"..delay)
    end
end

function QA.delete(id)
    if DIR[id] then
        killQA(id)
        DIR[id] = nil
    end
    resources.removeDevice(id)
end

------------ Lua functions called from fibapi.py ------------
-- Called from another thread, so be careful.
-- Use json to encode complex data
-- Should not throw errors and should return status code

function QA.fun.debugMessages(arg)
    arg = json.decode(arg)
    util.debug({ color = true }, arg.messageType, arg.message, arg.tag)
    return "OK",200
end

------------ Events posted from fibenv.py ------------
-- Usually carries complex data, so we use json
local Events = {}

function Events.onAction(event)
    local id = event.deviceId
    local args = json.decode(event.args)
    if not DIR[id] then
        if QA.isRemote("devices", id) then
            api.post("/devices/" .. id .. "/action/"..event.actionName, {args=args}, "hc3")
        else
            if QA.isLocal("devices", id) then
                QA.syslogerr("onAction","No action, QA declared local, ID:%s", id)
            else
                QA.syslogerr("onAction","Unknown QA, ID:%s", id)
            end
        end
        return
    end
    timers.add(id, 0, DIR[id].f,
        { type = 'onAction', deviceId = id, actionName = event.actionName, args = args })
end

function Events.uiEvent(event)
    local id = event.deviceId
    if not DIR[id] then 
        QA.syslogerr("uiEvent","Unknown QA, ID:%s", id)
        return 
    end
    timers.add(id, clock(), DIR[id].f,
        {
            type = 'UIEvent',
            deviceId = id,
            elementName = event.elementName,
            eventType = event.eventType,
            values = event.values or {}
        })
end

function Events.updateView(event)
    print("UV", json.encode(event))
end

function Events.installQA(event)
    local file = event.file
    local stat,res = pcall(QA.install,file)
    if not stat then print(res) end
end

function Events.importFQA(event)
    local file = event.file
    file = json.decode(file)
    local qa = QA.installFQA(file, event.roomId)
    if qa then
        QA.restart(qa.dev.id)
    end
end

function Events.refreshStates(event)
    refreshStates.newEvent(event.event)
end

function Events.httpResponse(event,options)
    local status = event.status
    local data = event.data
    local headers = event.headers
    local callback = options.callback
    systemTimer(function()
        callback(status, data, headers)
    end,0,"httpResponse")
end

function QA.onEvent(event,us) -- dispatch to event handler
    event = json.decode(event)
    local h = Events[event.type]
    if h then h(event,us) else print("Unknown event", event.type) end
end

--[[
    Main emulator dispatcher
    Responsible executing (Lua) tasks added to the timers queue.
    Called repeatedly by the main loop in Python (fibenv.py).
    Looks at the next task in queue, if time is up calls the task,
    otherwise returns the time to wait for the next task.
    If queue is empty returns 0.5 seconds.
    Ex. setTimeout adds tasks to this queue.
    Incoming events from the "outside" like onUIevent and onAction may cause
    the dispatcher to be called earlier the the last wait time.
--]]
function QA.dispatcher()
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

QA.syslog("boot","QA emulator started")
