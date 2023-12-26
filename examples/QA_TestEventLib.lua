--%%file=examples/EventLib.lua,eventLib;
--%%file=examples/SpeedLib.lua,speedLib;

-- fibaro.speedTime(4)

-- Event.a{type='t'}
-- function Event:a(event)
--   print(self.id,event)
-- end

-- Event.b{type='t'}
-- function Event:b(event)
--   print(self.id,event)
-- end

-- Event('c',{type='t'},function(self,event) print(self.id,event) end)

fibaro.debugFlags.post = true

Event.d{type='timer', time='+/00:00:05', aligned=true}
function Event:d(event)
  print(self.id,event)
  if self.date.sec > 30 then self:disable() self:timer('m/00',self.enable,self) end
end

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

local E = setmetatable({},{
  __index=function(t,k) return function(_,args) args.type=k return args end end})

Event.h(E:foo{time='t'})
function Event:h(event)
  print(self.id,event)
end

fibaro.post(E:foo{time='t'})