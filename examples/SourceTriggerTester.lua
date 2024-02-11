--%%file=examples/SourceTriggerSubscriber.lua,st;

-- function QuickApp:onInit()
--   local st = SourceTriggerSubscriber()
--   st:run()

--   local stp = st.post
--   function st:post(event,time,...)
--     if time then print(os.date("POST %X",fibaro.toTime(time))) end
--     return stp(st,event,time,...)
--   end

--   st:subscribe({type='weather'},
--       function(event)
--         print(json.encode(event))
--       end)

--   local function runAt(args)
--       local ref = {}
--       local time = args.time
--       local fun = args.fun
--       local interval = args.interval
--       local catch = args.catch
--       local env = args.env or {}
--       interval = interval==true and time or interval or nil
--       ref[1] = st:post({type='runAt', action = fun, interval = interval, ref=ref, env=env},time)
--       if catch and fibaro.toTime(time) < os.time() then
--         fun(env)
--       end
--       return ref
--     end

--   local function stopAt(ref)
--       if type(ref)=='table' and ref[1] then st:cancel(ref[1]) end
--     end

--   runAt{
--     time="n/13:42",
--     interval=true,
--     fun=function(event)
--       local r = runAt{time="h/15:00",interval=true,fun=function(event) print("15") end}
--       runAt{time="t/17:00",function() stopAt(r) end, catch=true}  
--     end,
--   catch=true}

--   for k,v in pairs(api.get("/weather")) do
--     st:post({type='weather', property=k, value=v})
--   end
-- end

-- ----{type='weather',property=<string>, value=<number>, old=<number>}
-- local SubWeathersnow = SourceTriggerSubscriber()
-- SubWeathersnow:subscribe(
--   {type='weather',property= "WeatherCondition", value="cloudy"}, ------------partlyCloudy   fog    clear   storm   snow   rain    cloudy----------
--   function(event)      
--     print("SubWeathersnow")
--   SubWeathersnow:stop()
--   print("SubWeathersnow2")
-- end)
-- -----oninit-------
-- SubWeathersnow:run()
-- for k,v in pairs(api.get("/weather")) do -- post weather events to ourselves when wwe start up
--   SubWeathersnow:post({type='weather', property=k, value=v})
-- end

---------------FibaroPiroff---------------
local FibaroPiroff = SourceTriggerSubscriber()

FibaroPiroff:subscribe({type='device', id=PirFibaroID, value=false, duration=60},
  function(event)                  
    print("FibaroPiroff")
  end)

FibaroPiroff:subscribe({type='device', id=PirFibaroID, value=true},
  function(event)                  
    pirTimer = FibaroPiroff:post({type='device', id=PirFibaroID, value=false, duration=60},60)
  end)

FibaroPiroff:subscribe({type='device', id=PirFibaroID, value=false},
  function(event)                  
    FibaroPiroff:cancel(pirTimer)
  end)
  
----oninit-----
FibaroPiroff:run()