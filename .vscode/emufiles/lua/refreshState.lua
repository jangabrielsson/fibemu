local fmt = string.format
local r,config = {},nil
local resources

local propFilter = {
    icon = true
}

local EventTypes = { -- There are more, but these are what I seen so far...
    AlarmPartitionArmedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    AlarmPartitionBreachedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    HomeArmStateChangedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    HomeDisarmStateChangedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    HomeBreachedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    WeatherChangedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    GlobalVariableChangedEvent = {
        f = function(d,s) resources.updateGlobalVariable(d.variableName, {name=d.variableName,value=d.value},s) end,
        l = function(d,e) return fmt("%s '%s' = '%s', old:'%s'",e.type,d.variableName,d.value,tostring(d.oldValue)) end
    },
    GlobalVariableAddedEvent = {
        f = function(d,s) resources.createGlobalVariable({name=d.variableName,value=d.value},s) end,
        l = function(d,e) return fmt("%s '%s' = '%s'",e.type,d.variableName,d.value) end
    },
    GlobalVariableRemovedEvent = {
        f = function(d,s) resources.removeGlobalVariable(d.variableName,true) end,
        l = function(d,e) return fmt("%s '%s'",e.type,d.variableName) end
    },

    CentralSceneEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s ID:%s Key:%s Attr:%s",e.type,d.id,d.keyId,d.keyAttribute) end
    },
    SceneActivationEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s ID:%s SID:%s",e.type,tostring(d.id),d.sceneId) end
    },
    AccessControlEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,tostring(d.id)) end
    },
    CustomEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s '%s'",e.type,d.name) end
    },
    PluginChangedViewEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    WizardStepStateChangedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    UpdateReadyEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },

    DevicePropertyUpdatedEvent = {
        f = function(d,s) resources.updateDeviceProp({deviceId=d.id,propertyName=d.property, value=d.newValue},s) end,
        l = function(d,e)
            if propFilter[d.property] then return end
            return fmt("%s ID:%s prop:%s val:%s",e.type,d.id,d.property,json.encode(d.newValue))
        end
    },
    DeviceRemovedEvent = {
        f = function(d,s) resources.removeDevice(d.id,s) end,
        l = function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    DeviceChangedRoomEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    DeviceCreatedEvent = {
        f = function(d,s) resources.createDevice(d, s) end,
        l = function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    DeviceModifiedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    PluginProcessCrashedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },

    SceneStartedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SceneFinishedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SceneRunningInstancesEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SceneRemovedEvent = {
        f = function(d,s) resources.removeScene(d.id) end,
        l = function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SceneModifiedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SceneCreatedEvent = {
        f = function(d,s) resources.createScene(d, s) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },

    OnlineStatusUpdatedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    ActiveProfileChangedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    ClimateZoneChangedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    ClimateZoneSetpointChangedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },

    NotificationCreatedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    NotificationRemovedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    NotificationUpdatedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },

    RoomCreatedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    RoomRemovedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    RoomModifiedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },

    SectionCreatedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    SectionRemovedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    SectionModifiedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },

    QuickAppFilesChangedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },

    ZwaveDeviceParametersChangedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    ZwaveNodeAddedEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    RefreshRequiredEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    DeviceFirmwareUpdateEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    GeofenceEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    DeviceActionRanEvent = {
        f=function(d,s) end,
        l=function(d,e) return fmt("%s ID:%s %s",e.type,d.id,d.actionName) end
    },
}

function r.init(conf, libs)
    config = conf
    resources = libs.resources
end

function r.newEvent(event)
    local h,m = EventTypes[event.type],nil
    if h then
        h.f(event.data, event, not event._emu)
        if h.l then
            m=h.l(event.data, event)
            if m then QA.syslog("REFRESH",m) end
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
    os.refreshStates(true, url, options)
end

return r
