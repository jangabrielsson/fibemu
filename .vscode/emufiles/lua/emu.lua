local props = ...
local luapath = props.path.."lua/"
local util = dofile(luapath.."utils.lua")
dofile(luapath.."json.lua")
local resources = dofile(luapath.."resources.lua")
local refreshState = dofile(luapath.."refreshState.lua")
local timers = util.timerQueue()
local clock = util.clock

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
config.creds = util.basicAuthorization(config.user, config.password)

QA = {}
local tasks = {}
-- props = {stopOnLoad = <boolean>}

local function runner(task)
    local env,id = {},task.id
    local format,errfun = string.format,nil
    local function log(str, fmt, ...) env.fibaro.debug(env.__TAG, format("%s %s", str, format(fmt, ...))) end
    local function logerr(str, fmt, ...) env.fibaro.error(env.__TAG, format("%s Error: %s", str, format(fmt, ...))) end
    local function setTimer(f, ms, log)
        assert(type(f)=='function',"setTimeout first arg need to be function")
        assert(type(ms)=='number',"setTimeout second arg need to be a number")
        local t = clock() + ms / 1000
        return timers.add(id, t, tasks[id].f,{ type = 'timer', fun = f, ms = t, log = log or "" })
    end    
    local function setTimer2(f, ms, log)
        coroutine.yield({ type = 'timer', fun = f, ms = ms / 1000, log = log or "" })
        f()
    end
    local function clearTimer(ref) assert(type(ref)=='number',"clearTimeout ref need to be number") timers.remove(ref) end
    local function checkErr(str, f, ...)
        local ok, err = pcall(f, ...) if not ok then env.fibaro.error(env.__TAG, format("%s Error: %s", str, err)) end
     end

    local function main(id, fname)
        env.___id = id
        local funs = {
            "os", "pairs", "ipairs", "select", "print", "math", "string", "pcall", "xpcall", "table", "error",
            "next","json","tostring", "tonumber", "assert", "unpack", "utf8", "collectgarbage",
            "setmetatable", "getmetatable", "type", "rawset", "rawget",
            "__HTTP"
        }
        for _, k in ipairs(funs) do env[k] = _G[k] end
        env._G = env
        env.__config = config
        local debugFlags, fmt = {}, string.format
        debugFlags.color = true
        if config.dark then util.fibColors['TEXT']='white' end

        env.setTimeout = setTimer
        env.clearTimeout = clearTimer

        function env.__fibaroSleep(ms) end

        function env.__fibaro_get_global_variable(name) end

        function env.__fibaro_get_device(id) end

        function env.__fibaro_get_devices() end

        function env.__fibaro_get_room(id) end

        function env.__fibaro_get_scene(id) return nil end

        function env.__fibaro_get_device_property(id, prop) end

        function env.__fibaro_get_breached_partitions() end

        function env.__fibaro_add_debug_message(tag, str, typ)
            assert(str, "Missing tag for debug")
            util.debug(debugFlags, tag, str, typ)
        end

        for _, l in ipairs({ "json.lua", "class.lua", "fibaro.lua", "quickApp.lua" }) do
            print("loading "..luapath..l)
            local stat, res = pcall(function() loadfile(luapath..l, "t", env)() end)
            if not stat then
                logerr("Load", "%s - %s", fname, res)
                QA.delete(id)
                return
            end
        end
        errfun = env.fibaro.error
        env.fibaro.debugFlags = debugFlags
        if debugFlags.dark then util.fibColors['TEXT'] = util.fibColors['TEXT'] or 'white' end

        local qa, res = loadfile(fname, "t", env)     -- Load QA
        if not qa then
            logerr("Load", "%s - %s", fname, res)
            QA.delete(id)
            return
        end
        local function ff() lldebugger.call(qa, true) end
        collectgarbage("collect")
        log("Starting", "%s (%.2fkb)", fname, collectgarbage("count"))
        local stat, err = pcall(props.stopOnLoad and ff or qa)     -- Start QA
        if not stat then
            logerr("Start", "%s - %s - restarting in 5s", fname, err)
            QA.delete(id)
            setTimer2(function() QA.start(id, fname) end, 5000)
            return
        end

        local stat,err = pcall(function()
            local qo = env.QuickApp({id=id,name="TEST", type='com.fibaro.binarySwitch', properties={}, interfaces={}, parentId=0})
            env.quickApp = qo
        end)
        if not stat then
            logerr(":onInit()", "%s - restarting in 5s", err)
            QA.delete(id)
            setTimer2(function() QA.start(id, fname) end, 5000)
            return
        end
    end
    local ok,err
    while true do
        ::foo:: if task.type == 'timer' then ok, err = pcall(task.fun) if not ok then errfun(env.__TAG, format("%s Error: %s", "timer", err)) end task = coroutine.yield({ type = 'next' }) goto foo
        -- if task.type == 'timer' then
        --     checkErr("setTimeout", task.fun)
        elseif task.type == 'qa' then
            main(task.id, task.fname)
        elseif task.type == 'onAction' then
            checkErr("onAction", env.onAction, id, task)
        elseif task.type == 'UIEvent' then
            checkErr("UIEvent", env.onUIEvent, id, task)
        end
        task = coroutine.yield({ type = 'next', log="X" })
    end
end

local function createTask(id, f, fname)
    local c = coroutine.create(f)
    local function t(task)
        local res,task = coroutine.resume(c,task)
        --print("X",task.type,task.log,coroutine.status(c))
        if task.type == 'timer' then
            timers.add(id, clock() + task.ms, t, task)
            coroutine.resume(c)
        end
    end
    tasks[id] = { f = t, fname = fname }
    return t
end

function QA.start(id, fname)
    timers.add(id, 0, createTask(id, runner, fname), { type = 'qa', id = id, fname = fname })
end

function QA.restart(id)
    if tasks[id] then
        local fname = tasks[id].fname
        QA.delete(id)
        QA.start(id, fname)
    end
end

function QA.delete(id)
    if tasks[id] then
        timers.removeId(id)
        tasks[id] = nil
    end
end

function QA.UIEvent(event)
    event = json.decode(event)
    local id = event.deviceId
    if not tasks[id] then return end
    timers.add(id, clock(), tasks[id].f,
        { type = 'UIEvent', deviceId = id, elementName = event.elementName, values = event.values or {} })
end

function QA.onAction(event)
    event = json.decode(event)
    local id = event.deviceId
    if not tasks[id] then return end
    timers.add(id, 0, tasks[id].f,
        { type = 'onAction', deviceId = id, actionName = event.actionName, args = event.args })
end

-- setTimeout(function() QA.start(41, "test.lua") end, 2000)
-- setTimeout(function() QA.start(42, "test.lua") end, 3000)
-- setTimeout(function() QA.UIEvent({ deviceId = 42, elementName = 'test', values = {} }) end, 5000)
-- setTimeout(function() QA.onAction({ deviceId = 42, actionName = 'foo', args = { 34, 56 } }) end, 7000)

resources.refresh()
refreshState.start()

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
