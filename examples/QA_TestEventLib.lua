--%%merge=examples/EventLib.lua,lib/Trigger.lua,examples/EventAndTriggerLib.lua;
--%%file=examples/EventAndTriggerLIb.lua,eventLib;
--%%file=examples/SpeedLib.lua,speedLib;

-- fibaro.speedTime(4)

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
  print("Timer2 every 5sec, aligned")
end

Event.sensorOff{type='device', id=88, property='value'}
function Event:sensorOff(event)
  if not self:trueFor(5,event.value==false) then return end
  self:debugf("Sensor %s trueFor %ds",event.id,5*self:again())
end

Event:post({type='device', id=88, property='value', value=false})

-- Event.a{type='t'}
-- function Event:a(event)
--   print(self.id,event)
-- end

-- Event.b{type='t'}
-- function Event:b(event)
--   print(self.id,event)
-- end

-- Event('c',{type='t'},function(self,event) print(self.id,event) end)

-- fibaro.debugFlags.post = true

-- Event.d{type='timer', time='+/00:00:05', aligned=true}
-- function Event:d(event)
--   print(self.id,event)
--   if self.date.sec > 30 then self:disable() self:timer('m/00',self.enable,self) end
-- end

-- Event.e{type='cron', time='* * * * *'}
-- function Event:e(event)
--   print(self.id,event)
-- end

-- Event.f{type='foo'}
-- function Event:f(event)
--   if not self:trueFor(5,event.ok=='ok') then return end
--   self:debugf("%s trueFor 5 %s",self.id,event)
--   self:debugf("Again %s",self:again())
-- end

-- fibaro.post({type='foo',ok='ok'})


-- fibaro.runTimers()
