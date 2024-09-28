--%%name=BetterQA
--%%type=com.fibaro.binarySwitch

--%%file=lib/BetterQA.lua,BQA;

function QuickApp:onInit()
  self:debug("onInit")
  local n,r = 0
  r = setInterval(function() 
      n = n+1
      local s = fibaro.timerToString(r)
      if n > 4 then clearInterval(r) end 
      print("OK",n)
      print(s)
  end,1000,"Interval")
  --fibaro.listTimers()
  -- setTimeout(function() 
  --   print("OK")
  -- end,20000,"Timeout")
end
