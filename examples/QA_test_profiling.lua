--%%name=MyQA
--%%type=com.fibaro.binarySwitch

-- Still needs some work... reports are a bit wrong...
function QuickApp:onInit()
   self:debug('onInit',self.name,self.id)

   fibaro.fibemu.profiler.start()

   for i=1,1 do
    fibaro.getGlobalVariable("A")
   end
   
   print("OK")
   fibaro.fibemu.profiler.stop()

   print(fibaro.fibemu.profiler.log())
end

