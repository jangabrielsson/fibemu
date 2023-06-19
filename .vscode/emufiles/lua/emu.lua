local pconfig = ...
local luapath = pconfig.path .. "lua/"
local util = dofile(luapath .. "utils.lua")
dofile(luapath .. "json.lua")
dofile(luapath .. "net.lua")
local resources = dofile(luapath .. "resources.lua")
local refreshState = dofile(luapath .. "refreshState.lua")
local timers = util.timerQueue()
local clock = util.clock
local format = string.format

print(os.date("Lua loader started %c"))
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

local f = io.open("config.json", "r")
assert(f, "Can't open config.json")
local config = json.decode(f:read("*all"))
f:close()
for k, v in pairs(pconfig) do if config[k] == nil then config[k] = v end end
config.creds = util.basicAuthorization(config.user, config.password)

QA,DIR = { config=config },{}
local gID = 5000


resources.refresh()
refreshState.init(resources)
refreshState.start(config)

function QA.syslog(typ,fmt, ...) 
    util.debug({color=true},typ, format(fmt, ...),"SYS")
end

local function createQAstruct(fname, id)
    local env = {}
    local debugFlags, fmt = {}, string.format
    debugFlags.color = true

    local function log(str, fmt, ...) util.debug(debugFlags,env.__TAG, format("%s %s", str, format(fmt, ...)),"DEBUG") end
    local function logerr(str, fmt, ...) env.fibaro.error(env.__TAG, format("%s Error: %s", str, format(fmt, ...))) end

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
        "next", "json", "tostring", "tonumber", "assert", "unpack", "utf8", "collectgarbage",
        "setmetatable", "getmetatable", "type", "rawset", "rawget",  -- extra stuff
        "__HTTP"                                                     -- pythin api
    }
    for _, k in ipairs(funs) do env[k] = _G[k] end
    env._G = env

    env.setTimeout = setTimer
    env.clearTimeout = clearTimer

    function env.__fibaroSleep(ms) end

    function env.__fibaro_get_global_variable(name) return resources.getResource("globalVariables",name) end

    function env.__fibaro_get_device(id) return resources.getResource("devices",id) end

    function env.__fibaro_get_devices() return util.toarray(resources.getResource("devices") or {}) end

    function env.__fibaro_get_room(id) return resources.getResource("rooms",id) end

    function env.__fibaro_get_scene(id) return resources.getResource("scenes",id) end

    function env.__fibaro_get_device_property(id, prop)
        local d = resources.getResource("devices",id)
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

    local f = io.open(fname, "r")
    if not f then
        logerr("Load", "%s - %s", fname, "File not found")
        return
    end
    local code = f:read("*all")
    f:close()

    local name, ftype = fname:match("([%w_]+)%.([luafq]+)$")
    local dev = { name = name, id = id, type = 'com.fibaro.binarySwitch', properties = {}, interfaces={}, parentId = 0 }
    assert(ftype == "lua", "Unsupported file type - " .. tostring(ftype))

    local chandler = {}
    function chandler.name(var, val, dev) dev.name = val end
    function chandler.type(var, val, dev) dev.type = val end
    function chandler.id(var, val, dev) dev.idtype = tonumber(id) end

    code:gsub("%-%-%%%%([%w_]+)=(.-)[\n\r]", function(var, val)
        if chandler[var] then chandler[var](var, val, dev) 
        else logerr("Load", "%s - Unknown header variable '%s'", fname, var) end
    end)

    if dev.id == nil then dev.id = gID; gID = gID + 1 end
    id = dev.id

    env.plugin = { mainDeviceId=dev.id}
    env.__TAG = "QUICKAPP"..dev.id

    for _, l in ipairs({ "json.lua", "class.lua", "net.lua", "fibaro.lua", "quickApp.lua" }) do
        log("Load","loading " .. luapath .. l)
        local stat, res = pcall(function() loadfile(luapath .. l, "t", env)() end)
        if not stat then
            logerr("Load", "%s - %s", fname, res)
            QA.delete(id)
            return
        end
    end

    env.fibaro.debugFlags = debugFlags
    env.fibaro.config = config
    if debugFlags.dark or config.dark then util.fibColors['TEXT'] = util.fibColors['TEXT'] or 'white' end

    local qa, res = load(code, fname, "t", env)  -- Load QA
    if not qa then
        logerr("Load", "%s - %s", fname, res)
        return
    end

    local qaf = qa
    if config['break'] and lldebugger then qaf = function() lldebugger.call(qa, true) end end

    return { qa = qaf, env = env, dev = dev, logerr = logerr, log = log }
end

local function runner(fname, fc, id)
    local qastr = createQAstruct(fname, id)
    local qa, env, dev, log, logerr = qastr.qa, qastr.env, qastr.dev, qastr.log, qastr.logerr
    local errfun = env.fibaro.error
    local function checkErr(str, f, ...)
        local ok, err = pcall(f, ...)
        if not ok then env.fibaro.error(env.__TAG, format("%s Error: %s", str, err)) end
    end

    DIR[dev.id] = { f = fc, fname = fname, env = env, dev = dev}

    collectgarbage("collect")
    log("Starting", "%s (%.2fkb)", fname, collectgarbage("count"))
    local stat, err = pcall(qa) -- Start QA
    if not stat then
        logerr("Start", "%s - %s - restarting in 5s", fname, err)
        QA.delete(id)
        return 5000
    end

    local stat, err = pcall(function()
        local qo = env.QuickApp(dev)
        env.quickApp = qo
    end)
    if not stat then
        logerr(":onInit()", "%s - restarting in 5s", err)
        QA.delete(id)
        return 5000
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

local function createQA(runner, fname, id)
    local c = coroutine.create(runner)
    local function t(task)
        local res, task = coroutine.resume(c, task)
        --print("X",task.type,task.log,coroutine.status(c))
        if task.type == 'timer' then
            timers.add(id, clock() + task.ms, t, task)
            coroutine.resume(c)
        end
    end
    local stat,res = coroutine.resume(c, fname, t, id)
    if not stat then print(res) 
    elseif type(res) == 'number' then
        timers.add(id, clock() + res/1000, function() QA.start(fname,id) end, { type = 'next' }) 
    end
end

function QA.start(fname, id)
    createQA(runner, fname, id)
end

function QA.restart(id)
    if DIR[id] then
        local fname = DIR[id].fname
        QA.delete(id)
        QA.start(fname, id)
    end
end

function QA.delete(id)
    if DIR[id] then
        timers.removeId(id)
        DIR[id] = nil
    end
end

function QA.UIEvent(event)
    event = json.decode(event)
    local id = event.deviceId
    if not DIR[id] then return end
    timers.add(id, clock(), DIR[id].f,
        { type = 'UIEvent', deviceId = id, elementName = event.elementName, values = event.values or {} })
end

function QA.onAction(event)
    event = json.decode(event)
    local id = event.deviceId
    if not DIR[id] then return end
    timers.add(id, 0, DIR[id].f,
        { type = 'onAction', deviceId = id, actionName = event.actionName, args = event.args })
end

function QA.onEvent(event)
    event = json.decode(event)
    refreshState.newEvent(event)
end

function QA.createResource(typ, id, data) return resources.createResource(typ, data) end
function QA.getResource(typ, id) return resources.getResource(typ, id) end
function QA.deleteResource(typ, id) return resources.deleteResource(typ, id) end

function QA.loop()
    local t, c, task = timers.peek()
    local cl = clock()
    --if t then print("loop",task.type,t-cl) else print("loop") end
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
