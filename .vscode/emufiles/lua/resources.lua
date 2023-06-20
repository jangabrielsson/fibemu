local r, config, refreshStates = {},nil

local function copy(o)
    if type(o) ~= 'table' then return o end
    local res = {}
    for k, v in pairs(o) do res[k] = copy(v) end
    return res
end

local keys = {
    globalVariables = "name",
    devices = "id",
    rooms = "id",
    sections = "id",
}

local rsrcs = {
    globalVariables = nil,
    devices = nil,
    rooms = nil,
    sections = nil,
}

function r.refresh(flag)
    if flag then
        r.refresh_resource("globalVariables", "name")
        r.refresh_resource("devices", "id")
        r.refresh_resource("rooms", "id")
        r.refresh_resource("sections", "id")
    end
end

local function postEvent(typ, data)
    local e = {
        type = typ,
        _emu = true,
        data = data,
        created = os.time(),
    }
    refreshStates.newEvent(e)
end

function r.init(conf, libs)
    config = conf
    refreshStates = libs.refreshStates
    for name, fun in pairs(r) do QA.fun[name] = fun end -- export resource functions
end

function r.refresh_resource(name, key, id)
    if id then
        local r = nil
        if not config.lcl then r = api.get("/" .. name .. "/" .. id, "hc3") end
        if r then
            rsrcs[name][id] = r
        end
        return r
    else
        rsrcs[name] = {}
        local rss = {}
        if not config.lcl then rss = api.get("/" .. name, "hc3") or {} end
        for _, rs in ipairs(rss) do
            rsrcs[name][rs[key]] = rs
        end
    end
    return rsrcs[name]
end

local function initr(typ)
    if rsrcs[typ] == nil then
        r.refresh_resource(typ, keys[typ])
    end
end

function r.getResource(typ, id)
    initr(typ)
    local rs = rsrcs[typ] or {}
    local res = id == nil and rs or rs[id]
    return res, res and 200 or 404
end

function r.createResource(typ, d)
    d = type(d) == 'string' and json.decode(d) or d
    initr(typ)
    local rs = rsrcs[typ] or {}
    local id = d[keys[typ]]
    if rs[id] then return nil, 404 end
    rs[id] = d
    return d, 200
end

function r.createGlobalVariable(d, sync)
    initr("globalVariables")
    d = type(d) == 'string' and json.decode(d) or d
    if sync then r.refresh_resource("globalVariables", nil, d.name) return end
    local name = d.name
    if rsrcs.globalVariables[name] then return nil, 409 end
    local gv = copy(d)
    gv.modified = os.time()
    gv.created = gv.modified
    rsrcs.globalVariables[name] = gv
    postEvent("GlobalVariableAddedEvent", { variableName = name, value = gv.value })
    return gv, 200
end

function r.removeGlobalVariable(name, sync)
    initr("globalVariables")
    if sync then rsrcs.globalVariables[name] = nil return end
    if rsrcs.globalVariables[name] == nil then return nil, 404 end
    rsrcs.globalVariables[name] = nil
    postEvent("GlobalVariableRemovedEvent", { variableName = name })
    return nil, 200
end

function r.updateGlobalVariable(name, d, sync)
    initr("globalVariables")
    d = type(d) == 'string' and json.decode(d) or d
    if sync then r.refresh_resource("globalVariables", nil, name) return end
    if rsrcs.globalVariables[name] == nil then return nil, 404 end
    local gv = rsrcs.globalVariables[name]
    local flag = false
    if gv.value ~= d.value then
        gv.modified = os.time()
        local oldValue = gv.value
        gv.value = d.value
        postEvent("GlobalVariableChangedEvent", { variableName = name, value = gv.value, oldValue = oldValue })
    end
    return gv, 200
end

function r.createDevice(d, sync)
    d = type(d) == 'string' and json.decode(d) or d
    if sync then r.refresh_resource("devices", nil, d.id) return end
    local id = d.id
    if rsrcs.devices[id] then return nil, 409 end
    local dv = copy(d)
    dv.modified = os.time()
    dv.created = dv.modified
    rsrcs.devices[id] = dv
    postEvent("DeviceCreatedEvent", { id = id })
    return dv, 200
end

function r.removeDevice(id, sync)
    if sync then rsrcs.devices[id] = nil return end
    if rsrcs.devices[id] == nil then return nil, 404 end
    rsrcs.devices[id] = nil
    postEvent("DeviceRemovedEvent", { id = id })
    return nil, 200
end

function r.updateDeviceProp(d, sync)
    d = type(d) == 'string' and json.decode(d) or d
    local id = d.deviceId or d.id
    if sync then r.refresh_resource("devices", nil, id) return end
    local prop = d.propertyName
    local value = d.value
    if rsrcs.devices[id] == nil then return nil, 404 end
    local dv = rsrcs.devices[id]
    if dv.properties[prop] == value then return nil, 200 end
    local oldValue = dv.properties[prop]
    dv.properties[prop] = value
    postEvent("DevicePropertyUpdatedEvent", { id = id, property = prop, newValue = value, oldValue = oldValue })
    return nil, 200
end

function r.createRoom(d, sync)
    d = type(d) == 'string' and json.decode(d) or d
    if sync then r.refresh_resource("rooms", nil, d.id) return end
    return nil, 200
end

function r.removeRoom(id, sync)
    initr("rooms")
    if sync then rsrcs.rooms[id]=nil return end
    if rsrcs.rooms[id] == nil then return nil, 404 end
    rsrcs.rooms[id] = nil
    return nil, 200
end

function r.updateRoom(id, d, sync)
    d = type(d) == 'string' and json.decode(d) or d
    if sync then r.refresh_resource("rooms", nil, d.id) return end
    return nil, 200
end

function r.createSection(d, sync)
    d = type(d) == 'string' and json.decode(d) or d
    if sync then r.refresh_resource("sections", nil, d.id) return end
    return nil, 200
end

function r.removeSection(id, sync)
    initr("sections")
    if rsrcs.sections[id] == nil then return nil, 404 end
    rsrcs.sections[id] = nil
    return nil, 200
end

function r.updateSection(id, d, sync)
    d = type(d) == 'string' and json.decode(d) or d
    if sync then r.refresh_resource("sections", nil, d.id) return end
    return nil, 200
end

return r
