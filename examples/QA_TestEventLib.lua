--%%merge=examples/EventLib.lua,lib/Trigger.lua,examples/EventAndTriggerLib.lua;
--%%file=examples/EventLib.lua,Event;
--%%file=lib/Trigger.lua,Trigger;
--%%file=examples/SpeedLib.lua,speedLib;

-- fibaro.speedTime(4)
-- fibaro.debugFlags.post = true

local Event = Event_std

Event.id='start'
Event{type='QAstart'}
function Event:handler(event)
  Event:attachRefreshstate()
end

-- Defining an event handler
Event.id='id1'
Event{type='device', id={20,30}, value=true}
--Event{type='device', id=30, value=true}
function Event:handler(event)
  print("Device ",event.id," turned true")
end

Event:post({type='device', id=20, value=true})
Event:post({type='device', id=30, value=true})

Event.id='id2'
Event{type='device', id=46, property='centralSceneEvent', value={keyId='$key', keyAttribute='$attr'}}
function Event:handler(event,vars)
  self:debug("Key",vars.key,"Atttribute",vars.attr)
end

Event.id='cronTest'
Event{type='cron', time='* * * * *'}
function Event:handler(event)
  self:debug("Cron, every minute")
end

Event.id='timerTest1'
Event{type='timer', time='+/00:00:05'}
function Event:handler(event)
  self:debug("Timer1 every 5sec, unaligned")
end

Event.id='timerTest2'
Event{type='timer', time='+/00:00:05', aligned=true}
function Event:handler(event)
  self:debug("Timer2 every 5sec, aligned")
end

Event.id='sensorOff'
Event{type='device', id=88, property='value'}
function Event:handler(event)
  if not self:trueFor(5,event.value==false) then return end
  self:debugf("Sensor %s trueFor %ds",event.id,5*self:again())
end
Event:post({type='device', id=88, property='value', value=false})

Event.id='ex3'
Event{type='device', id=88, property='value'}
function Event:handler(event)
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
Event.id='_'
Event{type='e1'}
function Event:handler(event)
  print("Event",self.id)
end

Event.id='_'
Event{type='e1'}
function Event:handler(event)
  print("Event",self.id)
end

Event.id='_'
Event{type='e1'}
function Event:handler(event)
  print("Event",self.id)
end

Event:post({type='e1'})

----------------------------

Event_std.id='sensorOff4'
Event_std{type='device', id=100, property='value', value=false}
Event_std.debug=true
function Event_std:handler(event)
  self:debug("Sensor",event.id,"off")
end

Event:post({type='device', id=100, property='value', value=false})

Event_std.id='cancelTest'
Event_std{type='tc'}
function Event_std:handler(event)
  self:post({type='tc2'},5)
  self:post({type='tc2'},7)
  self:post({type='tc2'},8)
end

Event_std.id='cancelTest2'
Event_std{type='tc2'}
function Event_std:handler(event)
  self:debug("TEST2")
  Event_std:cancelAll('cancelTest')
end

Event_std:post({type='tc'})

function fibaro.call_(id,fun,...)
  print("fibaro.call",id,fun,...)
end

Event_std.id='lightWithSensor'
Event_std.tagColor='red'
Event_std{type='device', id=100, property='value', value='$value'}
function Event_std:handler(event,vars)
  if vars.value then -- sensor breached
    if self:cancelAll() then self:debug("reset timer") end -- cancelAll returns true of any timer is cancelled
  	self:debug("Light on")
    fibaro.call_(101,'turnOn')
  else               -- sensor safe
    self:timer('+/00:00:10',fibaro.call_,101,'turnOff')
  end
end

Event_std:post({type='device', id=100, property='value', value=true})               -- fake sensor on
Event_std:post({type='device', id=100, property='value', value=false},'+/00:00:05') -- fake sensor off
Event_std:post({type='device', id=100, property='value', value=true},'+/00:00:09')  -- fake sensor on
Event_std:post({type='device', id=100, property='value', value=false},'+/00:00:12') -- fake sensor off

local days = {"Sunday","Monday","Tuesday","Wednesday","Tursday","friday","Saturday"}
Event.id="between"
Event{type='device', id=99, value=true}
function Event:handler(event)
  if self:between('17:00','sunset+00:30') then
    self:debug("Sensor breached between 17 and aunset+30min")
  else
    self:debug("Sensor breached outside 17 to sunset+30min")
  end
  self:debug("Btw, it's",days[self.date.wday],"today")
end

Event:post({type='device',id=99,value=true}) -- test

Event.id='_'
Event{type='double'}
function Event:handler(ev)
  print("Double",self.id)
  return self.BREAK -- Next matching handler will be skipped
end

Event.id='_'
Event{type='double'}
function Event:handler(ev)
  print("Double",self.id)
end

Event:post({type='double'})