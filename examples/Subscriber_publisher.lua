--%%name=Publisher

--%%file=lib/OS.lua,os;
--%%file=lib/Trigger.lua,trigger;
--%%file=lib/Event.lua,event;


local Event

function QuickApp:startRefresh()
  function fibaro._APP.trigger.post(ev)
    fibaro._APP.event.addEventMT(ev)
    fibaro.post(ev)
  end
  fibaro._APP.trigger.start()
end

function QuickApp:onInit()
  Event = fibaro._APP.event.Event
  fibaro._APP.event.enableBroadcast()
  local broadcast = fibaro._APP.event.broadcast
  self:startRefresh()
  
  Event.test{type='myTest'}
  function Event:test(event)
    print("XX",json.encode(event))
  end

  self:startRefresh()
end
