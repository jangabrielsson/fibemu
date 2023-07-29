local sceneNames = {
    "examples/Scene_test.lua",
}

local scenes, loadScene, sceneRunner, compileCondition = {}, nil, nil, nil
local fibemu = fibaro.fibemu
__TAG = "SceneRunner"

function fibemu.triggerHook(ev)
     for _,scene in ipairs(scenes) do
        if scene.cond(ev) then scene.run(ev) end
    end
end

function loadScene(fname,id)
    local scene = {}
    local f = io.open(fname, "r")
    assert(f)
    scene.code = f:read("*all")
    f:close()
    local cond = scene.code:match("COND[%s%c]*=[%s%c]*(%b{})")
    cond = fibemu.loadstring("return " .. cond)()
    scene.cond = compileCondition(cond)
    local env = { _sceneId = "SCENE"..id, __TAG = "SCENE"..id}
    local funs = {
        "os", "io","pairs", "ipairs", "select", "math", "string", "pcall", "xpcall", "table", "error",
        "next", "json", "tostring", "tonumber", "assert", "unpack", "utf8", "collectgarbage", "type",
        "fibaro","setTimeout","clearTimeout","setInterval","clearInterval",
    }
    for _,f in ipairs(funs) do env[f] = _G[f] end
    for k,v in pairs(_G) do if k:sub(1,2) == '__' then env[k] = v end end
    fibemu.loadfile(".vscode/emufiles/lua/json.lua","t",env)
    fibemu.loadfile(".vscode/emufiles/lua/net.lua","t",env)
    fibemu.loadfile(".vscode/emufiles/lua/fibaro.lua","t",env)
    function env.print(...) env.fibaro.debug(env._sceneId,...) end
    scene.fun = fibemu.loadstring(scene.code,fname,"t",env)
    function scene.run(ev)
        scene.fun()
    end
    return scene
end

local function map(f,l) local r = {} for i,v in ipairs(l) do r[i] = f(v) end return r end

local cfs = {}
local ops = {}
ops['=='] = function(a,b) return tostring(a) == tostring(b) end
ops['!='] = function(a,b) return tostring(a) ~= tostring(b) end
ops['>'] = function(a,b) return tostring(a) > tostring(b) end
ops['<'] = function(a,b) return tostring(a) < tostring(b) end
ops['>='] = function(a,b) return tostring(a) >= tostring(b) end
ops['<='] = function(a,b) return tostring(a) <= tostring(b) end

function cfs.device(c)
    local prop = c.property
    local op = ops[c.operator]
    local value = c.value
    local id = c.id
    return function(ev) return op(__fibaro_get_device_property(c.id,prop),value) end
end
function cfs.date(c)
    local prop = c.property
    local value = c.value
    if prop == 'sunset' or prop == 'sunrise' then
        assert(c.operator == '==',"date sunset/sunrise operaor must be '=='")
        assert(tonumber(value),"date sunset/sunrise value must be a number")
        return function(ev)
            local v = fibaro.getValue(1,prop.."Hour")
            local h = os.date("%H:%M",os.time()+value*60)
            return v == h
        end
    elseif prop == 'cron' then
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
    return function(ev) return op(__fibaro_get_global_variable(name),value) end
end
function cfs.profile(c)
    error("not implemented")
end

function compileCondition(c)
    local triggers = {}
    local function compile(c)
        if c.operator and c.conditions then
            local conds = map(compile,c.conditions)
            if c.operator == 'all' then
                return function(ev)
                    for _,c in ipairs(conds) do
                        if not c(ev) then return false end
                    end
                    return true
                end
            elseif c.operator == 'any' then
                return function(ev)
                    for _,c in ipairs(conds) do
                        if c(ev) then return true end
                    end
                    return false
                end               
            else
                error("Unknown operator: " .. c.operator)
            end
        else
            if c.isTrigger then triggers[#triggers+1] = c end
            assert(cfs[c.type],"Unknown condition type: " .. c.type)
            return cfs[c.type](c)
        end
    end
    local f = compile(c)
    return function(ev)
        return true
    end
end

for i, sn in ipairs(sceneNames) do
    scenes[#scenes + 1] = loadScene(sn,i)
end

fibaro.setGlobalVariable("A",os.date("%c"))
