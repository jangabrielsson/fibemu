local r, config, refreshStates = {},nil,nil
local copy

function r.init(conf, libs)
    config = conf
    refreshStates = libs.refreshStates
    copy = libs.util.copy
    for name, fun in pairs(r) do QA.fun[name] = fun end -- export resource functions
end

local keys = {
    globalVariables = "name",
    devices = "id",
    rooms = "id",
    sections = "id",
    customEvents = "name",
}

local rsrcs = {
    globalVariables = nil,
    devices = nil,
    rooms = nil,
    sections = nil,
    customEvents = nil,
}

function r.refresh(flag)
    if flag then
        r.refresh_resource("globalVariables", "name")
        r.refresh_resource("devices", "id")
        r.refresh_resource("rooms", "id")
        r.refresh_resource("sections", "id")
        r.refresh_resource("customEvents", "name")
    end
end

local function postEvent(typ, data)
    local e = {
        type = typ,
        _emu = true,
        data = data,
        created = os.time(),
    }
    QA.addEvent(json.encode(e))
    refreshStates.newEvent(e)
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

local CE,DE,ME = {},{},{}
function CE.globalVariables(d) return "GlobalVariableAddedEvent",{variableName=d.name,value=d.value} end
function CE.rooms(d) return "RoomCreatedEvent", {id = d.id} end
function CE.sections(d) return "SectionCreatedEvent", {id = d.id} end
function CE.devices(d) return "DeviceCreatedEvent", d end
function CE.customEvents(d) return "CustomEventCreatedEvent", d end
function DE.globalVariables(d) return "GlobalVariableRemovedEvent", {variableName=d.name,value=d.value} end
function DE.rooms(d) return "RoomRemovedEvent", {id = d.id} end
function DE.sections(d) return "SectionRemovedEvent", {id = d.id} end
function DE.devices(d) return "DeviceRemovedEvent", {id = d.id} end
function DE.customEvents(d) return "CustomEventRemovedEvent", {id = d.name} end
function ME.globalVariables(d,ov) return "GlobalVariableChangedEvent", {variableName=d.name, value=d.value, oldValue=ov} end
function ME.rooms(d) return "RoomModifiedEvent", {id = d.id} end
function ME.sections(d) return "SectionModifiedEvent", {id = d.id} end
function ME.devices(d) return "DeviceModifiedEvent", d end
function ME.customEvents(d) return "CustomEventModifiedEvent", d end
local UA = {
    globalVariables = {name=true, value=true},
    rooms = {name=true},
    customEvents = {name=true, userDescription=true},
    sections = {name=true},
    devices = {name=true, roomID=true, sectionID=true, enabled=true, visible=true},
}

local rsrcID = 8000
function r.createResource(typ, d)
    d = type(d) == 'string' and json.decode(d) or d
    initr(typ)
    local rs = rsrcs[typ] or {}
    local id = d[keys[typ]] 
    if id == nil then id = rsrcID; d[keys[typ]] = id; rsrcID = rsrcID + 1 end -- generate id
    if rs[id] then return nil, 409 end
    rs[id] = d
    d.modified = os.time() d.created = d.modified
    if CE[typ] then postEvent(CE[typ](d)) end
    return d, 200
end

function r.deleteResource(typ, id)
    initr(typ)
    local rs = rsrcs[typ] or {}
    local d = rs[id]
    if d==nil then return nil, 404 end
    rs[id] =nil
    if DE[typ] then postEvent(DE[typ](d)) end
    return d, 200
end

function r.modifyResource(typ, id, nd)
    nd = type(nd) == 'string' and json.decode(nd) or nd
    initr(typ)
    local key = keys[typ]
    local rs = rsrcs[typ] or {}
    local ed, oldValue = rs[id]
    rs[id] = nil
    if ed==nil then return nil, 404 end
    local flag = false
    for k,v in pairs(nd) do
        if UA[typ][k] and ed[k] ~= v then
            oldValue = ed[k]
            ed[k] = v
            flag = true
        end
    end
    rs[ed[key]] = ed
    if flag then ed.modified = os.time() end
    if flag and ME[typ] then postEvent(ME[typ](ed,oldValue)) end
    return ed, 200
end

function r.createDevice(d) return r.createResource("devices", d) end

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

function r.emitCustomEvent(name)
    if rsrcs.customEvents[name] == nil then return {}, 404 end
    postEvent("CustomEvent",rsrcs.customEvents[name])
    return {},204
end

return r
