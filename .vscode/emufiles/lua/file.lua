local config, resources, devices = nil, nil, nil
local gID = 5000

local function init(conf, libs)
    config = conf
    resources = libs.resources
    devices = libs.devices
end

local function installQA(fname, id)
    QA.syslog("Install","QA %s", fname)
    local f = io.open(fname, "r")
    if not f then
        QA.syslogerr("Install","File not found - %s", fname)
        return
    end
    local code = f:read("*all")
    f:close()

    local name, ftype = fname:match("([%w_]+)%.([luafq]+)$")
    if ftype ~= "lua" then
        QA.syslogerr("Install"," Unsupported file type - %s", tostring(ftype))
        return
    end

    local qaFiles = {}
    local chandler = {}
    function chandler.name(var, val, dev) dev.name = val end
    function chandler.type(var, val, dev) dev.type = val end
    function chandler.id(var, val, dev) dev.id = tonumber(id) end
    function chandler.file(var, val, dev)
        local fn, qn = table.unpack(val:sub(1, -2):split(","))
        dev.files = dev.files or {}
        dev.files[#dev.files + 1] = { fname = fn, qaname = qn }
    end

    local vars = {}
    code:gsub("%-%-%%%%([%w_]+)=(.-)[\n\r]", function(var, val)
        if chandler[var] then
            chandler[var](var, val, vars)
        else
            QA.syslogerr("Install %s - Unknown header variable '%s'", fname, var)
        end
    end)
    table.insert(vars.files, { code = code, fname = fname, qaname = 'main' })

    if vars.id == nil then
        vars.id = gID; gID = gID + 1
    end
    id = vars.id

    if DIR[id] then
        QA.syslogerr("Install ID:%s already installed (%s)", id, fname)
        return
    end

    local dev = devices.getDeviceStruct(vars.type or "com.fibaro.binarySwitch")
    if dev == nil then
        QA.syslogerr("Install %s - Unknown device type '%s'", fname, vars.type)
        dev = devices.getDeviceStruct("com.fibaro.binarySwitch")
    end
    dev.name = vars.name or name
    dev.id = vars.id
    dev.properties.quickAppVariables = {}
    dev.interfaces = {}
    dev.parentId = 0

    DIR[id] = { fname = fname, dev = dev, files = vars.files, name = dev.name }
    resources.createDevice(dev)
    return DIR[id]
end

return { installQA = installQA, init = init }