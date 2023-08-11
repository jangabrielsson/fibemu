local pconfig, hooks, luapath = ...
local function doload(fname) return dofile(luapath .. fname) end

local RESTART_TIME = 5000 -- 5s wait before restarting QA
local EMU_GLOBAL = "FIBEMU"

doload("json.lua")
doload("net.lua")
doload("class.lua")

pconfig = json.decode(pconfig)

local util = doload("utils.lua")
local devices = doload("device.lua")
local resources = doload("resources.lua")
local refreshStates = doload("refreshState.lua")
local files = doload("file.lua")
local timesup = doload("time.lua")

local timers = util.timerQueue()
local format, copy = string.format, util.copy

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
local pyhooks = hooks
local clock = pyhooks.clock
local luaType = function(obj)
    local t = type(obj)
    return t == 'table' and obj.__USERDATA and 'userdata' or t
end

QA, DIR = { config = config, fun = {}, debug = {}, debugDoc = {}, FIBEMUVAR = EMU_GLOBAL }, {}
function QA.addDoc(flag, doc) QA.debugDoc[flag] = doc end

QA.DIR = DIR
local debugFlags = QA.debug
debugFlags.color = true
debugFlags.refresh = true
fibaro = { pyhooks = pyhooks, debugFlags = debugFlags, fibemu = QA, config = config }
QA.loadstring = load
QA.loadfile = loadfile
os.orgtime = os.time
os.orgdate = os.date
local orgtime, orgdate = os.time, os.date
local timeOffset = 0
function os.time(a) return a == nil and orgtime() + timeOffset or orgtime(a) end

function os.date(a, b) return b == nil and orgdate(a, os.time()) or orgdate(a, b) end

function os.setTime(str) -- str = "mm/dd/yyyy-hh:mm:ss"
    local function tn(s, v) return tonumber(s) or v end
    local d, hour, min, sec = str:match("(.-)%-?(%d+):(%d+):?(%d*)")
    local month, day, year = d:match("(%d*)/?(%d*)/?(%d*)")
    local t = os.date("*t")
    t.year, t.month, t.day = tn(year, t.year), tn(month, t.month), tn(day, t.day)
    t.hour, t.min, t.sec = tn(hour, t.hour), tn(min, t.min), tn(sec, 0)
    local t1 = os.time(t)
    local t2 = os.date("*t", t1)
    if t.isdst ~= t2.isdst then
        t.isdst = t2.isdst
        t1 = os.time(t)
    end
    timeOffset = t1 - os.orgtime()
end

QA.addDoc("color", "true, uses colors in debug console")
QA.addDoc("refresh", "true, logs refreshStates (system triggers)")
QA.addDoc("dark", "true, sets debug console text to a light color (vscode in darkmode)")
QA.addDoc("debugFlags", "true, logs debugFlags being set in header")
QA.addDoc("quickVars", "true, logs quickAppVaribles being defined in header")
QA.addDoc("hc3_http", "true, logs http calls to HC3 or emulator")
QA.addDoc("libraryfiles", "true, logs Lua library files loaded (ex. quickApp.lua)")
QA.addDoc("userfiles", "true, logs user's QA files loaded (--%%file directive)")
QA.addDoc("refresh_resource", "true, logs refresh of resource in internal DB")
QA.addDoc("autoui", "true, will add 2s autorefresh for QA UI web interface page")
QA.addDoc("callstack", "true, will log callstack at error")

local libs = {
    devices = devices,
    resources = resources,
    files = files,
    refreshStates = refreshStates,
    lldebugger = lldebugger,
    emu = QA,
    util = util,
    binser = doload("binser.lua"),
    ui = doload("ui.lua"),
}
QA.libs = libs

devices.init(config, luapath .. "devices.json", libs)
resources.init(config, libs)
refreshStates.init(config, libs)
files.init(config, libs)
util.init(config, libs)
local member, epcall = util.member, util.epcall

for k, v in pairs(config.colors or {}) do util.fibColors[k] = v end

if debugFlags.dark or config.dark then util.fibColors['TEXT'] = util.fibColors['DARKTEXT'] end
if not config.lcl then refreshStates.start() end

function QA.syslog(typ, fmt, ...)
    util.debug({ color = true }, typ, format(fmt, ...), "SYS")
end

------- Greeting -----------------------------
QA.syslog('boot', "Fibemu v%s", config.version)
if not config.nogreet then
    QA.syslog('boot', "Web UI : %s", config.webURL)
    QA.syslog('boot', "alt. Web UI : %s", config.webURL.."frontend")
    QA.syslog('boot', "API Doc: %s", config.apiDocURL)
    QA.syslog('boot', "API EP : %s", config.apiURL)
