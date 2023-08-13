--%%name=CentralSceneEvent test
--%%type=com.fibaro.genericDevice
--%%file=examples/fibaroExtra.lua,fibaroExtra;

function fibaro.postCentralSceneEvent(keyId,keyAttribute)
    local data = {
      type =  "centralSceneEvent",
      source = plugin.mainDeviceId,
      data = { keyAttribute = keyAttribute, keyId = keyId }
    }
    return api.post("/plugins/publishEvent", data)
  end

function QuickApp:onInit()
    quickApp=self
    fibaro.debugFlags._allRefreshStates=true
    fibaro.event({type="device",property='centralSceneEvent'},function(env)
        local ev = env.event
        self:debugf("CentralSceneEvent: %s %s",ev.value.keyId,ev.value.keyAttribute)
    end)
    setTimeout(function() fibaro.postCentralSceneEvent(2,"Pressed") end,2000)
end

