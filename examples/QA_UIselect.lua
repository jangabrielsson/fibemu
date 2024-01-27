--%%name="Select test"
--%%type=com.fibaro.binarySwitch

--%%u={select='modeSelector',text='modes',options={{text='Auto',value='auto'},{text='Manual',value='manual'},{text='Eco',value='eco'}},onToggled='modeSelector'}
--%%u={{button='b1',text='newOptions',onReleased='newOptions'},{button='b2',text='setManual',onReleased='setManual'},{button='b3',text='setAuto',onReleased='setAuto'}}
--%%u={switch='s1',text='switch1',onReleased='sb'}

function QuickApp:modeSelector(event)
  print(event.values[1])
end

function QuickApp:sb(event)
  print(event.values[1])
  --self:updateView("s1","value","true")
end

function QuickApp:newOptions(event)
  local newData = {{text='Auto3',type='option',value='auto'},{text='Manual1',type='option',value='manual'},{text='Eco1',type='option',value='eco'}}
  newData[1].text = tostring(os.time())
  self:updateView("modeSelector","options",newData)
end

function QuickApp:setManual(event)
  print(event.values[1])
  self:updateView("modeSelector","selectedItem","manual")
end

function QuickApp:setAuto(event)
  print(event.values[1])
  self:updateView("modeSelector","selectedItem","auto")
end

function QuickApp:onInit()
  -- local i = 1
  -- local options = {"auto","manual","eco"}
  -- setInterval(function()
  --   self:updateView("modeSelector","selectedItem",options[i])
  --   i = i % 3 + 1
  -- end, 5000)
end