end
----------------------------------------------

function QA.syslogerr(typ, fmt, ...)
    util.debug({ color = true }, typ, format(fmt, ...), "SYSERR")
end

local function systemTimer(fun, ms, msg)
    local t = clock() + ms / 1000
    return timers.add(-1, t, fun, { type = 'timer', fun = fun, ms = t, log = "system" .. (msg and msg or "") })
end
QA.systemTimer = systemTimer

function string.split(str, sep)
    local fields, s = {}, sep or "%s"
    str:gsub("([^" .. s .. "]+)", function(c) fields[#fields + 1] = c end)
    return fields
end

local stackSkips = { "breakForError", "luaError", "error", "assert" }

local function createEnvironment(id)
    local qa = DIR[id]
    local env, dev = {}, qa.dev
    local debugFlags, fmt = qa.debug, string.format
    if debugFlags.color == nil then debugFlags.color = true end
    qa.env = env

    function qa.addTask(ms, task, nosleep) -- absolute time
        return timers.add(id, clock() + ms / 1000, DIR[id].f, task, nosleep)
    end

    function qa.addTimer(ms, f, log, nosleep) -- relative time
        local t = clock() + ms / 1000
        return timers.add(id, t, DIR[id].f, { type = 'timer', fun = f, ms = t, log = log or "" }, nosleep)
    end

    local function setTimer(f, ms, log)
        local ctx = debug.getinfo(2)
        local function f2() epcall(env.fibaro, env.__TAG, "setTimeout", true, ctx, f) end
        return qa.addTimer(ms, f2, log)
    end
    local function clearTimer(ref)
        assert(type(ref) == 'number', "clearTimeout arg must be number")
        timers.remove(ref)
    end

    os.debug = debug
    os.dofile,os.loadfile = dofile,loadfile

    local funs = {
        "os", "io", "pairs", "ipairs", "select", "print", "math", "string", "pcall", "xpcall", "table", "error",
        "next", "json", "tostring", "tonumber", "assert", "unpack", "utf8", "collectgarbage", "type",
        "setmetatable", "getmetatable", "rawset", "rawget", "coroutine" -- extra stuff
    }

    for _, k in ipairs(funs) do env[k] = _G[k] end
    env._G = env
    env._ENV = env
    env.type = luaType

    env.__setTimeout = setTimer
    env.__clearTimeout = clearTimer

    function env.__fibaroSleep(ms)                       -- Need to make sure that onAction/onUIEvent are not run...
        local co = coroutine.running()
        if not coroutine.isyieldable(co) then return end -- Think again. Cause issue from tool download due ti api.get's sleep(0)
        local function f() coroutine.resume(co) end
        timers.save(id)
        DIR[id].addTimer(ms, f, "sleep", true)
        coroutine.yield({ type = 'next' })
        timers.restore(id)
    end

    -- Optimizations. Instead of calling the API, we call the local function
    function env.__fibaro_get_global_variable(name) return resources.getResource("globalVariables", name) end

    function env.__fibaro_set_global_variable(name, value) return resources.modifyResource("globalVariables", name,
            { name = name, value = value }) end

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
    env.fibaro = {}
    env.fibaro.fibemu = QA
    env.fibaro.debugFlags = debugFlags
    env.fibaro._emulator = "fibemu"
    env.fibaro._IPADDRESS = config.whost
    env.fibaro.config = config
    env.fibaro.pyhooks = pyhooks
    if debugFlags.dark or config.dark then util.fibColors['TEXT'] = util.fibColors['DARKTEXT'] end

    for _, l in ipairs({ "json.lua", "class.lua", "fibaro.lua", "net.lua", "quickApp.lua", "fibemu.lua", "scene.lua" }) do
        local fn = luapath .. l
        if qa.debug.libraryfiles then
            QA.syslog(qa.tag, "Loading library " .. fn)
        end
        local stat, res = pcall(function() return loadfile(fn, "t", env)() end)
        if not stat then
            QA.syslogerr(qa.tag, "%s - %s", fn, res)
            qa.env = nil
            return
        end
    end
    env.net._setupPatches(config)
    env.net._debugFlags = debugFlags
    print("NET",env.net)
    return env
end

local remotes = {} -- resources that we access on the HC3

local function addFlags(perms, flags)
    for typ, vals in pairs(perms) do
        flags[typ] = flags[typ] or { patterns = {}, ids = {} }
        local ep = flags[typ]
        if ep == true then break end
        for _, v in ipairs(vals) do
            if v == '*' then
                flags[typ] = true
                break
            end
            if type(v) == 'string' and v:sub(1, 1) == "$" then
                ep.patterns[#ep.patterns + 1] = v:sub(2)
            else
                ep.ids[v] = true
            end
        end
    end
end

local function checkRsrcFlag(typ, id, flags)
    local p = flags[typ]
    local r = resources.getResource(typ, id)
    if r and r._local then return true end
    if p == nil then return false end
    if p == true then return true end
    if #p.patterns > 0 then
        local id2 = tostring(id)
        for _, v in ipairs(p.patterns) do
            if id2:match(v) then return true end
        end
    end
    if flags[typ].ids[id] then return true end
end

QA.isLocal = function(typ, id) return not checkRsrcFlag(typ, id, remotes) end
QA.isRemote = function(typ, id) return checkRsrcFlag(typ, id, remotes) end

local function runner(fc, id)
    local qa = DIR[id]
    qa.f = fc
    local debugFlags = { color = true }

    addFlags(qa.remotes, remotes)

    if not createEnvironment(id) then return end
    local env = qa.env
    if not files.loadFiles(id) then return end

    local errfun = env.fibaro.error
    debugFlags = env.fibaro.debugFlags

    local function log(fmt, ...) util.debug(debugFlags, env.__TAG, format(fmt, ...), "SYS") end

    local function checkErr(str, f, ...)
        local ok, err = pcall(f, ...)
        if not ok then env.fibaro.error(env.__TAG, format("%s Error: %s", str, err)) end
    end

    collectgarbage("collect")
    for _, qf in pairs(qa.files) do
        log("Running '%s'", qf.name)
        local stat, err = epcall(env.fibaro, env.__TAG, qf.name .. " ", true, nil, qf.qa) -- run QA file
        if not stat then
            if type(err) == 'userdata' then
                if lldebugger then lldebugger.stop() end
                QA.isDead = true
                return
            end
            env.fibaro.error(env.__TAG, format("will restart in %ds", RESTART_TIME / 1000))
            QA.restart(id, RESTART_TIME)
        end
    end

    local stat, _ = epcall(env.fibaro, env.__TAG, ":onInit() ", true, nil, function()
        local qo = env.QuickApp(qa.dev)
        env.quickApp = qo
    end)
    if not stat then
        QA.restart(id, RESTART_TIME)
        env.fibaro.error(env.__TAG, format("will restart in %ds", RESTART_TIME / 1000))
    end

    local ok, err
    while true do -- QA coroutine loop
        local task = coroutine.yield({ type = 'next', log = "X" })
        ::foo::
        if task.type == 'timer' then
            ok, err = pcall(task.fun)
            if not ok then errfun(env.__TAG, format("%s Error: %s", "timer", err)) end
            task = coroutine.yield({ type = 'next' })
            goto foo
            -- if task.type == 'timer' then
            --     checkErr("setTimeout", task.fun)
        elseif task.type == 'onAction' then
            checkErr("onAction", env.onAction, id, task)
        elseif task.type == 'UIEvent' then
            -- ToDo, update UI here
            checkErr("UIEvent", env.onUIEvent, id, task)
        end
    end
end

local function cresume(co, ...)
    local output = { coroutine.resume(co, ...) }
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
    DIR[1] = { dev = { id = 1 }, debug = { color = true } }
    createEnvironment(1)
    local env = DIR[1].env
    local stat, res = pcall(function() loadfile(fname, "t", env)() end)
    if (not stat) and type(res) ~= "userdata" then
        QA.syslogerr("initfile", "Error: %s", res)
    else
        QA.isDead = true
    end
end

function QA.install(fname, conf)
    local qa = files.installQA(fname, conf)
    if qa then
        QA.restart(qa.dev.id)
    end
    return qa.dev
end

function QA.installFQA(data, roomId)
    local qa = files.installFQA(data, roomId)
    if qa then
        QA.restart(qa.dev.id)
        return qa
    end
end

function QA.restart(id, delay)
    if DIR[id] and not DIR[id].child then
        delay = delay or 0
        killQA(id)
        systemTimer(function() createQArunner(runner, id) end, delay, " restart:" .. delay)
    end
end

function QA.delete(id)
    if DIR[id] then
        killQA(id)
        DIR[id] = nil
        resources.removeDevice(id)
        for cid, cqa in pairs(DIR) do
            if cqa.dev.parentId == id then
                QA.delete(cid)
            end
        end
    end
end

------------ Lua functions called from fibapi.py ------------
-- Called from another thread, so be careful.
-- Use json to encode complex data
-- Should not throw errors and should return status code

function QA.fun.debugMessages(arg)
    arg = json.decode(arg)
    util.debug({ color = true }, arg.tag, arg.message, arg.messageType)
    return "OK", 200
end

function QA.fun.restartDevice(id)
    if not DIR[id] or DIR[id].child then return nil, 404 end
    QA.restart(id)
    return "OK", 200
end

function QA.fun.createChildDevice(args)
    args = json.decode(args)
    if not tonumber(args.parentId) then return {}, 400 end
    local qa = files.createChildDevice(args.parentId, args)
    return qa.dev, 200
end

function QA.fun.deleteChildDevice(id)
    local qa = DIR[id]
    if qa and not qa.child then return nil, 501 end
    QA.delete(id)
    return qa.dev, 200
end

function QA.fun.publishEvent(args)
    args = json.decode(args)
    local type = args.type
    local id = args.source
    local ev = {
        type = "CentralSceneEvent",
        data = {
            id = id,
            keyId = args.data.keyId,
            keyAttribute = args.data.keyAttribute
        }
    }
    refreshStates.newEvent(ev)
    return true, 200
end

function QA.fun.exportFQA(args)
    args = json.decode(args)
    return true, 200
end

function QA.fun.importFQA(args)
    args = json.decode(args)
    local stat, res = pcall(QA.installFQA, args, args.roomId)
    if stat then
        return res.dev, 200
    else
        return nil, 404
    end
end

function QA.fun.exportFQA(id)
    if not DIR[id] then return nil, 404 end
    local fqa = files.createFQA(id)
    return fqa, 200
end

------------ Events posted from fibenv.py ------------
-- Usually carries complex data, so event.args is json encoded
local Events = {}

function Events.onAction(event)
    local id = event.deviceId
    local target_id, arg_id = id, id
    local args = json.decode(event.args)
    if DIR[target_id] and DIR[target_id].child then -- children sends events to parent
        arg_id = target_id
        target_id = DIR[arg_id].dev.parentId
    end
    if not DIR[id] then        if QA.isRemote("devices", id) then -- If remote, forward, call HC3
            api.post("/devices/" .. id .. "/action/" .. event.actionName, { args = args }, "hc3")
        else
            if QA.isLocal("devices", target_id) then
                QA.syslogerr("onAction", "No action, QA declared local, ID:%s", target_id)
            else
                QA.syslogerr("onAction", "Unknown QA, ID:%s", id)
            end
        end
        return
    end
    if DIR[target_id].addTask then
        DIR[target_id].addTask(0, {
            type = 'onAction', deviceId = arg_id, actionName = event.actionName, args = args
        })
    end
end

function Events.uiEvent(event)
    local id = event.deviceId
    if not DIR[id] then -- ToDo, should forward to remote devices
        QA.syslogerr("uiEvent", "Unknown QA, ID:%s", id)
        return
    end
    if event.eventType == "onChanged" then
        -- If slider change value, update our own ui struct for Web UI usage
        Events.updateView({
            deviceId = id,
            componentName = event.elementName,
            propertyName = "value",
            newValue = tostring(event.values[1])
        })
    end
    local target_id = id
    if DIR[id].child then -- children sends events to parent
        target_id = DIR[id].dev.parentId
    end
    DIR[target_id].addTask(0,
        {
            type = 'UIEvent',
            deviceId = id,
            elementName = event.elementName,
            eventType = event.eventType,
            values = event.values or {}
        })
end

function Events.updateView(ev) -- Used to update our own ui struct for Web UI usage
    local qa = DIR[ev.deviceId]
    if qa then
        local map = qa.uiMap
        if map[ev.componentName] then
            map[ev.componentName][ev.propertyName] = ev.newValue
        else
            QA.syslogerr("updateView", "Unknown componentName, QA ID:%s - %s",
                ev.deviceId, tostring(ev.componentName))
        end
    else
        QA.syslogerr("updateView", "Unknown QA, ID:%s", ev.deviceId) -- ToDo, Should forward to remote devices
    end
end

function Events.installQA(event)
    local file = event.file
    local stat, res = pcall(QA.install, file)
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

function Events.luaCallback(event, options)
    local args = event.args
    local callback = options.callback
    local id = options.id
    if DIR[id] then
        DIR[id].addTimer(0, function() callback(table.unpack(args)) end, 0, "luaCallback")
    end
end

function QA.onEvent(event, luaData) -- dispatch to event handler
    event = json.decode(event)
    local h = Events[event.type]
    if h then h(event, luaData) else print("Unknown event", event.type) end
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
    the dispatcher to be called earlier then the last wait time.
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

if not config.nogreet then
    QA.syslog("boot", "QA emulator started")
end
if (not config.lcl) and config.fibemuvar then refreshStates.hc3HookVar() end
