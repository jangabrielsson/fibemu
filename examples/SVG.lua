local fmt = string.format
local charMap = {
  ['\"']="%22",
  ['!']="%21",
  ['#']="%23",
  ['$']="%24",
  ['%']="%25",
  ['&']="%26",
  ['\'']="%27",
  [',']="%2C",
  -- ['<']="%3C",
  -- ['>']="%3E",
  ['=']="%3D",
  ['?']="%3F",
  ['@']="%40",
  ['\n']=""
}
local function prBuff()
  local self,buff = {},{}
  function self:pr(fm,...)
    local str = string.format(fm,...):gsub(".",charMap)
     buff[#buff+1]=str
  end
  function self:add(str)
    str = str:gsub(".",charMap)
    buff[#buff+1]=str
  end
  function self:add2(str)
    buff[#buff+1]=str
  end
  function self:tostring() return table.concat(buff) end
  return self
end

local function round(x) return math.floor(x+0.5) end

local function base64decode(data)
	local result, chars, bytes, stringFormat, stringChar, stringSub = "", {}, {["A"] = 0, ["B"] = 1, ["C"] = 2, ["D"] = 3, ["E"] = 4, ["F"] = 5, ["G"] = 6, ["H"] = 7, ["I"] = 8, ["J"] = 9, ["K"] = 10, ["L"] = 11, ["M"] = 12, ["N"] = 13, ["O"] = 14, ["P"] = 15, ["Q"] = 16, ["R"] = 17, ["S"] = 18, ["T"] = 19, ["U"] = 20, ["V"] = 21, ["W"] = 22, ["X"] = 23, ["Y"] = 24, ["Z"] = 25, ["a"] = 26, ["b"] = 27, ["c"] = 28, ["d"] = 29, ["e"] = 30, ["f"] = 31, ["g"] = 32, ["h"] = 33, ["i"] = 34, ["j"] = 35, ["k"] = 36, ["l"] = 37, ["m"] = 38, ["n"] = 39, ["o"] = 40, ["p"] = 41, ["q"] = 42, ["r"] = 43, ["s"] = 44, ["t"] = 45, ["u"] = 46, ["v"] = 47, ["w"] = 48, ["x"] = 49, ["y"] = 50, ["z"] = 51, ["0"] = 52, ["1"] = 53, ["2"] = 54, ["3"] = 55, ["4"] = 56, ["5"] = 57, ["6"] = 58, ["7"] = 59, ["8"] = 60, ["9"] = 61, ["-"] = 62, ["_"] = 63, ["="] = nil}, string.format, string.char, string.sub
	for i = 0, #data - 1, 4 do
		for j = 1, 4 do
			chars[j] = bytes[stringSub(data, i + j, i + j) or "="]
		end
		result =
			result ..
			stringChar(((chars[1] << 2) % 256 | (chars[2] >> 4))) ..
			(chars[3] and stringChar(((chars[2] << 4) % 256 | (chars[3] >> 2))) or "") ..
			(chars[4] and stringChar(((chars[3] << 6) % 256 | chars[4])) or "")
	end
	return result
end

local function getSize(b)
    local buf = {}
    for i = 1, 8 do buf[i] = b:byte(16 + i) end
    local width = (buf[1] << 24) + (buf[2] << 16) + (buf[3] << 8) + (buf[4] << 0)
    local height = (buf[5] << 24) + (buf[6] << 16) + (buf[7] << 8) + (buf[8] << 0);
    return width, height
end

class 'SVG'
function SVG:__init(qa,label,width,height)
  self.width = width
  self.height = height
  self.label = label
  self.qa = qa
  self.symbols = {}
  self.root = Group{}
  local raster = prBuff()
  raster:pr('<svg>')
  for i=0,height,25 do
    raster:pr('<text x="10" y="%s" font-size="10px">%s</text>',i+10,i)
    raster:pr('<line x1="0" y1="%s" x2="400" y2="%s" stroke-width="0.5" stroke-dasharray="5,5" stroke="black"/>',i,i)
  end
  for i=0,width,25 do
    raster:pr('<text x="%s" y="10" font-size="10px">%s</text>',i+2,i)
    raster:pr('<line x1="%s" y1="0" x2="%s" y2="400" stroke-width="0.5" stroke-dasharray="5,5" stroke="black"/>',i,i)
  end
  raster:pr('</svg>')
  self.rasterSVG = raster:tostring()
  self.raster = true
end

SVG.getImageSize = function(image)
  image = image:sub(23,54)
  image = base64decode(image)
  return getSize(image)
end

function SVG:symbol(name,svg)
  assert(type(svg)=='string',"SVG symbol must be a string")
  self.symbols[name]=svg
end

function SVG:render()
  local buff = prBuff()
  --buff:pr([[<img alt="SVG" src="data:image/svg+xml;utf8,<svg width='%s' height='%s' xmlns='http://www.w3.org/2000/svg'>]],self.width,self.height)
  buff:add2('<img alt="SVG" src="data:image/svg+xml;utf8,')
  buff:pr('<svg width="%s" height="%s" xmlns="http://www.w3.org/2000/svg">',self.width,self.height)
  -- buff:add([[
  --   <defs>
  --   <filter id="rounded-corners" x="-5%" width="110%" y="0%" height="100%">
  --     <feFlood flood-color="#FFAA55"/>
  --     <feGaussianBlur stdDeviation="2"/>
  --     <feComponentTransfer>
  --       <feFuncA type="table" tableValues="0 0 0 1"/>
  --     </feComponentTransfer>
  --     <feComponentTransfer>
  --       <feFuncA type="table" tableValues="0 1 1 1 1 1 1 1"/>
  --     </feComponentTransfer>
  --     <feComposite operator="over" in="SourceGraphic"/>
  --   </filter>
  --   </defs>
  -- ]])
  if self.defs then buff:add(self.defs) end
  for k,v in pairs(self.symbols) do
    buff:pr('<symbol id="%s">%s</symbol>',k,v)
  end
  self.root:render(buff)
  if self.raster then buff:add2(self.rasterSVG) end
  buff:add2('</svg>"/>')
  return buff:tostring()
end
function SVG:add(elm)
  if elm.verify then elm:verify(self) end
  self.root:add(elm) 
  return elm
end
function SVG:draw()
  local im = self:render()
  print(im)
  self.qa:updateView(self.label,'text',im)
end

local function copy(src,dest) for k,v in pairs(src) do dest[k]=v end end

class 'BaseElement'
function BaseElement:__init(params,attrs)
  self.params = params
  self.attrs = attrs
  for _,k in ipairs(attrs) do 
    self[k] = property(
      function(obj) return obj.params[k] end,
      function(obj,v) 
        obj.params[k]=v obj.dirty=true 
      end
    )
  end
  self.dirty = true
end
function BaseElement:render(buff)
  if self.dirty then 
    self.cached = self:render2()
    self.dirty = false
  end
  buff:add2(self.cached)
end
function BaseElement:render2(postfix)
  local b = {self.header}
  for _,k in ipairs(self.attrs) do 
    if self.params[k] then b[#b+1]=fmt('%s="%s" ',k,self.params[k]) end
  end
  b[#b+1]=postfix or '/>'
  return table.concat(b):gsub('.',charMap)
end

local RectAttr = {'x','y','width','height','fill','style','visibility'}
class 'Rectangle'(BaseElement)
function Rectangle:__init(params)
  BaseElement.__init(self,params,RectAttr)
  self.header = '<rect '
end

local CircleAttr = {'cx','cy','r','fill','style','visibility'}
class 'Circle'(BaseElement)
function Circle:__init(params)
  BaseElement.__init(self,params,CircleAttr)
  self.header = '<circle '
end

local SymbolAttr = {'href','x','y','r','fill','style','visibility','onclick'}
class 'Symbol'(BaseElement)
function Symbol:__init(params)
  BaseElement.__init(self,params,SymbolAttr)
  self.header = '<use '
end

local ImageAttr = {'x','y','width','height','href','transform','fill','style','visibility'}
class 'Image'(BaseElement)
function Image:__init(params)
  local header = "data:image/png;base64,"
  assert(params.href,"Image must have an image")
  assert(params.href:sub(1,#header)==header,"Unknown image")
  BaseElement.__init(self,params,ImageAttr)
  self.header = '<image '
end

class 'Group'
function Group:__init(params)
  copy(params,self)
  self.elements = self.elements or {}
end
function Group:add(elm) self.elements[#self.elements+1]=elm return elm end
function Group:render(buff)
  buff:pr('<g transform="%s">',self.transform or '')
  for _,e in ipairs(self.elements) do e:render(buff) end
  buff:pr('</g>')
end

local TextAttr = {'x','y','filter','fill','style','visibility'}
class 'Text'(BaseElement)
function Text:__init(params)
  BaseElement.__init(self,params,TextAttr)
  self.text = property(
    function(obj) return obj.params.text end,
    function(obj,v) 
      obj.params.text=v obj.dirty=true 
    end
  )
  self.header = '<text '
end
function Text:render2()
  local s = BaseElement.render2(self,">")
  local text = self.params.text:gsub(".",charMap)
  return fmt("%s%s</text>",s,text)
end

-- Sprite is a collection of elements where one is visible at a time
class 'Sprite'(Group)
function Sprite.__init(self,params)
  Group.__init(self,params)
end
function Sprite:render(buff)
  self.transform=string.format("translate(%s,%s)",self.x,self.y)
  Group.render(self,buff)
end
function Sprite:select(n)
  for i=1,#self.elements do
    self.elements[i].visibility = i==n and 'visible' or 'hidden'
  end
end

-- This is a simple class to add a string to the SVG
class 'Element'
function Element:__init(str)
  self.str = str
end
function Element:render(buff)
  buff:add(self.str)
end