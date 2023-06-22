local fmt = string.format
local r,config = {},nil
local resources

local propFilter = {
    icon = true
}

local EventTypes = { -- There are more, but these are what I seen so far...
    AlarmPartitionArmedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    AlarmPartitionBreachedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    HomeArmStateChangedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    HomeDisarmStateChangedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    HomeBreachedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    WeatherChangedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    GlobalVariableChangedEvent = {
        f = function(d,e) resources.updateGlobalVariable(d.variableName, {name=d.variableName,value=d.value},true) end,
        l = function(d,e) return fmt("%s '%s' = '%s', old:'%s'",e.type,d.variableName,d.value,tostring(d.oldValue)) end
    },
    GlobalVariableAddedEvent = {
        f = function(d,e) resources.createGlobalVariable({name=d.variableName,value=d.value},true) end,
        l = function(d,e) return fmt("%s '%s' = '%s'",e.type,d.variableName,d.value) end
    },
    GlobalVariableRemovedEvent = {
        f = function(d,e) resources.removeGlobalVariable(d.variableName,true) end,
        l = function(d,e) return fmt("%s '%s'",e.type,d.variableName) end
    },

    CentralSceneEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s Key:%s Attr:%s",e.type,d.id,d.keyId,d.keyAttribute) end
    },
    SceneActivationEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s SID:%s",e.type,tostring(d.id),d.sceneId) end
    },
    AccessControlEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,tostring(d.id)) end
    },
    CustomEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s '%s'",e.type,d.name) end
    },
    PluginChangedViewEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    WizardStepStateChangedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    UpdateReadyEvent = {
        f=function(de,s) end,
        l=function(d,e) return fmt("%s",e.type) end
    },

    DevicePropertyUpdatedEvent = {
        f = function(d,e) 
            resources.updateDeviceProp({deviceId=d.id,propertyName=d.property, value=d.newValue},true) 
        end,
        l = function(d,e)
            if propFilter[d.property] then return end
            return fmt("%s ID:%s prop:'%s' val:%s",e.type,d.id,d.property,json.encode(d.newValue))
        end
    },
    DeviceRemovedEvent = {
        f = function(d,e) resources.removeDevice(d.id,true) end,
        l = function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    DeviceChangedRoomEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    DeviceCreatedEvent = {
        f = function(d,e) resources.createDevice(d, true) end,
        l = function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    DeviceModifiedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    PluginProcessCrashedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },

    SceneStartedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SceneFinishedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SceneRunningInstancesEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SceneRemovedEvent = {
        f = function(d,e) resources.removeScene(d.id, true) end,
        l = function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SceneModifiedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SceneCreatedEvent = {
        f = function(d,e) resources.createScene(d, true) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },

    OnlineStatusUpdatedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    ActiveProfileChangedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    ClimateZoneChangedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    ClimateZoneSetpointChangedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },

    NotificationCreatedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    NotificationRemovedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    NotificationUpdatedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },

    RoomCreatedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    RoomRemovedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    RoomModifiedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },

    CustomEventCreatedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.name) end
    },
    CustomEventRemovedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.name) end
    },
    CustomEventModifiedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.name) end
    },

    SectionCreatedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SectionRemovedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },
    SectionModifiedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s ID:%s",e.type,d.id) end
    },

    QuickAppFilesChangedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },

    ZwaveDeviceParametersChangedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    ZwaveNodeAddedEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    RefreshRequiredEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    DeviceFirmwareUpdateEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    GeofenceEvent = {
        f=function(d,e) end,
        l=function(d,e) return fmt("%s",e.type) end
    },
    DeviceActionRanEvent = {
        f=function(d,e) end,
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
        if not event._emu then h.f(event.data, event) end -- emulator events are already handled
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
