local scenes, loadScene, sceneRunner, compileCondition, dateTest = {}, nil, nil, nil, nil
local Events = {}
local DEBUG = true
local function printf(...) print(string.format(...)) end
local fibemu = fibaro.fibemu

local triggerFilter = {
    device = true,
    ['global-variable'] = true,
    ['se-startup'] = true,
    ['custom-event'] = true,
    alarm = true,
    climate = true,
    profile = true,
    weather = true,
    location = true,
}

function fibemu.loadScenes(s, ...)
    function fibemu.triggerHook(ev)
        local st = Events[ev.type] and Events[ev.type](ev, ev.data) or ev
        if ev == st then return end
        if not triggerFilter[st.type] then return end
        local timestamp = os.time()
        for _, scene in ipairs(scenes) do
            local event = { event = st, timestamp = timestamp, scene = scene }
            if scene.cond(event) then scene.run(event) end
        end
    end

    local sceneNames = type(s) == 'table' and s or { ... }
    for i, sn in ipairs(sceneNames) do
        scenes[#scenes + 1] = loadScene(sn, i)
    end
end

function loadScene(fname, id)
    local scene = {}
    local f = io.open(fname, "r")
    assert(f)
    scene.code = f:read("*all")
    f:close()
    local cond = scene.code:match("COND[%s%c]*=[%s%c]*(%b{})")
    cond = fibemu.loadstring("return " .. cond)()
    scene.cond = compileCondition(cond, scene)
    local env = { _sceneId = "SCENE" .. id, __TAG = "SCENE" .. id }
    local funs = {
        "os", "io", "pairs", "ipairs", "select", "math", "string", "pcall", "xpcall", "table", "error",
        "next", "json", "tostring", "tonumber", "assert", "unpack", "utf8", "collectgarbage", "type",
        "fibaro", "setTimeout", "clearTimeout", "setInterval", "clearInterval",
    }
    for _, f in ipairs(funs) do env[f] = _G[f] end
    for k, v in pairs(_G) do if k:sub(1, 2) == '__' then env[k] = v end end
    fibemu.loadfile(fibemu.path.."lua/json.lua", "t", env)
    fibemu.loadfile(fibemu.path.."lua/net.lua", "t", env)
    fibemu.loadfile(fibemu.path.."fibaro.lua", "t", env)
    function env.print(...) env.fibaro.debug(env._sceneId, ...) end

    scene.fun = fibemu.loadstring(scene.code, fname, "t", env)
    function scene.run(ev)
        env.sourceTrigger = ev.event
        scene.fun(ev)
    end

    return scene
end

Events = { -- There are more, but these are what I seen so far...
    AlarmPartitionArmedEvent = function(t) return t end,
    AlarmPartitionBreachedEvent = function(t) return t end,
    HomeArmStateChangedEvent = function(t) return t end,
    HomeDisarmStateChangedEvent = function(t) return t end,
    HomeBreachedEvent = function(t) return t end,
    WeatherChangedEvent = function(t) return t end,
    GlobalVariableChangedEvent = function(t, d)
        return { type = 'global-variable', name = d.variableName, value = d.newValue, oldValue = d.oldValue }
    end,
    GlobalVariableAddedEvent = function(t, d)
        return { type = 'global-variable', name = d.navariableNameme, value = d.newValue }
    end,
    CentralSceneEvent = function(t) return t end,
    SceneActivationEvent = function(t) return t end,
    AccessControlEvent = function(t) return t end,
    CustomEvent = function(t) return t end,
    DevicePropertyUpdatedEvent = function(t, d)
        return { type = 'device', id = d.deviceID, property = d.propertyName, value = d.value }
    end,
    OnlineStatusUpdatedEvent = function(t) return t end,
    ActiveProfileChangedEvent = function(t) return t end,
    ClimateZoneChangedEvent = function(t) return t end,
    ClimateZoneSetpointChangedEvent = function(t) return t end,
    GeofenceEvent = function(t) return t end,
}

local function map(f, l)
    local r = {}
    for i, v in ipairs(l) do r[i] = f(v) end
    return r
end

local function copy(t)
    local r = {}
    for k, v in pairs(t) do r[k] = v end
    return r
end

local cfs = {}
local ops = {}
ops['=='] = function(a, b) return tostring(a) == tostring(b) end
ops['anyValue'] = function(a, b) return true end
ops['!='] = function(a, b) return tostring(a) ~= tostring(b) end
ops['>'] = function(a, b) return tostring(a) > tostring(b) end
ops['<'] = function(a, b) return tostring(a) < tostring(b) end
ops['>='] = function(a, b) return tostring(a) >= tostring(b) end
ops['<='] = function(a, b) return tostring(a) <= tostring(b) end
ops['match=='] = function(a, b) return a == b end
ops['match!='] = function(a, b) return a ~= b end
ops['match>'] = function(a, b) return a > b end
ops['match<'] = function(a, b) return a < b end
ops['match>='] = function(a, b) return a >= b end
ops['match<='] = function(a, b) return a <= b end

local minuteTimers, minuteRef = {}, nil
local function addMinuteTimer(f)
    minuteTimers[#minuteTimers + 1] = f
    if minuteRef then return end
    local nxt = (os.time() // 60 + 1) * 60
    local function loop()
        nxt = nxt + 60
        for _, f in ipairs(minuteTimers) do f() end
        minuteRef = setTimeout(loop, 1000 * (nxt - os.time()))
    end
    minuteRef = setTimeout(loop, 1000 * (nxt - os.time()))
end

local function clearMinuteTimers()
    if minuteRef then clearTimeout(minuteRef) end
    minuteTimers, minuteRef = {}, nil
end

function cfs.device(c)
    local prop = c.property
    local op = ops[c.operator]
    local value = c.value
    local id = c.id
    local duration = c.duration
    local ref = nil
    local lastTrue = nil
    return function(ev)
        local res = op((__fibaro_get_device_property(id, prop) or {}).value, value)
        if res then lastTrue = lastTrue or os.time() else lastTrue = nil end
        -- If duration, we need to set a timer and trigger the scene... or just trigger the action?. TBD
        return res
    end
end

function cfs.date(c)
    local isTrigger = c.isTrigger
    local prop = c.property
    local op = c.operator
    local value = c.value
    if prop == 'sunset' or prop == 'sunrise' then
        assert(op == '==', "date sunset/sunrise operaor must be '=='")
        assert(tonumber(value), "date sunset/sunrise value must be a number")
        return function(ev)
            local v = fibaro.getValue(1, prop .. "Hour")
            local h = os.date("%H:%M", ev.timestamp + value * 60)
            return v == h
        end
    elseif prop == 'cron' then
        local function timePattern(value)
            local tp = {}
            if value[1] ~= '*' then tp.min = tonumber(value[1]) end
            if value[2] ~= '*' then tp.hour = tonumber(value[2]) end
            if value[3] ~= '*' then tp.day = tonumber(value[3]) end
            if value[4] ~= '*' then tp.month = tonumber(value[4]) end
            if value[5] ~= '*' then tp.wday = tonumber(value[5]) end
            if value[6] ~= '*' then tp.year = tonumber(value[6]) end
            return tp
        end
        if op == 'match' then
            local dateStr = table.concat(value, " ")
            local test = dateTest(dateStr)
            return function(ev)
                if isTrigger and ev.event.type ~= 'date' and ev.event.property ~= 'cron' and ev.event.operator ~= 'match' then return false end --???
                local t = test(ev.timestamp)
                if DEBUG then printf("MATCH: %s => %s", os.date("%c", ev.timestamp), t) end
                return t
            end
        elseif op == 'matchInterval' then
            local interval = tonumber(value.interval)
            local time = value.date
            assert(interval, "matchInterval: missing interval")
            assert(type(time) == 'table', "matchInterval: missing date")
            local tp = timePattern(time)
            return function(ev)
                local tn = os.date("*t", ev.timestamp)
                for k, v in pairs(tp) do tn[k] = v end
                local t = os.time(tn)
                if ev.scene.intervalStart then clearTimeout(ev.scene.intervalStart) end
                if ev.scene.intervalRef then clearInterval(ev.scene.intervalRef) end
                ev.scene.intervalStart = setTimeout(function()
                    ev.scene.intervalStart = nil
                    ev.scene.intervalRef = setInterval(function()
                        ev.scene.run(ev)
                    end, 1000 * interval)
                end, 1000 * (t - os.time()))
            end
        else
            local op2 = ops[op]
            assert(op2, "Unknown operator: " .. op)
            local tp = timePattern(value)
            return function(ev)
                local tn = os.date("*t", ev.timestamp)
                for k, v in pairs(tp) do tn[k] = v end
                --print("D1:", os.date("%c", ev.timestamp), "D2:", os.date("%c", os.time(tn)))
                return op2(ev.timestamp, os.time(tn))
            end
        end
    else
        error("Unknown date property: " .. prop)
    end
end

function cfs.weather(c)
    error("not implemented")
end

function cfs.location(c)
    error("not implemented")
end

cfs['custom-event'] = function(c)
    error("not implemented")
end
function cfs.alarm(c)
    error("not implemented")
end

function cfs.climate(c)
    error("not implemented")
end

cfs['se-startup'] = function(c)
    error("not implemented")
end
cfs['global-variable'] = function(c)
    local name = c.property
    local op = ops[c.operator]
    local value = c.value
    return function(ev) return ev.event.name == name and op((__fibaro_get_global_variable(name) or {}).value, value) end
end
function cfs.profile(c)
    error("not implemented")
end

function compileCondition(c, scene)
    local triggers = {}
    local function compile(c)
        if c.operator and c.conditions then
            local conds = map(compile, c.conditions)
            if c.operator == 'all' then
                return function(ev)
                    for _, c in ipairs(conds) do
                        if not c(ev) then return false end
                    end
                    return true
                end
            elseif c.operator == 'any' then
                return function(ev)
                    for _, c in ipairs(conds) do
                        if c(ev) then return true end
                    end
                    return false
                end
            else
                error("Unknown operator: " .. c.operator)
            end
        else
            if c.isTrigger then triggers[#triggers + 1] = c end
            assert(cfs[c.type], "Unknown condition type: " .. c.type)
            return cfs[c.type](c)
        end
    end
    local condFun = compile(c)
    local triggers2 = copy(triggers)
    for _, t in ipairs(triggers2) do
        if t.type == 'date' and t.property == 'cron' and t.operator == 'match' then
            local cron = compile(t)
            local t0 = t
            addMinuteTimer(function()
                local ev = { timestamp = os.time(), event = t0, scene = scene }
                if cron(ev) then
                    scene.run(ev)
                end
            end)
        end
    end
    local triggerFun = function(ev) return true end -- ToDo
    return function(ev)
        return triggerFun(ev) and condFun(ev)
    end
end

function dateTest(dateStr0)
    local days = { sun = 1, mon = 2, tue = 3, wed = 4, thu = 5, fri = 6, sat = 7 }
    local months = {
        jan = 1,
        feb = 2,
        mar = 3,
        apr = 4,
        may = 5,
        jun = 6,
        jul = 7,
        aug = 8,
        sep = 9,
        oct = 10,
        nov = 11,
        dec = 12
    }
    local last, month = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }, nil

    local function seq2map(seq)
        local s = {}
        for _, v in ipairs(seq) do s[v] = true end
        return s;
    end

    local function flatten(seq, res) -- flattens a table of tables
        res = res or {}
        if type(seq) == 'table' then for _, v1 in ipairs(seq) do flatten(v1, res) end else res[#res + 1] = seq end
        return res
    end

    local function _assert(test, msg, ...) if not test then error(format(msg, ...), 3) end end

    local function expandDate(w1, md)
        local function resolve(id)
            local res
            if id == 'last' then
                month = md
                res = last[md]
            elseif id == 'lastw' then
                month = md
                res = last[md] - 6
            else
                res = type(id) == 'number' and id or days[id] or months[id] or tonumber(id)
            end
            _assert(res, "Bad date specifier '%s'", id)
            return res
        end
        local step = 1
        local w, m = w1[1], w1[2]
        local start, stop = w:match("(%w+)%p(%w+)")
        if (start == nil) then return resolve(w) end
        start, stop = resolve(start), resolve(stop)
        local res, res2 = {}, {}
        if w:find("/") then
            if not w:find("-") then -- 10/2
                step = stop; stop = m.max
            else
                step = (w:match("/(%d+)"))
            end
        end
        step = tonumber(step)
        _assert(start >= m.min and start <= m.max and stop >= m.min and stop <= m.max, "illegal date intervall")
        while (start ~= stop) do -- 10-2
            res[#res + 1] = start
            start = start + 1; if start > m.max then start = m.min end
        end
        res[#res + 1] = stop
        if step > 1 then
            for i = 1, #res, step do res2[#res2 + 1] = res[i] end
            ; res = res2
        end
        return res
    end

    local function parseDateStr(dateStr)       --,last)
        --local map = table.map
        local seq = string.split(dateStr, " ") -- min,hour,day,month,wday
        local lim = { { min = 0, max = 59 }, { min = 0, max = 23 }, { min = 1, max = 31 }, { min = 1, max = 12 },
            { min = 1, max = 7 }, { min = 2000, max = 3000 } }
        for i = 1, 6 do if seq[i] == '*' or seq[i] == nil then seq[i] = tostring(lim[i].min) .. "-" .. lim[i].max end end
        seq = map(function(w) return string.split(w, ",") end, seq) -- split sequences "3,4"
        local month0 = os.date("*t", os.time()).month
        seq = map(function(t)
            local m = table.remove(lim, 1);
            return flatten(map(function(g) return expandDate({ g, m }, month0) end, t))
        end, seq) -- expand intervalls "3-5"
        return map(seq2map, seq)
    end
    local sun, offs, day, sunPatch = dateStr0:match("^(sun%a+) ([%+%-]?%d+)")
    if sun then
        sun = sun .. "Hour"
        dateStr0 = dateStr0:gsub("sun%a+ [%+%-]?%d+", "0 0")
        sunPatch = function(dateSeq)
            local h, m = (fibaro.getValue(1, sun)):match("(%d%d):(%d%d)")
            dateSeq[1] = { [(tonumber(h) * 60 + tonumber(m) + tonumber(offs)) % 60] = true }
            dateSeq[2] = { [math.floor((tonumber(h) * 60 + tonumber(m) + tonumber(offs)) / 60)] = true }
        end
    end
    local dateSeq = parseDateStr(dateStr0)
    return function(t0)                                                         -- Pretty efficient way of testing dates...
        local t = os.date("*t", t0 or os.time())
        if month and month ~= t.month then dateSeq = parseDateStr(dateStr0) end -- Recalculate 'last' every month
        if sunPatch and (month and month ~= t.month or day ~= t.day) then
            sunPatch(dateSeq)
            day = t.day
        end                         -- Recalculate sunset/sunrise
        return
            dateSeq[1][t.min] and   -- min     0-59
            dateSeq[2][t.hour] and  -- hour    0-23
            dateSeq[3][t.day] and   -- day     1-31
            dateSeq[4][t.month] and -- month   1-12
            dateSeq[5][t.wday] or
            false                   -- weekday 1-7, 1=sun, 7=sat
    end
end
