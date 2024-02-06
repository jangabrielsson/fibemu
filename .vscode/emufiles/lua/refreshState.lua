local fmt = string.format
local r,config,emu = {},nil,nil
local resources

local propFilter = {
    icon = true
}

local EventTypes = { -- There are more, but these are what I seen so far...
    AlarmPartitionArmedEvent = {
        f=function(d,e) return resources.modifyResource(
            "alarms/v1/partitions",
            d.partitionId,
            nil,
            true) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    AlarmPartitionBreachedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    HomeArmStateChangedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    HomeDisarmStateChangedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    HomeBreachedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    WeatherChangedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s %s %s",e.type,d.change,d.newValue) end
    },
    GlobalVariableChangedEvent = {
        f = function(d,e) 
            if d.variableName == QA.FIBEMUVAR then return end
            return resources.modifyResource(
            "globalVariables",
            d.variableName,
            nil,
            true)
        end,
        l = function(d,e) return fmt("%s '%s' = '%s', old:'%s'",e.type,d.variableName,d.newValue,tostring(d.oldValue)) end
    },
    GlobalVariableAddedEvent = {
        f = function(d,e) return resources.createResource(
            "globalVariables",
            d.variableName,
            true)
        end,
        l = function(d,e) return fmt("%s '%s' = '%s'",e.type,d.variableName,d.value) end
    },
    GlobalVariableRemovedEvent = {
        f = function(d,e) return resources.deleteResource(
            "globalVariables",
            d.variableName,
            true)
        end,
        l = function(d,e) return fmt("%s '%s'",e.type,d.variableName) end
    },

    CentralSceneEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s ID:%s Key:%s Attr:%s",e.type,d.id,d.keyId,d.keyAttribute) end
    },
    SceneActivationEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s ID:%s SID:%s",e.type,tostring(d.id),d.sceneId) end
    },
    AccessControlEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s ID:%s",e.type,tostring(d.id)) end
    },
    CustomEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s '%s'",e.type,d.name,d.userDescription) end
    },
    PluginChangedViewEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s %s %s",e.type,d.deviceId,d.propertyName,d.newValue) end
    },
    WizardStepStateChangedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    UpdateReadyEvent = {
        f=function(de,s) return true end,
        l=function(d,e) return fmt("%s isReady:%s",e.type,d.isReady) end
    },

    DevicePropertyUpdatedEvent = {
        f = function(d,e) 
            return resources.updateDeviceProp(
                {deviceId=d.id,propertyName=d.property, value=d.newValue},
                true)
        end,
        l = function(d,e)
            if propFilter[d.property] then return end
            return fmt("%s ID:%s prop:'%s' val:%s",e.type,d.id,d.property,json.encode(d.newValue))
        end
    },
    DeviceRemovedEvent = {
        f = function(d,e) return resources.deleteResource("devices",d.id,true) end,
        l = function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    DeviceChangedRoomEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    DeviceCreatedEvent = {
        f = function(d,e) return resources.createResource(
            "devices", 
            d.id or d.deviceId,
            true) 
        end,
        l = function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    DeviceModifiedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    PluginProcessCrashedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s ID:%s %s",e.type,d.id or d.deviceId,d.error or "") end
    },

    SceneStartedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SceneFinishedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SceneRunningInstancesEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SceneRemovedEvent = {
        f = function(d,e) return resources.deleteResource("scenes", d.id, true) end,
        l = function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SceneModifiedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s ID:%s",e.type, d.id) end
    },
    SceneCreatedEvent = {
        f = function(d,e) return resources.createResource("scenes", d.id, true) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },

    OnlineStatusUpdatedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    ActiveProfileChangedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    ClimateZoneChangedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    ClimateZoneSetpointChangedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    ClimateZoneTemperatureChangedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    NotificationCreatedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    NotificationRemovedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    NotificationUpdatedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },

    RoomCreatedEvent = {
        f=function(d,e) return resources.createResource(
            "rooms", 
            d.id,
            true) 
        end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    RoomRemovedEvent = {
        f=function(d,e) return resources.deleteResource("rooms",d.id,true) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    RoomModifiedEvent = {
        f=function(d,e) return resources.modifyResource(
            "rooms",
            d.id,
            d,
            true)
        end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },

    CustomEventCreatedEvent = {
        f=function(d,e) return resources.createResource(
            "customEvents", 
            d.name,
            true)
        end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.name) end
    },
    CustomEventRemovedEvent = {
        f=function(d,e) return resources.deleteResource("customEvents",d.name,true) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.name) end
    },
    CustomEventModifiedEvent = {
        f=function(d,e) return resources.modifyResource(
            "customEvents",
            d.name,
            d,
            true)
        end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.name) end
    },

    SectionCreatedEvent = {
        f=function(d,e) return resources.createResource(
            "sections",
            d.id,
            true)
        end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SectionRemovedEvent = {
        f=function(d,e) return resources.deleteResource(
            "sections",
            d.id,
            true)
        end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SectionModifiedEvent = {
        f=function(d,e) return resources.modifyResource(
            "sections",
            d.id,
            d,
            true)
        end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },

    QuickAppFilesChangedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },

    ZwaveDeviceParametersChangedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    ZwaveNodeAddedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    ZwaveNodeWokeUpEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    ZwaveNodeWentToSleepEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    RefreshRequiredEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    DeviceFirmwareUpdateEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    GeofenceEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    DeviceActionRanEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s ID:%s %s",e.type,d.id,d.actionName) end
    },

    PowerMetricsChangedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s consumptionPower:%s productionPower:%s",e.type,d.consumptionPower,d.productionPower) end
    },
    DeviceNotificationState = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    DeviceInterfacesUpdatedEvent = {
        f=function(d,e) return true end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
}

function r.init(conf, libs)
    config = conf
    emu = libs.emu
    resources = libs.resources
end

function r.logEvent(event)
    local h = EventTypes[event.type]
    if QA.triggerHook then QA.triggerHook(event) end
    if h and h.l and emu.debug.refresh then
        local m = h.l(event.data, event)
        if m then QA.syslog("refresh",m) end
    end
end

function r.newEvent(event)
    local h = EventTypes[event.type]
    if h then
        if h.f(event.data, event) then
            QA.addEvent(json.encode(event)) -- emulator events are handled elsewhere
            r.logEvent(event)
        end
    else
        print("Unknown event type: ", json.encode(event))
    end
end

function r.start()
    local url = fmt("http://%s:%s/api/refreshStates?lang=en&rand=0.09580020181569104&logs=false&last=", config.host,
        config.port)
    local options = {
        headers = {
            ['Authorization'] = config.creds,
            ["Accept"] = '*/*',
            ["X-Fibaro-Version"] = "2",
            ["Fibaro-User-PIN"] = config.pin,
            ["Content-Type"] = "application/json",
        }
    }
    QA.pyhooks.refreshStates(true, url, options) -- Python function 
end

function r.hc3HookVar()
    api.post("/globalVariables", {name=QA.FIBEMUVAR,value=tostring(os.time())}, "hc3")
    local data = {url=string.format("http://%s:%s",config.hostIP,config.wport)}
    local function loop()
        data.time=os.orgtime()
        api.put("/globalVariables/"..QA.FIBEMUVAR, {name=QA.FIBEMUVAR, value=(json.encode(data))}, "hc3")
        QA.systemTimer(loop, 3000,'hc3hook')
    end
    loop()
end

r.eventTypes = EventTypes

return r
