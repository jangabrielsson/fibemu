--%%name=SVGTest
--%%u={{button="raster", text="Raster", onReleased="raster"},{button="sensors", text="Flip indicators", onReleased="indic"}}
--%%u={slider="temp", onChanged="temp"}
--%%u={label="label1", text='SVG paceholder'}

--%%file=examples/SVG.lua,svg;
--%%file=examples/SVGimages.lua,images;

local fmt = string.format

function QuickApp:onInit()
  self:createMap()
  self:drawMap()
end

function QuickApp:raster(ev) 
  self.image.raster = not self.image.raster
  self:drawMap()
end

function QuickApp:indic(ev)
  local map = {"#red","#yellow","#green"} 
  for i,ind in ipairs(self.indicators) do
    ind.href=map[math.random(1,3)] -- just select a random color
  end
  self:drawMap()
end

function QuickApp:temp(ev)
  local val = ev.values[1]
  for i,t in ipairs(self.temps) do
    t.text = string.format('%.1f°',1.1*val*i)
  end
  self:drawMap()
end

function QuickApp:createMap()
  local map = _IMAGES['houseMap']
  local imwidth,imheight = SVG.getImageSize(map)
  local scale = 400/imwidth
  local width,height = 400,imheight*scale
  local im = SVG(self,'label1',width,height)
  im:add(Rectangle{x=0,y=0,width=width,height=height,style='fill:grey'})
  local m = im:add(Image{x=0,y=0,width=width,height=height,href=map})
  --m.transform=fmt("scale(%s)",scale) -- Scale the image to fit the window

  self.temps = {}
  local tempPos = {{x=100,y=100},{x=200,y=100},{x=300,y=100},{x=100,y=200},{x=300,y=200}}
  for i=1,5 do -- Add 5 temp labels
    self.temps[#self.temps+1] =
      im:add(Text{x=tempPos[i].x,y=tempPos[i].y,text=fmt('0.%d°',i),style='font-size:15;border:1', filter='url(%23rounded-corners)'})
  end
  self.indicators = {}
  local indPos = {{x=75,y=100},{x=175,y=100},{x=275,y=200},{x=75,y=200},{x=175,y=200}}
  -- for i=1,5 do  -- Add 5 circle indicators
  --   local sprite = Sprite{
  --     x=indPos[i].x,
  --     y=indPos[i].y,
  --     elements={
  --       Circle{r=10,style='fill:red;stroke:black'},
  --       Circle{r=10,style='fill:yellow;stroke:black'},
  --       Circle{r=10,style='fill:green;stroke:black'}
  --     }
  --   }
  --   self.indicators[#self.indicators+1] = im:add(sprite)
  -- end
  im:symbol("red",[[<circle cx="10" cy="10" r="10" style="fill:red;stroke:black"/>]])
  im:symbol("yellow",[[<circle cx="10" cy="10" r="10" style="fill:yellow;stroke:black"/>]])
  im:symbol("green",[[<circle cx="10" cy="10" r="10" style="fill:green;stroke:black"/>]])
  for i=1,5 do
    self.indicators[#self.indicators+1] = im:add(Symbol{href="#green",x=indPos[i].x,y=indPos[i].y})
  end

  -- Created with https://boxy-svg.com/app editor
  im:symbol("foo",
    [[<svg viewBox="83.6651 66.158 43.6658 44.704" width="43.6658" height="44.704" xmlns="http://www.w3.org/2000/svg" xmlns:bx="https://boxy-svg.com">
  <path d="M 97.57 69.165 Q 105.498 63.151 113.426 69.165 L 121.594 75.361 Q 129.522 81.375 126.494 91.106 L 123.374 101.131 Q 120.345 110.862 110.546 110.862 L 100.45 110.862 Q 90.651 110.862 87.622 101.131 L 84.502 91.106 Q 81.474 81.375 89.402 75.361 Z" 
   transform="matrix(1, 0, 0, 1, 0, 7.105427357601002e-15)" bx:shape="n-gon 105.498 89.525 25.26 26.374 5 0.33 1@6ecf38d1"/>
    </svg>]])
  im:add(Symbol{href="#foo",x=340,y=110,fill="red",onclick="alert('You have clicked the circle.')"})

  im:add(Element([[
    <svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
  <path
    fill="none"
    stroke="lightgrey"
    d="M20,50 C20,-50 180,150 180,50 C180-50 20,150 20,50 z" />

  <circle r="5" fill="red">
    <animateMotion
      dur="10s"
      repeatCount="indefinite"
      path="M20,50 C20,-50 180,150 180,50 C180-50 20,150 20,50 z" />
  </circle>
</svg>
  ]]))
  --im.root.transform=fmt("scale(%s)",scale)
  self.image = im
end

function QuickApp:drawMap()
  self.image:draw()
end