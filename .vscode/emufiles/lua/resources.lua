local r, config, refreshStates = {},nil,nil
local copy,emu

function r.init(conf, libs)
    config = conf
    refreshStates = libs.refreshStates
    copy,emu = libs.util.copy,libs.emu
    for name, fun in pairs(r) do QA.fun[name] = fun end -- export resource functions
end

local keys = {
    globalVariables = "name",
    devices = "id",
    rooms = "id",
    sections = "id",
    customEvents = "name",
    iosDevices = "id",
    users = "id",
    ['panels/location'] = "id",
    ['energy/devices'] = "id",
    notificationCenter = "id",
    icons = "iconSet",
    ['alarms/v1/devices'] = "id",
    ['alarms/v1/partitions'] = "id",
    ['panels/notifications'] = "id",
    --['panels/family'] = "id",
    ['panels/sprinklers'] = "id",
    ['panels/humidity'] = "id",
    ['panels/favoriteColors'] = "id",
    ['panels/favoriteColors/v2'] = "id",
}

local rsrcs = {
    globalVariables = nil,
    devices = nil,
    rooms = nil,
    sections = nil,
    customEvents = nil,
    ['settings/location'] = nil,
    ['settings/info'] = nil,
    ['settings/led'] = nil,
    ['settings/network'] = nil,
    ['alarms/v1/partitions'] = nil,
    ['alarms/v1/devices'] = nil,
    notificationCenter = nil,
    profiles = nil,
    users = nil,
    icons = nil,
    weather = nil,
    debugMessages = nil,
    home = nil,
    iosDevices = nil,
    ['energy/devices'] = nil,
    ['panels/location'] = nil,
    ['panels/notifications'] = nil,
    ['panels/family'] = nil,
    ['panels/sprinklers'] = nil,
    ['panels/humidity'] = nil,
    ['panels/favoriteColors'] = nil,
    diagnostics = nil,
    sortOrder = nil,
    loginStatus = nil,
    RGBprograms = nil,
}

local function postEvent(typ, data)
    local e = {
        type = typ,
        _emu = true,
        data = data,
        created = os.time(),
    }
    QA.addEvent(json.encode(e))
    refreshStates.logEvent(e)
end

local gID = 4999
function r.nextRsrcId() gID = gID + 1; return gID end

function r.refresh_resource(typ, key, id)
    if id then
        local r = nil
        if not config.lcl then r = api.get("/" .. typ .. "/" .. id, "hc3") end
        if r then
            rsrcs[typ][id] = r
        end
        return r
    else
        if emu.debug.refresh_resource then
            QA.syslog("resource", "refresh '%s'", typ)
        end
        rsrcs[typ] = {}
        local rss = {}
        if not config.lcl then rss = api.get("/" .. typ, "hc3") or {} end
        if key == nil then 
            rsrcs[typ] = rss
            rss._local = emu.isShadow(typ,id)
        else
            for _, rs in ipairs(rss) do
                local id = rs[key]
                rsrcs[typ][id] = rs
                rsrcs[typ][id]._local = emu.isShadow(typ,id)
            end
            rsrcs[typ]._dict = true
        end
    end
    return rsrcs[typ]
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
function DE.globalVariables(d) return "GlobalVariableRemovedEvent", {variableName=d.name,newValue=d.value} end
function DE.rooms(d) return "RoomRemovedEvent", {id = d.id} end
function DE.sections(d) return "SectionRemovedEvent", {id = d.id} end
function DE.devices(d) return "DeviceRemovedEvent", {id = d.id} end
function DE.customEvents(d) return "CustomEventRemovedEvent", {id = d.name} end
function ME.globalVariables(d,ov) return "GlobalVariableChangedEvent", {variableName=d.name, newValue=d.value, oldValue=ov} end
function ME.rooms(d) return "RoomModifiedEvent", {id = d.id} end
function ME.sections(d) return "SectionModifiedEvent", {id = d.id} end
function ME.devices(d) return "DeviceModifiedEvent", {id = d.id} end
function ME.weather(d,ov)
    local p,v = next(d)
    return "WeatherChangedEvent", {change=p,newValue=v,oldValue=ov} 
end
function ME.customEvents(d) return "CustomEventModifiedEvent", d end
local UA = { -- properties we can modify
    globalVariables = {name=true, value=true},
    rooms = {name=true},
    customEvents = {name=true, userDescription=true},
    sections = {name=true},
    devices = {name=true, roomID=true, sectionID=true, enabled=true, visible=true},
    weather = {
        Temperature = true, Humidity=true,ConditionCode=true,TemperatureUnit=true, WeatherCondition=true,
        WeatherConditionConverted=true, Wind=true, WindUnit=true
    }
}

