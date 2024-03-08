--%%name=SVGTest3
--%%u={label="label1", text='SVG paceholder'}
--%%id=1507

--%%file=examples/SVG.lua,svg;
--%%image=examples/MAP.SVG,map

local fmt = string.format
local dataDefs,dataData,dataOrg

local tags = {
  _width = 400,
  _height = 400,
  alert1 = "green",
  alert2 = "green",
  alert3 = "green",
  alert4 = "green",
  alert5 = "green",
  alert6 = "green",
  alert7 = "green",
  alert8 = "green",
  alert9 = "green",
  alert10 = "green",
  alert11 = "green",
  alert12 = "green",
  alert13 = "green",
  temp1 = "37.5°",
  temp3 = "37.5°",
  temp4 = "37.5°",
  temp5 = "37.5°",
  temp7 = "37.5°",
  temp8 = "37.5°",
  temp9 = "37.5°",
  temp10 = "37.5°",
  temp11 = "37.5°",
  temp12 = "37.5°",
  temp13 = "37.5°", 
}

local function randomize(map)
  for tag,_ in pairs(map.values) do
    if tag:sub(1,5) == 'alert' then
      local value = math.random(1,3)
      if value == 1 then
        map.values[tag] = 'red' --'#FF0000'
      elseif value == 2 then
        map.values[tag] = 'yellow' --'#00FF00'
      elseif value == 3 then
        map.values[tag] = 'green' --'#0000FF'
      end
    elseif tag:sub(1,4) == 'temp' then
      map.values[tag] = fmt("%.1f°",math.random(10,40))
    end
  end
end

function QuickApp:onInit()
  local m = _IMAGES['map']
  local map = TaggedImage(m.data,tags)
  setInterval(function()
   randomize(map)
   self:updateView('label1', 'text', 
   fmt('<img src="%s" width=400 height=400/>',map:render())
  )
  end,3000)
end