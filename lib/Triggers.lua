local _GLOBAL = false

local function quickVarEvent(d,_,post)
  local old={}; for _,v in ipairs(d.oldValue) do old[v.name] = v.value end
  for _,v in ipairs(d.newValue) do
    if not equal(v.value,old[v.name]) then
      post({type='quickvar', id=d.id, name=v.name, value=v.value, old=old[v.name]})
    end
  end
end

-- There are more, but these are what I seen so far...
--[[
{type='alarm', property='armed', id = <partitionId>, value=<boolean>}
{type='alarm', property='breached', id = <partitionId>, value=<boolean>}
{type='alarm', property='homeArmed', value=<boolean>
{type='alarm', property='homeBreached', value=<boolean>
{type='weather',property=<string>, value=<number>, old=<number>}
{type='global-variable', name=<string>, value=<string>, old=<string>}
{type='quickvar', id=<number>, name=<string>, value=<value>, old=<value>}
{type='device', id=<number>, property=<string>, value=<value>, old=<value>}
{type='device', id=<number>, property='centralSceneEvent', value={keyId=<number>, keyAttribute=<number>}}
{type='device', id=<number>, property='sceneActivationEvent', value={sceneId=<number>}}
{type='device', id=<number>, property='accessControlEvent', value=<table>}
{type='custom-event', name=<string>, value=<string>}
{type='deviceEvent', id=<number>, value='removed'}
{type='deviceEvent', id=<number>, value='changedRoom'}
{type='deviceEvent', id=<number>, value='created'}
{type='deviceEvent', id=<number>, value='modified'}
{type='deviceEvent', id=<number>, value='crashed', error=<string>}
{type='sceneEvent', id=<number>, value='started'}
{type='sceneEvent', id=<number>, value='finished'}
{type='sceneEvent', id=<number>, value='instance', instance=<value>}
{type='sceneEvent', id=<number>, value='removed'}
{type='sceneEvent', id=<number>, value='modified'}
{type='sceneEvent', id=<number>, value='created'}
{type='onlineEvent', value=<boolean>}
{type='profile',property='activeProfile',value=<string>, old=<string>}
{type='ClimateZone', id=<number>, type=<string>, value=<string>, old=<string>}
{type='ClimateZoneSetpoint', id=<number>, type=<string>, value=<number>, old=<number>}
{type='notification', id=<number>, value='created'}
{type='notification', id=<number>, value='removed'}
{type='notification', id=<number>, value='updated'}
{type='room', id=<number>, value='created'}
{type='room', id=<number>, value='removed'}
{type='room', id=<number>, value='modified'}
{type='section', id=<number>, value='created'}
{type='section', id=<number>, value='removed'}
{type='section', id=<number>, value='modified'}
{type='location',id=<number>,property=<string>,value=<string>,timestamp=<number>}
{type='user',id=<number>,value='action',data=<value>}
{type='system',value='action',data=<value>}
--]]
local EventTypes = {
  AlarmPartitionArmedEvent = function(d,_,post) post({type='alarm', property='armed', id = d.partitionId, value=d.armed}) end,
  AlarmPartitionBreachedEvent = function(d,_,post) post({type='alarm', property='breached', id = d.partitionId, value=d.breached}) end,
  AlarmPartitionModifiedEvent = function(d,_,post)  end,
  HomeArmStateChangedEvent = function(d,_,post) post({type='alarm', property='homeArmed', value=d.newValue}) end,
  HomeDisarmStateChangedEvent = function(d,_,post) post({type='alarm', property='homeArmed', value=not d.newValue}) end,
  HomeBreachedEvent = function(d,_,post) post({type='alarm', property='homeBreached', value=d.breached}) end,
  WeatherChangedEvent = function(d,_,post) post({type='weather',property=d.change, value=d.newValue, old=d.oldValue}) end,
  GlobalVariableChangedEvent = function(d,_,post)
    if d.variableName == GlobalSourceTriggerGV then
      if _GLOBAL then
        local stat,va = pcall(json.decode,d.newValue)
        if not stat then return end
        va._transID = nil
        post(va)
      end
    else
      post({type='global-variable', name=d.variableName, value=d.newValue, old=d.oldValue})
    end
  end,
  GlobalVariableAddedEvent = function(d,_,post) post({type='global-variable', name=d.variableName, value=d.value, old=nil}) end,
  DevicePropertyUpdatedEvent = function(d,_,post)
    if d.property=='quickAppVariables' then quickVarEvent(d,_,post)
    else
      post({type='device', id=d.id, property=d.property, value=d.newValue, old=d.oldValue})
    end
  end,
  CentralSceneEvent = function(d,_,post)
    d.id,d.icon = d.id or d.deviceId,nil
    post({type='device', property='centralSceneEvent', id=d.id, value={keyId=d.keyId, keyAttribute=d.keyAttribute}})
  end,
  SceneActivationEvent = function(d,_,post)
    d.id = d.id or d.deviceId
    post({type='device', property='sceneActivationEvent', id=d.id, value={sceneId=d.sceneId}})
  end,
  AccessControlEvent = function(d,_,post)
    post({type='device', property='accessControlEvent', id=d.id, value=d})
  end,
  CustomEvent = function(d,_,post)
    local value = api.get("/customEvents/"..d.name)
    post({type='custom-event', name=d.name, value=value and value.userDescription})
  end,
  PluginChangedViewEvent = function(d,_,post) post({type='PluginChangedViewEvent', value=d}) end,
  WizardStepStateChangedEvent = function(d,_,post) post({type='WizardStepStateChangedEvent', value=d})  end,
  UpdateReadyEvent = function(d,_,post) post({type='updateReadyEvent', value=d}) end,
  DeviceRemovedEvent = function(d,_,post)  post({type='deviceEvent', id=d.id, value='removed'}) end,
  DeviceChangedRoomEvent = function(d,_,post)  post({type='deviceEvent', id=d.id, value='changedRoom'}) end,
  DeviceCreatedEvent = function(d,_,post)  post({type='deviceEvent', id=d.id, value='created'}) end,
  DeviceModifiedEvent = function(d,_,post) post({type='deviceEvent', id=d.id, value='modified'}) end,
  PluginProcessCrashedEvent = function(d,_,post) post({type='deviceEvent', id=d.deviceId, value='crashed', error=d.error}) end,
  SceneStartedEvent = function(d,_,post)   post({type='sceneEvent', id=d.id, value='started'}) end,
  SceneFinishedEvent = function(d,_,post)  post({type='sceneEvent', id=d.id, value='finished'})end,
  SceneRunningInstancesEvent = function(d,_,post) post({type='sceneEvent', id=d.id, value='instance', instance=d}) end,
  SceneRemovedEvent = function(d,_,post)  post({type='sceneEvent', id=d.id, value='removed'}) end,
  SceneModifiedEvent = function(d,_,post)  post({type='sceneEvent', id=d.id, value='modified'}) end,
  SceneCreatedEvent = function(d,_,post)  post({type='sceneEvent', id=d.id, value='created'}) end,
  OnlineStatusUpdatedEvent = function(d,_,post) post({type='onlineEvent', value=d.online}) end,
  ActiveProfileChangedEvent = function(d,_,post)
    post({type='profile',property='activeProfile',value=d.newActiveProfile, old=d.oldActiveProfile})
  end,
  ClimateZoneChangedEvent = function(d,_,post) --ClimateZoneChangedEvent
    if d.changes and type(d.changes)=='table' then
      for _,c in ipairs(d.changes) do
        c.type,c.id='ClimateZone',d.id
        post(c)
      end
    end
  end,
  ClimateZoneSetpointChangedEvent = function(d,_,post) d.type = 'ClimateZoneSetpoint' post(d,_,post) end,
  NotificationCreatedEvent = function(d,_,post) post({type='notification', id=d.id, value='created'}) end,
  NotificationRemovedEvent = function(d,_,post) post({type='notification', id=d.id, value='removed'}) end,
  NotificationUpdatedEvent = function(d,_,post) post({type='notification', id=d.id, value='updated'}) end,
  RoomCreatedEvent = function(d,_,post) post({type='room', id=d.id, value='created'}) end,
  RoomRemovedEvent = function(d,_,post) post({type='room', id=d.id, value='removed'}) end,
  RoomModifiedEvent = function(d,_,post) post({type='room', id=d.id, value='modified'}) end,
  SectionCreatedEvent = function(d,_,post) post({type='section', id=d.id, value='created'}) end,
  SectionRemovedEvent = function(d,_,post) post({type='section', id=d.id, value='removed'}) end,
  SectionModifiedEvent = function(d,_,post) post({type='section', id=d.id, value='modified'}) end,
  QuickAppFilesChangedEvent = function(_) end,
  ZwaveDeviceParametersChangedEvent = function(_) end,
  ZwaveNodeAddedEvent = function(_) end,
  RefreshRequiredEvent = function(_) end,
  DeviceFirmwareUpdateEvent = function(_) end,
  GeofenceEvent = function(d,_,post) post({type='location',id=d.userId,property=d.locationId,value=d.geofenceAction,timestamp=d.timestamp}) end,
  DeviceActionRanEvent = function(d,e,post)
    if e.sourceType=='user' then
      post({type='user',id=e.sourceId,value='action',data=d})
    elseif e.sourceType=='system' then
      post({type='system',value='action',data=d})
    end
  end,
}