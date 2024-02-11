--%%merge=examples/EventLib.lua,lib/Trigger.lua,examples/EventAndTriggerLib.lua;
--%%file=examples/EventLib.lua,Event;
--%%file=lib/Trigger.lua,Trigger;
--%%file=examples/SpeedLib.lua,speedLib;

-- fibaro.speedTime(4)
-- fibaro.debugFlags.post = true

local Event = Event_basic

Event.start{type='QAstart'}
function Event:start(event)
  Event:attachRefreshstate()
end

-- Defining an event handler
Event.id1{type='device', id={20,30}, value=true}
--Event.id1{type='device', id=30, value=true}
function Event:id1(event)
  print("Device ",event.id," turned true")
end

Event:post({type='device', id=20, value=true})
Event:post({type='device', id=30, value=true})

Event.id2{type='device', id=46, property='centralSceneEvent', value={keyId='$key', keyAttribute='$attr'}}
function Event:id2(event,vars)
  print("Key",vars.key,"Atttribute",vars.attr)
end

Event.cronTest{type='cron', time='* * * * *'}
function Event:cronTest(event)
  print("Cron, every minute")
end

Event.timerTest1{type='timer', time='+/00:00:05'}
function Event:timerTest1(event)
  print("Timer1 every 5sec, unaligned")
end

Event.timerTest2{type='timer', time='+/00:00:05', aligned=true}
function Event:timerTest2(event)
  self:debugf("Timer2 every 5sec, aligned")
end

Event.sensorOff{type='device', id=88, property='value'}
function Event:sensorOff(event)
  if not self:trueFor(5,event.value==false) then return end
  self:debugf("Sensor %s trueFor %ds",event.id,5*self:again())
end
Event:post({type='device', id=88, property='value', value=false})

Event.ex3{type='device', id=88, property='value'}
function Event:ex3(event)
  -- self:debugf(fmt,...)
  -- self:tracef(fmt,...)
  -- self:warningf(fmt,...)
  -- self:errorf(fmt,...)
  -- self:post(event[,time])
  -- self:cancel(timer)
  -- self:enable(evh)
  -- self:disable(evh)
  -- self:timer(timme,fun,...)
  -- self:trueFor(time,fun)
  -- self:again([n])
  -- return self.BREAK
  end

-- Alternative way to define event handlers
-- Event('c',{type='t'},function(self,event) print(self.id,event) end)
-- Event:post({type='t', value=1})

-- fibaro.runTimers()

-- "Anonymous" event handlers. Will be assigned an id of type "event:"..n
Event._{type='e1'}
function Event:_(event)
  print("Event",self.id)
end

Event._{type='e1'}
function Event:_(event)
  print("Event",self.id)
end

Event._{type='e1'}
function Event:_(event)
  print("Event",self.id)
end

Event:post({type='e1'})