local rsrcID = 8000

local function createResource_remote(typ, id) -- incoming trigger from HC3
    initr(typ)
    local rs = rsrcs[typ] or {}
    if rs[id] and rs[id]._local then return end -- existing local, ignore
    rs[id] = api.get("/" .. typ .. "/" .. id, "hc3")
    return true
end

local function createResource_local(typ, d)
    d = type(d) == 'string' and json.decode(d) or d
    initr(typ)
    local key = keys[typ]
    local rs = rsrcs[typ] or {}
    d._local = true
    local id = d.id or r.nextRsrcId(); d[key] = id  -- generate id
    if rs[id] then return nil, 409 end -- already exsists
    rs[id] = d
    d.modified = os.time() d.created = d.modified
    if CE[typ] then postEvent(CE[typ](d)) end
    return d, 200
end

function r.createResource(typ, d, remote)
    if remote then return createResource_remote(typ, d) else return createResource_local(typ, d) end
end

local function deleteResource_remote(typ, id)
    initr(typ)
    local rs = rsrcs[typ] or {}
    if rs[id] and rs[id]._local then return end
    rs[id]=nil
    return true
end

local function deleteResource_local(typ, id)
    initr(typ)
    local rs = rsrcs[typ] or {}
    local d = rs[id]
    if d==nil then return nil, 404 end
    if not d._local then
        if not emu.hasPermission(typ,id) then
            return nil, 403
        else                             -- sync back to hc3
            api.delete("/" .. typ .. "/" .. id, "hc3")
            rs[id] = nil
            return d,200
        end
    end
    rs[id] = nil
    if DE[typ] then postEvent(DE[typ](d)) end
    return d, 200
end

function r.deleteResource(typ, id, remote)
    if remote then return deleteResource_remote(typ, id) else return  deleteResource_local(typ, id) end
end

local function modifyResource_remote(typ, id, nd)
    nd = type(nd) == 'string' and json.decode(nd) or nd
    initr(typ)
    local rs = rsrcs[typ] or {}
    if rs[id] and rs[id]._local then return end -- local shadow, ignore
    rs[id] = api.get("/" .. typ .. "/" .. id, "hc3") or {}
    return true
end

local function modifyResource_local(typ, id, nd)
    nd = type(nd) == 'string' and json.decode(nd) or nd
    initr(typ)
    local key = keys[typ]
    local rs = rsrcs[typ] or {}
    local ed, oldValue = key==nil and rs or rs[id],nil
    if key then rs[id] = nil end
    if ed==nil then return nil, 404 end
    if not ed._local and not emu.hasPermission(typ,id) then
        if key then rs[id] = ed end
        return nil, 403
    end
    local flag = false
    local props = {}
    for k,v in pairs(nd) do
        if UA[typ][k] and ed[k] ~= v then
            oldValue = ed[k]
            props[k] = v
            ed[k] = v
            flag = true
        end
    end
    if key then rs[ed[key]] = ed end
    if not flag then return ed,200 end
    ed.modified = os.time() 
    if not ed._local then       -- sync back to HC3
        local r,c = api.put("/" .. typ .. "/" .. id, props, "hc3")
        return r,c
    end
    if ME[typ] then postEvent(ME[typ](props,oldValue)) end
    return ed, 200
end

function r.modifyResource(typ, id, nd, remote)
    if remote then return modifyResource_remote(typ, id, nd) else return modifyResource_local(typ, id, nd) end
end

function r.createDevice(d) return r.createResource("devices", d) end

function r.updateDeviceProp(arg, remote)
    d = type(d) == 'string' and json.decode(d) or d
    initr("devices")
    local id = arg.deviceId or arg.id
    if remote then r.refresh_resource("devices", nil, id) return true end
    local prop = arg.propertyName
    local newValue = arg.value
    if rsrcs.devices[id] == nil then return nil, 404 end
    local d = rsrcs.devices[id]
    if d.properties[prop] == newValue then return nil, 200 end
    if not d._local then
        if not emu.hasPermission("devices",id) then
            return nil, 403
        else                             -- sync back to hc3
            api.put("/devices/" .. id,{ properties = {[prop] = newValue }}, "hc3")
            d.properties[prop] = newValue
            return nil, 200
        end
    end
    local oldValue = d.properties[prop]
    d.properties[prop] = newValue
    postEvent("DevicePropertyUpdatedEvent", { id = id, property = prop, newValue = newValue, oldValue = oldValue })
    return nil, 200
end

function r.emitCustomEvent(name)
    initr("customEvents")
    if rsrcs.customEvents[name] == nil then return {}, 404 end
    postEvent("CustomEvent",rsrcs.customEvents[name])
    return {},204
end

return r
