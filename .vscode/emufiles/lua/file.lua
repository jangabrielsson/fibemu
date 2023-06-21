local config, resources, devices, lldebugger = nil, nil, nil, nil
local libs,exports = nil, nil
local copy,merge
local gID = 5000

local function init(conf, libs2)
    libs = libs2
    config = conf
    resources = libs.resources
    devices = libs.devices
    lldebugger = libs.lldebugger
    copy,merge = libs.util.copy,libs.util.merge
    for name, fun in pairs(exports) do QA.fun[name] = fun end -- export file functions
end

local function installFQA(fqa, id)
    QA.syslog("Install","FQA '%s'", fqa.name)
    local dev = devices.getDeviceStruct(fqa.type)
    if dev == nil then
        QA.syslogerr("Install","%s - Unknown device type '%s'", fqa.name, fqa.type)
        return
    end
    dev = copy(dev)
    dev.name = fqa.name
    dev.type = fqa.type
    dev.id = gID; gID = gID + 1
    for k,v in pairs(fqa.initialProperties or {}) do
        dev.properties[k] = v
    end
    dev.interfaces = merge(dev.interfaces,fqa.initialInterfaces or {})
    dev.parentId = 0
    DIR[dev.id] = { fname = "", dev = dev, files = fqa.files, name = dev.name }
    resources.createDevice(dev)
    return DIR[dev.id]
end

local function installQA(fname, id)
    QA.syslog("Install","QA '%s'", fname)
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

    local chandler = {}
    function chandler.name(var, val, dev) dev.name = val end
    function chandler.type(var, val, dev) dev.type = val end
    function chandler.id(var, val, dev) dev.id = tonumber(id) end
    function chandler.file(var, val, dev)
        local fn, qn = table.unpack(val:sub(1, -2):split(","))
        dev.files[#dev.files + 1] = { fname = fn, name = qn, isMain=false, content = nil }
    end

    local vars = { files = {} }
    code:gsub("%-%-%%%%([%w_]+)=(.-)[\n\r]", function(var, val)
        if chandler[var] then
            chandler[var](var, val, vars)
        else
            QA.syslogerr("Install","%s - Unknown header variable '%s'", fname, var)
        end
    end)
    table.insert(vars.files, { name='main', isMain=true, content = code, fname = fname })

    if vars.id == nil then
        vars.id = gID; gID = gID + 1
    end
    id = vars.id

    if DIR[id] then
        QA.syslogerr("Install","ID:%s already installed (%s)", id, fname)
        return
    end

    local dev = devices.getDeviceStruct(vars.type or "com.fibaro.binarySwitch")
    if dev == nil then
        QA.syslogerr("Install","%s - Unknown device type '%s'", fname, vars.type)
        dev = devices.getDeviceStruct("com.fibaro.binarySwitch")
    end
    dev = copy(dev)
    dev.name = vars.name or name
    dev.id = vars.id
    dev.properties.quickAppVariables = {}
    dev.interfaces = {}
    dev.parentId = 0

    DIR[id] = { fname = fname, dev = dev, files = vars.files, name = dev.name }
    resources.createDevice(dev)
    return DIR[id]
end

local function loadFiles(id)
    local qa = DIR[id]
    local env = qa.env
    for _, qf in pairs(qa.files) do
        if qf.content == nil then
            local file = io.open(qf.fname, "r")
            assert(file, "File not found:" .. qf.fname)
            qf.content = file:read("*all")
            file:close()
        end
        QA.syslog("Loading","User file %s",qf.fname or qf.name)
        local qa, res = load(qf.content, qf.fname, "t", env) -- Load QA
        if not qa then
            QA.syslogerr("Loading","%s - %s", qf.fname or qf.nam, res)
            return false
        end
        qf.qa = qa
        if qf.name == "main" and config['break'] and lldebugger then
            qf.qa = function() lldebugger.call(qa, true) end
        end
    end
    return true
end

local function getQAfiles(id,name)
    if not DIR[id] then return nil,404 end
    if name == nil then
        local res
        for f in ipairs(DIR[id].files) do
            res[#res+1]={name=f.name,content=nil,type='lua',isOpen=false,isMain=f.isMain}
        end
        return res,200
    end
    for _,f in ipairs(DIR[id].files) do
        if f.name == name then
            return {name=f.name,content=f.content,type='lua',isOpen=false,isMain=f.isMain==true},200
        end
    end
    return nil,404
end

local function setQAfiles(id,files)
    if not DIR[id] then return nil,404 end
    local qa = DIR[id]
    files = type(files)=="string" and json.decode(files) or files
    for i = 1,#qa.files do
        local f = qa.files[i]
        if f.name == files.name then
            qa.files[i] = files
            QA.restart(id)
            return nil,200
        end
    end
    qa.files[#qa.files+1] = files
    QA.restart(id)
    return nil,200
end

local function exportFQA(id)
    if not DIR[id] then 
        if resources.getResource("devices",id) then
            local fqa,code = api.get("/quickApp/export/"..id,"hc3")
            return fqa,code
        end
        return nil,404 
    end
end

local function importFQA(file)
end

local function deleteQAfile(id,name)
    if not DIR[id] then return nil,404 end
    local files = DIR[id].files
    for i = 1, #files do
        if files[i].name == name then
            table.remove(files, i)
            QA.restart(id)
            return name,200
        end
    end
    return nil,404
end

exports = { 
    installQA = installQA, init = init, loadFiles = loadFiles,
    getQAfiles = getQAfiles, setQAfiles = setQAfiles,
    importQA = importFQA, exportFQA = exportFQA,
    installFQA = installFQA,
    deleteQAfile = deleteQAfile
}
return exports
