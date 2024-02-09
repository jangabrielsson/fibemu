local config, resources, devices, lldebugger = nil, nil, nil, nil
local libs, exports, emu, ui = nil, nil, nil, nil
local copy, merge, append
local QA, DIR
local customUI = {}

local function base64encode(data)
    local bC = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') end
        return r;
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
        return bC:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

local function getSize(b)
    local buf = {}
    for i = 1, 8 do buf[i] = b:byte(16 + i) end
    local width = (buf[1] << 24) + (buf[2] << 16) + (buf[3] << 8) + (buf[4] << 0)
    local height = (buf[5] << 24) + (buf[6] << 16) + (buf[7] << 8) + (buf[8] << 0);
    return width, height
end

local function init(conf, libs2)
    libs = libs2
    ui = libs.ui
    config = conf
    resources = libs.resources
    devices = libs.devices
    lldebugger = libs.lldebugger
    emu = libs.emu
    QA, DIR = emu, emu.DIR
    copy, merge, append = libs.util.copy, libs.util.merge, libs.util.append
    for name, fun in pairs(exports) do QA.fun[name] = fun end -- export file functions
end

local function addStockUI(dev, ui)
    local cui = customUI[dev.type or dev.baseType or ""]
    if cui then -- Insert stock UI at top.
        ui = ui or {}
        if #ui > 0 then
            table.insert(ui, 1, { label = '__divider', text = '-------------------------------' }) -- 31
        end
        for i = #cui, 1, -1 do table.insert(ui, 1, cui[i]) end
    end
    return ui
end

