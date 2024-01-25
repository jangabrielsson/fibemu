local r, rsrcs, config, refreshStates = {}, {}, nil, nil
local copy, emu, binser
local defaultRsrcs = {}

function r.init(conf, libs)
    config = conf
    refreshStates = libs.refreshStates
    copy, emu, binser = libs.util.copy, libs.emu, libs.binser
    for name, fun in pairs(r) do QA.fun[name] = fun end -- export resource functions
    defaultRsrcs['settings/network'].networkConfig.wlan0.ipConfig.ip = emu.config.whost
    if conf.storage then
        local f = io.open(conf.storage, "r")
        if f then
            local data = f:read("*a")
            local stat,res = pcall(json.decode,data)
            if stat then
                local id,data = next(res)
                rsrcs.keys[tonumber(id)] = data
                --QA.syslog("resource","loaded keys: %s",res)
            else
                --QA.syslog("resource","failed to load keys: %s",res)
            end
        end
        conf.storageKeys = rsrcs.keys
    end
end

local function updateDates()
    local sunrise, sunset = QA.libs.time.suntime(os.time())
    --print(sunrise,sunset)
    defaultRsrcs['devices'][1].properties.sunriseHour = sunrise
    defaultRsrcs['devices'][1].properties.sunsetHour = sunset
end

local _intercepts = { devices={} }
_intercepts.devices[1] = function() updateDates() end
_intercepts.devices[2] = function() updateDates() end

local function intercept(typ,id)
    if _intercepts[typ] and _intercepts[typ][id] then
        _intercepts[typ][id](typ,id)
    end
end

defaultRsrcs['devices'] = {
    [1] = {
        id = 1,
        name = "zwave",
        roomID = 219,
        type = "com.fibaro.zwavePrimaryController",
        baseType = "",
        enabled = true,
        visible = false,
        isPlugin = false,
        parentId = 0,
        interfaces = {
            "energy",
            "zwave"
        },
        properties = {
            UIMessageSendTime = 0,
            autoConfig = 0,
            configured = true,
            date = "a",
            dead = false,
            deviceControlType = 1,
            deviceIcon = 28,
            deviceRole = "Other",
            disabled = 1,
            emailNotificationID = 0,
            emailNotificationType = 0,
            energy = 0,
            log = "",
            logTemp = "",
            manufacturer = "",
            markAsDead = true,
            model = "",
            nodeID = 1,
            nodeId = 1,
            productInfo = "",
            pushNotificationID = 0,
            pushNotificationType = 0,
            saveLogs = true,
            saveToEnergyPanel = true,
            serialNumber = "",
            showChildren = 1,
            smsNotificationID = 0,
            smsNotificationType = 0,
            status = "STAT_IDLE",
            storeEnergyData = true,
            sunriseHour = "04:31",
            sunsetHour = "21:14",
            userDescription = "",
            value = 0,
            zwaveBuildVersion = "3.67",
            zwaveCompany = "Unknown",
            zwaveInfo = "",
            zwaveRegion = "EU",
            zwaveVersion = "4.33"
        },
        actions = {
            pollingDeadDevice = 1,
            pollingTimeSec = 1,
            reconfigure = 0,
            requestNodeNeighborUpdate = 1,
            reset = 0,
            turnOff = 0,
            turnOn = 0
        }
    },
    [2] = {
        id = 2,
        name = "admin",
        roomID = 219,
        type = "HC_user",
        baseType = "com.fibaro.voipUser",
        enabled = true,
        visible = true,
        isPlugin = false,
        parentId = 0,
        interfaces = {
            "energy",
            "voip"
        },
        properties = {
            Email = "foo@bar.com",
            HotelModeRoom = 0,
            LastPwdChange = 1684757552,
            Latitude = 52.4320294933,
            Location = "52.4320294933;16.8449900900",
            LocationTime = "2012-12-06 12:15",
            LocationTimestamp = 1354792521,
            Longitude = 16.84499009,
            PreviousLatitude = 52.4320252015,
            PreviousLocation = "52.4320252015;16.8449947542",
            PreviousLocationTime = "2012-12-06 12:14",
            PreviousLocationTimestamp = 1354792461,
            PreviousLongitude = 16.844994754200002,
            SendNotifications = true,
            TrackUser = 1,
            UserType = "superuser",
            atHome = false,
            deviceIcon = 91,
            energy = 0,
            fidLastSynchronizationTimestamp = 1689148003,
            fidRole = "USER",
            fidUuid = "b7a2295a-2615-40d0-84d9-f22de24875fe",
            firmwareUpdateLevel = 0,
            integrationPin = "",
            saveLogs = true,
            saveToEnergyPanel = true,
            sipDisplayName = "_",
            sipUserEnabled = true,
            sipUserID = "1",
            sipUserPassword = "",
            skin = "light",
            skinSetting = "manual",
            storeEnergyData = true,
            useIntegrationPin = false,
            useOptionalArmPin = false,
            usePin = false
        },
        actions = {
            reset = 0,
            sendDefinedEmailNotification = 1,
            sendDefinedSMSNotification = 2,
            sendEmail = 2,
            sendGlobalEmailNotifications = 1,
            sendGlobalPushNotifications = 1,
            sendGlobalSMSNotifications = 1,
            sendPush = 1,
            setSipDisplayName = 1,
            setSipUserID = 1,
            setSipUserPassword = 1
        },
    }
}

