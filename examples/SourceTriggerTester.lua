--%%file=examples/SourceTriggerSubscriber.lua,st;

function QuickApp:onInit()
  local st = SourceTriggerSubscriber()
  st:run()

  local stp = st.post
  function st:post(event,time,...)
    if time then print(os.date("POST %X",fibaro.toTime(time))) end
    return stp(st,event,time,...)
  end

  st:subscribe({type='runAt'},
      function(event)
        event.ref[1] = nil
        if event.action(event.env) == 'BREAK' then return end
        if event.interval then 
          event.ref[1] = st:post(event,event.interval) 
        end
      end)

  local function runAt(args)
      local ref = {}
      local time = args.time
      local fun = args.fun
      local interval = args.interval
      local catch = args.catch
      local env = args.env or {}
      interval = interval==true and time or interval or nil
      ref[1] = st:post({type='runAt', action = fun, interval = interval, ref=ref, env=env},time)
      if catch and fibaro.toTime(time) < os.time() then
        fun(env)
      end
      return ref
    end

  local function stopAt(ref)
      if type(ref)=='table' and ref[1] then st:cancel(ref[1]) end
    end

  runAt{
    time="n/13:42",
    interval=true,
    fun=function(event)
      local r = runAt{time="h/15:00",interval=true,fun=function(event) print("15") end}
      runAt{time="t/17:00",function() stopAt(r) end, catch=true}  
    end,
  catch=true}

end