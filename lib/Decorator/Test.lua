
--%%name='Test decorators'
--%%debug=refresh:false
--%%file=lib/Decorator/Decorator.lua,Decorator;
--%%file=lib/Decorator/Dec_Log.lua,DLog;
--%%file=lib/Decorator/Dec_Private.lua,DPrivate;
--%%file=lib/Decorator/Dec_Event.lua,DEvent;

T = {foo = 42}
--@Event:type='device',id=T.foo,value=*
--@Log:level=INFO
function QuickApp:device(id,value)
end

--@Event:type='scene',id=T.foo,value=*
--@Log:level=INFO
--@Private
function QuickApp:scene(type)
  print("MyScene")
end

--@Log:level=INFO
--@Event:type='test',id=T.foo,value=*
function test(a,b)
  print(a+b)
end

--@Log:level=INFO
--@Event:type='test2',id=T.foo,value=$>4
function test2(_event)
  print("Triggered",json.encode(_event))
end

--fibaro.DECORATE_DEBUG=true
function QuickApp:onInit()
  print("onInit")
  self:post({type='test2',id=42,value=5})
end