defaultRsrcs['settings/location'] = {
    city = "Berlin",
    latitude = 52.520008,
    longitude = 13.404954,
}

defaultRsrcs['settings/info'] = {
    serialNumber = "HC3-00000999",
    platform = "HC3",
    zwaveEngineVersion = "2.0",
    hcName = "HC3-00000999",
    mac = "ac:17:02:0d:35:c8",
    zwaveVersion = "4.33",
    timeFormat = 24,
    zwaveRegion = "EU",
    serverStatus = os.time(),
    defaultLanguage = "en",
    defaultRoomId = 219,
    sunsetHour = "15:23",
    sunriseHour = "07:40",
    hotelMode = false,
    temperatureUnit = "C",
    batteryLowNotification = false,
    date = "09:53 | 15.11.2021",
    dateFormat = "dd.mm.yy",
    decimalMark = ".",
    timezoneOffset = 3600,
    currency = "EUR",
    softVersion = "5.142.83", 
    beta = false,
    currentVersion = {
        version = "5.142.83",
        type = "stable"
    },
    installVersion = {
        version = "",
        type = "",
        status = "",
        progress = 0
    },
    timestamp = os.time(),
    online = false,
    tosAccepted = true,
    skin = "light",
    skinSetting = "manual",
    updateStableAvailable = false,
    updateBetaAvailable = false,
    newestStableVersion = "5.090.17",
    newestBetaVersion = "5.000.15",
    isFTIConfigured = true,
    isSlave = false,
}

defaultRsrcs['settings/network'] = {
    networkConfig = {
        wlan0 = {
            enabled = true,
            ipConfig = {
                ip = "2.2.2.2",
            }
        }
    }
}

defaultRsrcs.users = {
    [2] = {
        id = 2,
        name = "admin",
        type = "superuser",
        email = "foo@bar.com",
        deviceRights = {},
        sceneRights = {},
        alarmRights = {},
        profileRights = {},
        climateZoneRights = {},
    }
}

defaultRsrcs['panels/location'] = {
    [6] = {
        id = 6,
        name = "My Home",
        address = "Serdeczna 3, Wysogotowo",
        longitude = 16.791597,
        latitude = 52.404958,
        radius = 150,
        home = true,
    }
}

defaultRsrcs.weather = {
    Temperature = 3.1,
    TemperatureUnit = "C",
    Humidity = 51.4,
    Wind = 29.52,
    WindUnit = "km/h",
    WeatherCondition = "clear",
    ConditionCode = 32
}

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