local function annotateUI(UI)
    local res, map = {}, {}
    for _, e in ipairs(UI) do
        if e[1] == nil then e = { e } end
        for _, e2 in ipairs(e) do
            e2.type = e2.button and 'button' or e2.slider and 'slider' or e2.label and 'label' or e2.select and 'select' or e2.switch and 'switch'
            map[e2[e2.type]] = e2
        end
        res[#res + 1] = e
    end
    return res, map
end

local function installFQA(fqa, conf)
    conf = conf or {}
    QA.syslog("install", "FQA '%s'", fqa.name)
    local dev = devices.getDeviceStruct(fqa.type)
    if dev == nil then
        QA.syslogerr("install", "%s - Unknown device type '%s'", fqa.name, fqa.type)
        return
    end
    dev = copy(dev)
    dev.name = fqa.name
    dev.type = fqa.type
    dev.id = resources.nextRsrcId()
    for k, v in pairs(fqa.initialProperties or {}) do
        dev.properties[k] = v
    end
    dev.interfaces = merge(dev.interfaces, fqa.initialInterfaces or {})
    dev.parentId = 0
    local tag = "QUICKAPP" .. dev.id
    local uiStruct, uiMap = ui.view2UI(dev.properties.viewLayout, dev.properties.uiCallbacks), nil
    --- ToDo - add stock UI...
    uiStruct, uiMap = annotateUI(uiStruct)

    DIR[dev.id] = {
        fname = "",
        dev = dev,
        files = fqa.files,
        name = dev.name,
        tag = tag,
        debug = {},
        UI = uiStruct or {},
        uiMap = uiMap or {},
        remotes = {},
        allRemote = false,
    }
    resources.createDevice(dev)
    return DIR[dev.id]
end

local FDIR = ""
local function installQA(fname, conf)
    local dispName,id=fname,nil
    conf = conf or {}
    if QA.config.hc3fspath and QA.config.hc3fspath~="" then
        local prefix = fname:match("^([%.%/\\]+)")
        if prefix and #prefix > 7 then
            FDIR = QA.config.hc3fspath
            dispName = fname:gsub(prefix,"")
            fname = FDIR.."/"..dispName
            dispName = "hc3fs:/"..dispName
        else QA.config.hc3fs = "" end
    else
    end
    if not conf.silent then QA.syslog("install", "QA '%s'", dispName) end
    local f = io.open(fname, "r")
    if not f then
        QA.syslogerr("install", "File not found - %s", fname)
        return
    end
    local code = f:read("*all")
    f:close()

    local name, ftype = fname:match("([%w%-%(%)%[%]_]+)%.([luafq]+)$")
    if ftype ~= "lua" then
        QA.syslogerr("install", " Unsupported file type - %s (strange characters in name?)", tostring(fname))
        return
    end

    local function resolveRoot(name)
        if name == "<automatic>" then
            local nname = fname:match("^(.-)[%w_ ‰.]+$")
            if nname then return nname end
        end
        return name
    end

    local eRoot = ""
    code:gsub("(%-%-%%%%root=.-)[\n\r]",function(str)
        eRoot = str:match("root=(.+)")
        eRoot = resolveRoot(eRoot)
    end)
    local parseCode = code:gsub("(%-%-%%%%include=.-)[\n\r]", function(str)
        local fname2 = eRoot..str:match("include=(.+)")
        local f2 = io.open(fname2, "r")
        if not f2 then QA.syslogerr("install", "Include file not found - %s", fname2) return "" end
        local icode = f2:read("*all")
        f2:close()
        return icode
    end)

    local function eval(str)
        local stat, res = pcall(function() return load("return " .. str, nil, "t", { config = config })() end)
        if stat then return res, true else return nil, false end
    end

    local fileoffset = ""
    local chandler = {}
    function chandler.root(var, val, vars) val=resolveRoot(val) fileoffset = val eRoot=val end
    function chandler.root2(var, val, vars) val=resolveRoot(val) fileoffset = val eRoot=val end

    function chandler.u(var, val, vars)
        vars.ui = vars.ui or {}
        local value, stat = eval(val)
        if stat == false then
            QA.syslogerr("install", "Bad UI expr '%s'", val)
        else
            vars.ui[#vars.ui + 1] = value
        end
    end

    for i = 1, 20 do
        local u = "u" .. i
        chandler[u] = chandler.u
    end
    function chandler.name(var, val, vars) vars.name = val:match('"(.-)"') or val end

    function chandler.type(var, val, vars) vars.type = val:match('"(.-)"') or val end

    function chandler.storage(var, val, vars) vars.storage = val:match('"(.-)"') or val end

    function chandler.allRemote(var, val, vars) vars.allRemote = eval(val) == true end

    function chandler.id(var, val, vars) vars.id = tonumber(val) end

    function chandler.zombie(var, val, vars) vars.zombie = tonumber(val) end

    function chandler.proxy(var, val, vars) vars.proxy = tonumber(val) end

    function chandler.noStock(var, val, vars) vars.noStock = eval(val) end
    function chandler.fullLua(var, val, vars) vars.fullLua = eval(val) end

    function chandler.debug(var, val, vars) --%%debug=flag1:val1,flag2:val2
        local dbs = {}
        vars.debug._init = true
        val:gsub("([^,]+)", function(d) dbs[#dbs + 1] = d end)
        for _, d in ipairs(dbs) do
            local var, val, stat = d:match("([%w_]+):(.+)")
            val, stat = eval(val)
            if stat == false or not var then
                QA.syslogerr("install", "Bad debug expr '%s'", d)
            else
                vars.debug[var] = val
                if emu.debug.debugFlags then
                    QA.syslog("install", "Debugflag %s=%s", var, val)
                end
            end
        end
    end

    function chandler.var(var, val2, vars) --%%var=varname:varvalue
        local l = fibaro
        local var, val, stat = val2:match("([%w_]+):(.+)")
        val, stat = eval(val)
        if stat == false or not var then
            QA.syslogerr("install", "Bad quickvar expr '%s'", val2)
        else
            vars.qvars[var] = val
            if emu.debug.quickVars then
                QA.syslog("install", "QuickVar %s=%s", var, val)
            end
        end
    end

    function chandler.merge(var, val, vars) --%%merge=fname1,fname2,...,oufile;
        val = val:match("(.*);") or val
        local files = val:split(",")
        if #files < 2 then
            QA.syslogerr("install", "Bad merge expr '%s'", val)
            return
        end
        local code = {}
        for i=1,#files-1 do
            local f = io.open(files[i], "r")
            if not f then
                QA.syslogerr("install", "(merge) File not found - %s", files[i])
                return
            end
            code[#code+1] = string.format("------- %s ----------", files[i])
            code[#code+1] = f:read("*all")
            f:close()
        end
        local f = io.open(files[#files], "w")
        if not f then
            QA.syslogerr("install", "(merge) Can't create file - %s", files[#files])
            return
        end
        f:write(table.concat(code, "\n"))
    end

    function chandler.interface(var, val, vars) --%%interface=x,y,z
        for _, ifc in ipairs(val:split(",")) do
            vars.interfaces[ifc] = true
        end
    end

    function chandler.image(var, val, vars) --%%image=fname,name
        local fname, name = val:match("(.-),(.*)")
        vars.images = vars.images or {}
        vars.images[#vars.images + 1] = { name = name, fname = fname }
    end

    function chandler.file(var, val, vars) --%%file=path,name;
        local fn, qn = table.unpack(val:sub(1, -2):split(","))
        vars.files[#vars.files + 1] = { fname = FDIR..fileoffset .. fn, name = qn, isMain = false, content = nil }
    end

    function chandler.remote(var, val, vars)
        local typ, list = val:match("([%w_/]-):(.+)")
        local items = {}
        list:gsub("([^,]+)", function(item) items[#items + 1] = tonumber(item) or item end)
        vars.remote[typ] = vars.remote[typ] or {}
        vars.remote[typ] = append(vars.remote[typ], items)
    end

    local vars = { files = {}, writes = {}, remote = {}, debug = {}, qvars = {}, interfaces = {} }
    parseCode:gsub("%-%-%%%%([%w_]+)=(.-)[\n\r]", function(var, val)
        if chandler[var] then
            chandler[var](var, val, vars)
        else
            QA.syslogerr("install", "%s - Unknown header variable '%s'", fname, var)
        end
    end)
    parseCode:gsub("%-%-FILE:(.-)[\n\r]", function(val) --backward compatible
        chandler.file('file', val, vars)
    end)
    table.insert(vars.files, { name = 'main', isMain = true, content = code, fname = fname })

    local definedId = vars.id
    vars.id = conf.id or vars.id
    if vars.id == nil then vars.id = resources.nextRsrcId() end
    id = vars.id

    if DIR[id] then
        QA.syslogerr("install", "ID:%s already installed (%s)", id, fname)
        return
    end

    vars.type = conf.type or vars.type
    local dev = devices.getDeviceStruct(vars.type or "com.fibaro.binarySwitch")
    if dev == nil then
        QA.syslogerr("install", "%s - Unknown device type '%s'", fname, vars.type)
        dev = devices.getDeviceStruct("com.fibaro.binarySwitch")
    end
    dev = copy(dev)
    dev.name = conf.name or vars.name or name
    dev.id = vars.id
    for n,v in pairs(conf.qvars or {}) do vars.qvars[n]=v end
    local qvars = {}
    for k, v in pairs(vars.qvars or {}) do qvars[#qvars + 1] = { name = k, value = v } end
    dev.properties.quickAppVariables = qvars
    vars.interfaces['quickApp'] = true
    for _,i in ipairs(conf.interfaces or {}) do vars.interfaces[i] = true end
    local ifs = {}
    for i, _ in pairs(vars.interfaces) do ifs[#ifs + 1] = i end
    dev.interfaces = ifs
    dev.parentId = 0
    local tag = "QUICKAPP" .. dev.id

    local uiStruct, uiMap = nil, nil

    if not vars.noStock then vars.ui = addStockUI(dev, vars.ui) end

    if vars.ui then
        ui.transformUI(vars.ui)
        dev.properties.viewLayout = ui.mkViewLayout(vars.ui, nil, dev.id)
        dev.properties.uiCallbacks = ui.uiStruct2uiCallbacks(vars.ui)
        uiStruct = ui.view2UI(dev.properties.viewLayout, dev.properties.uiCallbacks)
        uiStruct, uiMap = annotateUI(uiStruct)
    end

    DIR[id] = {
        fullLua = vars.fullLua == true,
        fname = fname,
        dev = dev,
        files = vars.files,
        name = dev.name,
        zombie = vars.zombie,
        tag = tag,
        debug = vars.debug,
        remotes = vars.remote,
        allRemote = vars.allRemote,
        UI = uiStruct or {},
        uiMap = uiMap or {},
        definedId = definedId,
        images = vars.images,
    }

    for k, v in pairs(vars.debug) do emu.debug[k] = v end

    if not conf.silent then resources.createDevice(dev) end
    return DIR[id]
end

customUI = {
    ['com.fibaro.binarySwitch'] = {
        {
            { button = "__turnon",  text = "Turn On",  onReleased = "turnOn" },
            { button = "__turnoff", text = "Turn Off", onReleased = "turnOff" }
        }
    },
    ['com.fibaro.multilevelSwitch'] = {
        {
            { button = "__turnon",  text = "Turn On",  onReleased = "turnOn" },
            { button = "__turnoff", text = "Turn Off", onReleased = "turnOff" }
        },
        { label = '_Brightness', text = 'Brightness' },
        { slider = '__value',    min = 0,            max = 99, onChanged = 'setValue' },
        {
            { button = '__sli', text = "&#8679;", onReleased = "startLevelIncrease" },
            { button = '__sld', text = "&#8681;", onReleased = "startLevelDecrease" },
            { button = '__sls', text = "&Vert;",  onReleased = "stopLevelChange" },
        },
    },
    ['com.fibaro.energyMeter'] = {
        { label = '__energy', text = '...' }
    },
    ['com.fibaro.powerMeter'] = {
        { label = '__power', text = '...' }
    },
    ['com.fibaro.temperatureSensor'] = {
        { label = '__temperature', text = '...' }
    },
    ['com.fibaro.humiditySensor'] = {
        { label = '__humidity', text = '...' }
    },
    ['com.fibaro.colorController'] = {
        {
            { button = '__turnon',  text = "Turn On",  onReleased = "turnOn" },
            { button = '__turnoff', text = "Turn Off", onReleased = "turnOff" }
        },
        { label = '_Brightness', text = 'Brightness' },
        { slider = '__value',    min = 0,            max = 99, onChanged = 'setValue' },
        {
            { button = '__sli', text = "&#8679;", onReleased = "startLevelIncrease" },
            { button = '__sld', text = "&#8681;", onReleased = "startLevelDecrease" },
            { button = '__sls', text = "&Vert;",  onReleased = "stopLevelChange" }
        }
    },
}

--customUI['com.fibaro.binarySensor']     = customUI['com.fibaro.binarySwitch']      -- For debugging
--customUI['com.fibaro.multilevelSensor'] = customUI['com.fibaro.multilevelSwitch']  -- For debugging

local function createChildDevice(pID, cdev)
    QA.syslog("install", "Child '%s' %s", cdev.name, cdev.type)
    local dev = devices.getDeviceStruct(cdev.type)
    if dev == nil then
        QA.syslogerr("install", "%s - Unknown device type '%s'", cdev.name, cdev.type)
        return
    end
    dev = copy(dev)
    dev.name = cdev.name
    dev.type = cdev.type
    dev.id = resources.nextRsrcId()
    for k, v in pairs(cdev.initialProperties or {}) do
        dev.properties[k] = v
    end
    dev.interfaces = merge(dev.interfaces, cdev.initialInterfaces or {})
    dev.parentId = pID
    local tag = "QUICKAPP" .. dev.id

    -- local uiStruct, uiMap = {}, {}
    -- if dev.properties.viewLayout then
    --     uiStruct, uiMap = ui.view2UI(dev.properties.viewLayout, dev.properties.uiCallbacks), nil
    -- end

    -- if next(uiStruct) == nil then
    --     local UI = customUI[dev.type] or {}
    --     ui.transformUI(UI)
    --     dev.properties.viewLayout = ui.mkViewLayout(UI, nil, dev.id)
    --     dev.properties.uiCallbacks = ui.uiStruct2uiCallbacks(UI)
    --     uiStruct = ui.view2UI(dev.properties.viewLayout, dev.properties.uiCallbacks)
    -- end
    -- uiStruct, uiMap = annotateUI(uiStruct)

    local UI =  ui.view2UI(dev.properties.viewLayout or {}, dev.properties.uiCallbacks or {})
    local uiStruct, uiMap = nil, nil

    if not QA.debugFlags.noStock then UI = addStockUI(dev, UI) end

    if next(UI) then
        ui.transformUI(UI)
        dev.properties.viewLayout = ui.mkViewLayout(UI, nil, dev.id)
        dev.properties.uiCallbacks = ui.uiStruct2uiCallbacks(UI)
        uiStruct = ui.view2UI(dev.properties.viewLayout, dev.properties.uiCallbacks)
        uiStruct, uiMap = annotateUI(uiStruct)
    end

    DIR[dev.id] = {
        fname = "",
        dev = dev,
        files = {},
        name = dev.name,
        tag = tag,
        debug = {},
        UI = uiStruct or {},
        uiMap = uiMap or {},
        remotes = {},
        allRemote = false,
        child = true,
    }
    resources.createDevice(dev)
    return DIR[dev.id]
end

local function loadFiles(id)
    local qa = DIR[id]
    local env = qa.env
    local loadedFiles = {}
    for _, qf in pairs(qa.files) do
        if qf.content == nil then
            local file = io.open(qf.fname, "r")
            assert(file, "File not found:" .. qf.fname)
            qf.content = file:read("*all")
            file:close()
        end
        if loadedFiles[qf.name] then
            QA.syslogerr(qa.tag, "Duplicate user file name '%s'", qf.name)
            return false
        end
        loadedFiles[qf.name] = true
        if qa.debug.userfiles then
            QA.syslog(qa.tag, "Loading user file %s", qf.fname or qf.name)
        end
        local path = qf.fname
        if FDIR ~="" and path:sub(1,#FDIR)==FDIR then
           path = "hc3fs:"..path:gsub(FDIR,"")
        else
            path = QA.pyhooks.expandPath(path)
        end
        local qa2, res = load(qf.content, path, "t", env) -- Load QA
        if not qa2 then
            QA.syslogerr(qa.tag, "%s - %s", qf.fname or qf.name, res)
            return false
        end
        qf.qa = qa2
        if qf.name == "main" and config['break'] and lldebugger then
            qf.qa = function() lldebugger.call(qa, true) end
        end
    end
    local imcont = { "_IMAGES={};\n" }
    for _, im in ipairs(qa.images or {}) do
        local file = io.open(im.fname, "r")
        assert(file, "Image not found:" .. im.name, im.fname)
        local img = file:read("*all")
        local w, h = getSize(img)
        imcont[#imcont + 1] = string.format([[
            _IMAGES['%s']={data='%s',w=%s,h=%s}
            ]], im.name, "data:image/png;base64," .. base64encode(img), w, h)
        file:close()
    end
    if #imcont > 1 then
        local content = table.concat(imcont, "\n")
        local qa2, res = load(content, "images", "t", env) -- Load QA
        table.insert(qa.files, 1, {
            qa = qa2,
            name = "IMAGES",
            content = content,
            type = 'lua',
            isMain = false,
            isOpen = false
        })
    end
    return true
end

local function getQAfiles(id, name)
    if not DIR[id] then return nil, 404 end
    if name == nil then
        local res = {}
        for _, f in ipairs(DIR[id].files) do
            res[#res + 1] = { name = f.name, content = nil, type = 'lua', isOpen = false, isMain = f.isMain }
        end
        return res, 200
    end
    for _, f in ipairs(DIR[id].files) do
        if f.name == name then
            return { name = f.name, content = f.content, type = 'lua', isOpen = false, isMain = f.isMain == true }, 200
        end
    end
    return nil, 404
end

local function setQAfiles(id, files)
    if not DIR[id] then return nil, 404 end
    local qa = DIR[id]
    files = type(files) == "string" and json.decode(files) or files
    for i = 1, #qa.files do
        local f = qa.files[i]
        if f.name == files.name then
            qa.files[i] = files
            QA.restart(id)
            return nil, 200
        end
    end
    qa.files[#qa.files + 1] = files
    QA.restart(id)
    return nil, 200
end

local function createFQA(id)
    local qa = DIR[id]
    local files = copy(qa.files)
    local dev = qa.dev
    for _, f in ipairs(files) do
        f.qa = nil
        f.fname = nil
        f.isOpen = false
        f.type = "lua"
    end

    local p = copy(dev.properties)
    p.viewLayout, p.uiCallbacks = ui.pruneStock(p)

    local props = {
        apiVersion = "1.2",
        quickAppVariables = p.quickAppVariables or {},
        uiCallbacks = #p.uiCallbacks > 0 and p.uiCallbacks or nil,
        viewLayout = p.viewLayout,
        typeTemplateInitialized = true,
    }
    local fqa = {
        apiVersion = "1.2",
        name = dev.name,
        type = dev.type,
        files = files,
        initialProperties = props,
        initialInterfaces = dev.interfaces,
    }
    return fqa
end

local function exportFQA(id)
    if not DIR[id] then
        if resources.getResource("devices", id) then
            local fqa, code = api.get("/quickApp/export/" .. id, "hc3")
            return fqa, code
        end
        return nil, 404
    end
end

local function importFQA(file)
end

local function file2fqa(fname)
    local qa = installQA(fname, {silent=true})
    assert(qa, "File not found:" .. fname)
    local dev = qa.dev
    local files = qa.files
    loadFiles(qa.dev.id)
    for _, f in ipairs(files) do
        f.qa = nil
        f.fname = nil
        f.isOpen = false
        f.type = "lua"
    end

    local p = copy(dev.properties)
    p.viewLayout, p.uiCallbacks = ui.pruneStock(p)

    local props = {
        apiVersion = "1.2",
        quickAppVariables = p.quickAppVariables or {},
        uiCallbacks = #p.uiCallbacks > 0 and p.uiCallbacks or nil,
        viewLayout = p.viewLayout,
        typeTemplateInitialized = true,
    }
    local fqa = {
        apiVersion = "1.2",
        name = dev.name,
        type = dev.type,
        files = files,
        initialProperties = props,
        initialInterfaces = dev.interfaces,
    }
    return fqa
end

local function deleteQAfile(id, name)
    if not DIR[id] then return nil, 404 end
    local files = DIR[id].files
    for i = 1, #files do
        if files[i].name == name then
            table.remove(files, i)
            QA.restart(id)
            return name, 200
        end
    end
    return nil, 404
end

exports = {
    installQA = installQA,
    init = init,
    loadFiles = loadFiles,
    getQAfiles = getQAfiles,
    setQAfiles = setQAfiles,
    importQA = importFQA,
    exportFQA = exportFQA,
    createFQA = createFQA,
    installFQA = installFQA,
    file2FQA = file2fqa,
    deleteQAfile = deleteQAfile,
    createChildDevice = createChildDevice,
}
return exports