rsrcs = {
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

local function getDefaultResource(typ)
    return defaultRsrcs[typ] or {}
end

local function postEvent(typ, data)
    local e = {
        type = typ,
        _emu = true,
        data = data,
        created = os.time(),
    }
    --print("ADDED",json.encode(e))
    QA.addEvent(json.encode(e))
    refreshStates.logEvent(e)
end

local gID = 4999
function r.nextRsrcId()
    gID = gID + 1; return gID
end

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
        local rss
        if not config.lcl then rss = api.get("/" .. typ, "hc3") end
        if rss == nil then rss = getDefaultResource(typ) end
        if key == nil then
            rsrcs[typ] = rss
            rss._local = emu.isLocal(typ, id)
        else
            for _, rs in ipairs(rss) do
                local id = rs[key]
                rsrcs[typ][id] = rs
                rsrcs[typ][id]._local = emu.isLocal(typ, id)
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

function r.dumpResources(fname)
    local stat, res = pcall(function()
        binser.writeFile(fname, rsrcs)
        return true
    end)
    if stat and res then return true, 200 end
    return false, 501
end

function r.loadResources(fname)
    local stat, res = pcall(function()
        local rs = binser.readFile(fname)
        rsrcs = rs
        return true
    end)
    if stat and res then
        DIR = {}
        return true, 200
    end
    return false, 501
end

function r.getResource(typ, id)
    initr(typ)
    local rs = rsrcs[typ] or {}
    if config.lcl then intercept(typ,id) end
    local res = id == nil and rs or rs[id]
    return res, res and 200 or 404
end

local CE, DE, ME = {}, {}, {}
function CE.globalVariables(d) return "GlobalVariableAddedEvent", { variableName = d.name, value = d.value } end

function CE.rooms(d) return "RoomCreatedEvent", { id = d.id } end

function CE.sections(d) return "SectionCreatedEvent", { id = d.id } end

function CE.devices(d) return "DeviceCreatedEvent", d end

function CE.customEvents(d) return "CustomEventCreatedEvent", d end

function DE.globalVariables(d) return "GlobalVariableRemovedEvent", { variableName = d.name, newValue = d.value } end

function DE.rooms(d) return "RoomRemovedEvent", { id = d.id } end

function DE.sections(d) return "SectionRemovedEvent", { id = d.id } end

function DE.devices(d) return "DeviceRemovedEvent", { id = d.id } end

function DE.customEvents(d) return "CustomEventRemovedEvent", { id = d.name } end

function ME.globalVariables(id, p, nv, ov)
    return "GlobalVariableChangedEvent",
        { variableName = id, newValue = nv, oldValue = ov }
end

function ME.rooms(id) return "RoomModifiedEvent", { id = id } end

function ME.sections(id) return "SectionModifiedEvent", { id = id } end

function ME.devices(id, p, nv, ov) return "DeviceModifiedEvent", { id = id, property = p, newValue = nv, oldValue = ov } end

function ME.weather(id, nv, ov)
    return "WeatherChangedEvent", { change = id, newValue = nv, oldValue = ov }
end

function ME.customEvents(id, nv, ov) return "CustomEventModifiedEvent", { id = id } end

local UA = { -- properties we can modify
    globalVariables = { name = true, value = true },
    rooms = { name = true },
    customEvents = { name = true, userDescription = true },
    sections = { name = true },
    devices = { name = true, roomID = true, sectionID = true, enabled = true, visible = true },
    weather = {
        Temperature = true,
        Humidity = true,
        ConditionCode = true,
        TemperatureUnit = true,
        WeatherCondition = true,
        WeatherConditionConverted = true,
        Wind = true,
        WindUnit = true
    }
}

local rsrcID = 8000

local function createResource_from_hc3(typ, id) -- incoming trigger from HC3
    initr(typ)
    local rs = rsrcs[typ] or {}
    if rs[id] and rs[id]._local then return end -- existing local, ignore
    rs[id] = api.get("/" .. typ .. "/" .. id, "hc3")
    return true
end

local function createResource_from_emu(typ, d)
    d = type(d) == 'string' and json.decode(d) or d
    initr(typ)
    local key = keys[typ]
    local rs = rsrcs[typ] or {}
    d._local = true
    local id = d[key] or r.nextRsrcId(); d[key] = id -- generate id
    if rs[id] then return nil, 409 end               -- already exsists
    rs[id] = d
    d.modified = os.time()
    d.created = d.modified
    if CE[typ] then postEvent(CE[typ](d)) end
    return d, 200
end

function r.createResource(typ, d, remote)
    if remote then
        return createResource_from_hc3(typ, d)
    else
        return createResource_from_emu(typ, d)
    end
end

local function deleteResource_from_hc3(typ, id)
    initr(typ)
    local rs = rsrcs[typ] or {}
    if rs[id] and rs[id]._local then return end
    rs[id] = nil
    return true
end

local function deleteResource_from_emu(typ, id)
    initr(typ)
    local rs = rsrcs[typ] or {}
    local d = rs[id]
    if d == nil then return nil, 404 end
    if not d._local then
        -- sync back to hc3
        api.delete("/" .. typ .. "/" .. id, "hc3")
        rs[id] = nil
        return d, 200
    end
    rs[id] = nil
    if DE[typ] then postEvent(DE[typ](d)) end
    return d, 200
end

function r.deleteResource(typ, id, remote)
    if remote then
        return deleteResource_from_hc3(typ, id)
    else
        return deleteResource_from_emu(typ, id)
    end
end

local function modifyResource_from_hc3(typ, id, nd)
    nd = type(nd) == 'string' and json.decode(nd) or nd
    initr(typ)
    local rs = rsrcs[typ] or {}
    if rs[id] and rs[id]._local then return true end -- local shadow, ignore
    rs[id] = api.get("/" .. typ .. "/" .. id, "hc3") or {}
    return true
end

local function modifyResource_from_emu(typ, id, nd)
    nd = type(nd) == 'string' and json.decode(nd) or nd
    initr(typ)
    local key = keys[typ]
    local rs = rsrcs[typ] or {}
    local ed, oldValues = key == nil and rs or rs[id], {}
    if key then rs[id] = nil end
    if ed == nil then return nil, 404 end
    local flag = false
    local props, newProps = {}, {}
    for k, v in pairs(nd) do
        if UA[typ][k] and ed[k] ~= v then
            newProps[k] = { newValue = v, oldValue = ed[k] }
            props[k] = v
            ed[k] = v
            flag = true
        end
    end
    if key then rs[ed[key]] = ed end
    if not flag then return ed, 200 end
    ed.modified = os.time()
    if not ed._local then -- sync back to HC3
        local r, c = api.put("/" .. typ .. "/" .. id, props, "hc3")
        return r, c
    end
    if ME[typ] then
        for p, vs in pairs(newProps) do postEvent(ME[typ](id, p, vs.newValue, vs.oldValue)) end
    end
    return ed, 200
end

function r.modifyResource(typ, id, nd, remote)
    if remote then
        return modifyResource_from_hc3(typ, id, nd)
    else
        return modifyResource_from_emu(typ, id, nd)
    end
end

function r.createDevice(d) return r.createResource("devices", d) end

function r.removeDevice(d) return r.deleteResource("devices", d) end

function r.updateDeviceProp(d, remote)
    local arg = type(d) == 'string' and json.decode(d) or d
    initr("devices")
    local id = arg.deviceId or arg.id
    if remote then
        r.refresh_resource("devices", nil, id)
        return true
    end
    local prop = arg.propertyName
    local newValue = arg.value
    --print("DDD1",json.encode(d),tostring(QA.DIR[id].dev.properties[prop]))
    if rsrcs.devices[id] == nil then return nil, 404 end
    local d = rsrcs.devices[id]
    if d.properties[prop] == newValue then return nil, 200 end
    local oldValue = d.properties[prop]
    if not d._local then
        -- sync back to hc3
        api.put("/devices/" .. id, { properties = { [prop] = newValue } }, "hc3")
        d.properties[prop] = newValue
        return nil, 200
    else
        --print("DDD2",json.encode(d),tostring(QA.DIR[id].dev.properties[prop]),tostring(newValue))
        if QA.DIR[id] then
            local dev = QA.DIR[id].dev
            QA.DIR[id].dev.properties[prop] = newValue
        end
    end
    d.properties[prop] = newValue
    if QA.hasZombie(id) then -- update zombie too...
        api.put("/devices/" .. QA.hasZombie(id), { properties = { [prop] = newValue } }, "hc3")
    end
    postEvent("DevicePropertyUpdatedEvent", { id = id, property = prop, newValue = newValue, oldValue = oldValue })
    return nil, 200
end

function r.emitCustomEvent(name)
    initr("customEvents")
    if rsrcs.customEvents[name] == nil then return {}, 404 end
    postEvent("CustomEvent", rsrcs.customEvents[name])
    return {}, 204
end

--------- QA keys -------------
rsrcs.keys = {}
function r.getQAKey(id, name)
    rsrcs.keys[id] = rsrcs.keys[id] or {}
    return name and rsrcs.keys[id][name] or rsrcs.keys[id], 200
end

function r.deleteQAKey(id, name)
    if rsrcs.keys[id] == nil then return end
    if name then rsrcs.keys[id][name] = nil else rsrcs.keys[id] = nil end
    return nil, 200
end

function r.createQAKey(id, name, value)
    rsrcs.keys[id] = rsrcs.keys[id] or {}
    if rsrcs.keys[id] ~= nil then return nil, 404 end
    rsrcs.keys[id][name] = value
    return value, 200
end

function r.setQAKey(id, name, value)
    rsrcs.keys[id] = rsrcs.keys[id] or {}
    if rsrcs.keys[id] == nil then return nil, 404 end
    rsrcs.keys[id][name] = value
    return value, 200
end

function r.flushQAKeys(id)
    if config.storage and rsrcs.keys[id] then 
        local f = io.open(config.storage, "w")
        if f then
            local store = { [tostring(id)] = rsrcs.keys[id] }
            f:write(json.encode(store))
            f:close()
        end
    end
    return true, 200
end
return r
