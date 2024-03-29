--%%name=SVGTest2
--%%u={label="label1", text='SVG paceholder'}

--%%file=examples/SVG.lua,svg;
local fmt = string.format
local dataDefs,dataData,dataOrg

function QuickApp:onInit()
  self:createClock()
  self:drawMap()
end

function QuickApp:createClock()
  -- self:updateView("label0","text",
  --   fmt([[<img alt="SVG" src="data:image/svg+xml;utf8,%s"/>]],
  --   fmt([[<svg xmlns="http://www.w3.org/2000/svg" xmlns:bx="https://boxy-svg.com">%s</svg>]],
  --   dataDefs:gsub("232%.362","232.300")):gsub(".",SVG.charMap))
  -- )
  local im = SVG(self,'label1',400,400)
  im.raster = false
  im.defs = dataDefs:gsub("232%.362","232.300")
  im:add(Rectangle{x=0,y=0,width=160,height=59,fill="url(#gradient-4)"})
  local h1 = im:add(Symbol{href="#Number1", transform="scale(0.2)translate(-50,-100)"})
  local h2 = im:add(Symbol{href="#Number2", transform="scale(0.2)translate(110,-100)"})
  im:add(Symbol{href="#Number:", transform="scale(0.2)translate(270,-100)"})
  local m1 = im:add(Symbol{href="#Number4", transform="scale(0.2)translate(430,-100)"})
  local m2 = im:add(Symbol{href="#Number5", transform="scale(0.2)translate(590,-100)"})
  self.image = im

  local t = 3600*8+60*30+11
  setInterval(function()
    t = (t+60) % (3600*24)
    local h = t // 3600
    local m = (t % 3600) // 60
    h1.href=fmt('#Number%s',h//10)
    h2.href=fmt('#Number%s',h%10)
    m1.href=fmt('#Number%s',m//10)
    m2.href=fmt('#Number%s',m%10)
    print(h//10,h%10,m//10,m%10)
    self:drawMap()
  end,3000)
end

function QuickApp:drawMap()
  self.image:draw()
end

dataDefs = [[
  <defs>
  <filter id="drop-shadow-filter-0" color-interpolation-filters="sRGB" x="-50%" y="-50%" width="200%" height="200%" bx:preset="drop-shadow 1 10 10 5 0.35 rgba(0,0,0,0.3)">
    <feGaussianBlur in="SourceAlpha" stdDeviation="5"></feGaussianBlur>
    <feOffset dx="10" dy="10"></feOffset>
    <feComponentTransfer result="offsetblur">
      <feFuncA id="spread-ctrl" type="linear" slope="0.7"></feFuncA>
    </feComponentTransfer>
    <feFlood flood-color="rgba(0,0,0,0.3)"></feFlood>
    <feComposite in2="offsetblur" operator="in"></feComposite>
    <feMerge>
      <feMergeNode></feMergeNode>
      <feMergeNode in="SourceGraphic"></feMergeNode>
    </feMerge>
  </filter>
  <radialGradient gradientUnits="userSpaceOnUse" cx="69.147" cy="247.354" r="6.945" id="gradient-2" gradientTransform="matrix(0.00038, 0.605445, -7.374908, 0.004634, 1892.33374, 204.342972)">
    <stop offset="0" style="stop-color: rgb(84.706% 84.706% 84.706%)"></stop>
    <stop offset="1" style="stop-color: rgb(91, 89, 89);"></stop>
  </radialGradient>
  <radialGradient gradientUnits="userSpaceOnUse" cx="69.147" cy="247.354" r="6.945" id="gradient-1" gradientTransform="matrix(0.00038, 0.605445, -7.374908, 0.004634, 2016.031738, 204.850647)">
    <stop offset="0" style="stop-color: rgb(84.706% 84.706% 84.706%)"></stop>
    <stop offset="1" style="stop-color: rgb(91, 89, 89);"></stop>
  </radialGradient>
  <linearGradient gradientUnits="userSpaceOnUse" x1="129.985" y1="153.249" x2="129.985" y2="346.75" id="gradient-0" gradientTransform="matrix(0.999999, -0.001542, 0.001278, 0.828717, -0.443073, 59.593021)">
    <stop offset="0" style="stop-color: rgb(175, 172, 172);"></stop>
    <stop offset="1" style="stop-color: rgb(23.408% 23.408% 23.408%)"></stop>
  </linearGradient>
  <linearGradient gradientUnits="userSpaceOnUse" x1="129.985" y1="153.249" x2="129.985" y2="346.75" id="gradient-3" gradientTransform="matrix(1, -0.000001, 0, 0.691945, -0.000001, 106.817975)">
    <stop offset="0" style="stop-color: rgb(116, 113, 113);"></stop>
    <stop offset="1" style="stop-color: rgb(0% 0% 0%)"></stop>
  </linearGradient>
  <linearGradient gradientUnits="userSpaceOnUse" x1="130.137" y1="245.718" x2="130.137" y2="248.686" id="gradient-4" gradientTransform="matrix(-1, 0, 0, -1.083386, 263.48941, 515.635346)">
    <stop offset="0" style="stop-color: rgb(69.804% 69.412% 69.412%)"></stop>
    <stop offset="1" style="stop-color: rgb(40.449% 40.094% 40.094%)"></stop>
  </linearGradient>
  <linearGradient gradientUnits="userSpaceOnUse" x1="20.75" y1="226.109" x2="20.75" y2="233.828" id="gradient-5" gradientTransform="matrix(0.999959, -0.009718, 0.004292, 0.504556, -1.002719, 116.050288)">
    <stop offset="0" style="stop-color: rgb(93.333% 93.333% 93.333%)"></stop>
    <stop offset="1" style="stop-color: rgb(53.086% 53.086% 53.086%)"></stop>
  </linearGradient>
  <style bx:fonts="Readex Pro"></style>
  <linearGradient gradientUnits="userSpaceOnUse" x1="129.985" y1="153.249" x2="129.985" y2="346.75" id="gradient-6" gradientTransform="matrix(0.999999, -0.001542, 0.001278, 0.828717, 146.556927, 59.593021)">
    <stop offset="0" style="stop-color: rgb(175, 172, 172);"></stop>
    <stop offset="1" style="stop-color: rgb(23.408% 23.408% 23.408%)"></stop>
  </linearGradient>
  <linearGradient gradientUnits="userSpaceOnUse" x1="129.985" y1="153.249" x2="129.985" y2="346.75" id="gradient-7" gradientTransform="matrix(1, -0.000001, 0, 0.691945, 146.999999, 106.817978)">
    <stop offset="0" style="stop-color: rgb(116, 113, 113);"></stop>
    <stop offset="1" style="stop-color: rgb(0% 0% 0%)"></stop>
  </linearGradient>
  <filter id="filter-1" color-interpolation-filters="sRGB" x="-50%" y="-50%" width="200%" height="200%" bx:preset="drop-shadow 1 10 10 5 0.35 rgba(0,0,0,0.3)">
    <feGaussianBlur in="SourceAlpha" stdDeviation="5"></feGaussianBlur>
    <feOffset dx="10" dy="10"></feOffset>
    <feComponentTransfer result="offsetblur">
      <feFuncA id="feFuncA-1" type="linear" slope="0.7"></feFuncA>
    </feComponentTransfer>
    <feFlood flood-color="rgba(0,0,0,0.3)"></feFlood>
    <feComposite in2="offsetblur" operator="in"></feComposite>
    <feMerge>
      <feMergeNode></feMergeNode>
      <feMergeNode in="SourceGraphic"></feMergeNode>
    </feMerge>
  </filter>
  <linearGradient gradientUnits="userSpaceOnUse" x1="20.75" y1="226.109" x2="20.75" y2="233.828" id="gradient-8" gradientTransform="matrix(0.999959, -0.009718, 0.004292, 0.504556, -1.002719, 116.050288)">
    <stop offset="0" style="stop-color: rgb(93.333% 93.333% 93.333%)"></stop>
    <stop offset="1" style="stop-color: rgb(53.086% 53.086% 53.086%)"></stop>
  </linearGradient>
  <linearGradient gradientUnits="userSpaceOnUse" x1="130.137" y1="245.718" x2="130.137" y2="248.686" id="gradient-9" gradientTransform="matrix(-1, 0, 0, -1.083386, 410.48941, 515.635376)">
    <stop offset="0" style="stop-color: rgb(69.804% 69.412% 69.412%)"></stop>
    <stop offset="1" style="stop-color: rgb(40.449% 40.094% 40.094%)"></stop>
  </linearGradient>
  <radialGradient gradientUnits="userSpaceOnUse" cx="69.147" cy="247.354" r="6.945" id="gradient-10" gradientTransform="matrix(0.00038, 0.605445, -7.374908, 0.004634, 2163.031738, 204.850647)">
    <stop offset="0" style="stop-color: rgb(84.706% 84.706% 84.706%)"></stop>
    <stop offset="1" style="stop-color: rgb(91, 89, 89);"></stop>
  </radialGradient>
  <radialGradient gradientUnits="userSpaceOnUse" cx="69.147" cy="247.354" r="6.945" id="gradient-11" gradientTransform="matrix(0.00038, 0.605445, -7.374908, 0.004634, 2039.33374, 204.342972)">
    <stop offset="0" style="stop-color: rgb(84.706% 84.706% 84.706%)"></stop>
    <stop offset="1" style="stop-color: rgb(91, 89, 89);"></stop>
  </radialGradient>
  <linearGradient gradientUnits="userSpaceOnUse" x1="129.985" y1="153.249" x2="129.985" y2="346.75" id="gradient-12" gradientTransform="matrix(0.999999, -0.001542, 0.001278, 0.828717, 437.556915, 57.593021)">
    <stop offset="0" style="stop-color: rgb(175, 172, 172);"></stop>
    <stop offset="1" style="stop-color: rgb(23.408% 23.408% 23.408%)"></stop>
  </linearGradient>
  <linearGradient gradientUnits="userSpaceOnUse" x1="129.985" y1="153.249" x2="129.985" y2="346.75" id="gradient-13" gradientTransform="matrix(1, -0.000001, 0, 0.691945, 438, 104.817978)">
    <stop offset="0" style="stop-color: rgb(116, 113, 113);"></stop>
    <stop offset="1" style="stop-color: rgb(0% 0% 0%)"></stop>
  </linearGradient>
  <filter id="filter-2" color-interpolation-filters="sRGB" x="-50%" y="-50%" width="200%" height="200%" bx:preset="drop-shadow 1 10 10 5 0.35 rgba(0,0,0,0.3)">
    <feGaussianBlur in="SourceAlpha" stdDeviation="5"></feGaussianBlur>
    <feOffset dx="10" dy="10"></feOffset>
    <feComponentTransfer result="offsetblur">
      <feFuncA id="feFuncA-2" type="linear" slope="0.7"></feFuncA>
    </feComponentTransfer>
    <feFlood flood-color="rgba(0,0,0,0.3)"></feFlood>
    <feComposite in2="offsetblur" operator="in"></feComposite>
    <feMerge>
      <feMergeNode></feMergeNode>
      <feMergeNode in="SourceGraphic"></feMergeNode>
    </feMerge>
  </filter>
  <linearGradient gradientUnits="userSpaceOnUse" x1="20.75" y1="226.109" x2="20.75" y2="233.828" id="gradient-14" gradientTransform="matrix(0.999959, -0.009718, 0.004292, 0.504556, -1.002719, 116.050288)">
    <stop offset="0" style="stop-color: rgb(93.333% 93.333% 93.333%)"></stop>
    <stop offset="1" style="stop-color: rgb(53.086% 53.086% 53.086%)"></stop>
  </linearGradient>
  <linearGradient gradientUnits="userSpaceOnUse" x1="130.137" y1="245.718" x2="130.137" y2="248.686" id="gradient-15" gradientTransform="matrix(-1, 0, 0, -1.083386, 701.48938, 513.635376)">
    <stop offset="0" style="stop-color: rgb(69.804% 69.412% 69.412%)"></stop>
    <stop offset="1" style="stop-color: rgb(40.449% 40.094% 40.094%)"></stop>
  </linearGradient>
  <radialGradient gradientUnits="userSpaceOnUse" cx="69.147" cy="247.354" r="6.945" id="gradient-16" gradientTransform="matrix(0.00038, 0.605445, -7.374908, 0.004634, 2454.031738, 202.850647)">
    <stop offset="0" style="stop-color: rgb(84.706% 84.706% 84.706%)"></stop>
    <stop offset="1" style="stop-color: rgb(91, 89, 89);"></stop>
  </radialGradient>
  <radialGradient gradientUnits="userSpaceOnUse" cx="69.147" cy="247.354" r="6.945" id="gradient-17" gradientTransform="matrix(0.00038, 0.605445, -7.374908, 0.004634, 2330.33374, 202.342972)">
    <stop offset="0" style="stop-color: rgb(84.706% 84.706% 84.706%)"></stop>
    <stop offset="1" style="stop-color: rgb(91, 89, 89);"></stop>
  </radialGradient>
  <linearGradient gradientUnits="userSpaceOnUse" x1="129.985" y1="153.249" x2="129.985" y2="346.75" id="gradient-18" gradientTransform="matrix(0.999999, -0.001542, 0.001278, 0.828717, 584.556946, 57.593021)">
    <stop offset="0" style="stop-color: rgb(175, 172, 172);"></stop>
    <stop offset="1" style="stop-color: rgb(23.408% 23.408% 23.408%)"></stop>
  </linearGradient>
  <linearGradient gradientUnits="userSpaceOnUse" x1="129.985" y1="153.249" x2="129.985" y2="346.75" id="gradient-19" gradientTransform="matrix(1, -0.000001, 0, 0.691945, 585, 104.817978)">
    <stop offset="0" style="stop-color: rgb(116, 113, 113);"></stop>
    <stop offset="1" style="stop-color: rgb(0% 0% 0%)"></stop>
  </linearGradient>
  <filter id="filter-3" color-interpolation-filters="sRGB" x="-50%" y="-50%" width="200%" height="200%" bx:preset="drop-shadow 1 10 10 5 0.35 rgba(0,0,0,0.3)">
    <feGaussianBlur in="SourceAlpha" stdDeviation="5"></feGaussianBlur>
    <feOffset dx="10" dy="10"></feOffset>
    <feComponentTransfer result="offsetblur">
      <feFuncA id="feFuncA-3" type="linear" slope="0.7"></feFuncA>
    </feComponentTransfer>
    <feFlood flood-color="rgba(0,0,0,0.3)"></feFlood>
    <feComposite in2="offsetblur" operator="in"></feComposite>
    <feMerge>
      <feMergeNode></feMergeNode>
      <feMergeNode in="SourceGraphic"></feMergeNode>
    </feMerge>
  </filter>
  <linearGradient gradientUnits="userSpaceOnUse" x1="20.75" y1="226.109" x2="20.75" y2="233.828" id="gradient-20" gradientTransform="matrix(0.999959, -0.009718, 0.004292, 0.504556, -1.002719, 116.050288)">
    <stop offset="0" style="stop-color: rgb(93.333% 93.333% 93.333%)"></stop>
    <stop offset="1" style="stop-color: rgb(53.086% 53.086% 53.086%)"></stop>
  </linearGradient>
  <linearGradient gradientUnits="userSpaceOnUse" x1="130.137" y1="245.718" x2="130.137" y2="248.686" id="gradient-21" gradientTransform="matrix(-1, 0, 0, -1.083386, 848.48938, 513.635376)">
    <stop offset="0" style="stop-color: rgb(69.804% 69.412% 69.412%)"></stop>
    <stop offset="1" style="stop-color: rgb(40.449% 40.094% 40.094%)"></stop>
  </linearGradient>
  <radialGradient gradientUnits="userSpaceOnUse" cx="69.147" cy="247.354" r="6.945" id="gradient-22" gradientTransform="matrix(0.00038, 0.605445, -7.374908, 0.004634, 2601.031738, 202.850647)">
    <stop offset="0" style="stop-color: rgb(84.706% 84.706% 84.706%)"></stop>
    <stop offset="1" style="stop-color: rgb(91, 89, 89);"></stop>
  </radialGradient>
  <radialGradient gradientUnits="userSpaceOnUse" cx="69.147" cy="247.354" r="6.945" id="gradient-23" gradientTransform="matrix(0.00038, 0.605445, -7.374908, 0.004634, 2477.33374, 202.342972)">
    <stop offset="0" style="stop-color: rgb(84.706% 84.706% 84.706%)"></stop>
    <stop offset="1" style="stop-color: rgb(91, 89, 89);"></stop>
  </radialGradient>
  <linearGradient gradientUnits="userSpaceOnUse" x1="129.985" y1="153.249" x2="129.985" y2="346.75" id="gradient-24" gradientTransform="matrix(0.999999, -0.001542, 0.001278, 0.828717, 292.556931, 58.593021)">
    <stop offset="0" style="stop-color: rgb(175, 172, 172);"></stop>
    <stop offset="1" style="stop-color: rgb(23.408% 23.408% 23.408%)"></stop>
  </linearGradient>
  <linearGradient gradientUnits="userSpaceOnUse" x1="129.985" y1="153.249" x2="129.985" y2="346.75" id="gradient-25" gradientTransform="matrix(1, -0.000001, 0, 0.691945, 293, 105.817978)">
    <stop offset="0" style="stop-color: rgb(116, 113, 113);"></stop>
    <stop offset="1" style="stop-color: rgb(0% 0% 0%)"></stop>
  </linearGradient>
  <filter id="filter-4" color-interpolation-filters="sRGB" x="-50%" y="-50%" width="200%" height="200%" bx:preset="drop-shadow 1 10 10 5 0.35 rgba(0,0,0,0.3)">
    <feGaussianBlur in="SourceAlpha" stdDeviation="5"></feGaussianBlur>
    <feOffset dx="10" dy="10"></feOffset>
    <feComponentTransfer result="offsetblur">
      <feFuncA id="feFuncA-4" type="linear" slope="0.7"></feFuncA>
    </feComponentTransfer>
    <feFlood flood-color="rgba(0,0,0,0.3)"></feFlood>
    <feComposite in2="offsetblur" operator="in"></feComposite>
    <feMerge>
      <feMergeNode></feMergeNode>
      <feMergeNode in="SourceGraphic"></feMergeNode>
    </feMerge>
  </filter>
  <linearGradient gradientUnits="userSpaceOnUse" x1="20.75" y1="226.109" x2="20.75" y2="233.828" id="gradient-26" gradientTransform="matrix(0.999959, -0.009718, 0.004292, 0.504556, -1.002719, 116.050288)">
    <stop offset="0" style="stop-color: rgb(93.333% 93.333% 93.333%)"></stop>
    <stop offset="1" style="stop-color: rgb(53.086% 53.086% 53.086%)"></stop>
  </linearGradient>
  <linearGradient gradientUnits="userSpaceOnUse" x1="130.137" y1="245.718" x2="130.137" y2="248.686" id="gradient-27" gradientTransform="matrix(-1, 0, 0, -1.083386, 556.48941, 514.635376)">
    <stop offset="0" style="stop-color: rgb(69.804% 69.412% 69.412%)"></stop>
    <stop offset="1" style="stop-color: rgb(40.449% 40.094% 40.094%)"></stop>
  </linearGradient>
  <radialGradient gradientUnits="userSpaceOnUse" cx="69.147" cy="247.354" r="6.945" id="gradient-28" gradientTransform="matrix(0.00038, 0.605445, -7.374908, 0.004634, 2309.031738, 203.850647)">
    <stop offset="0" style="stop-color: rgb(84.706% 84.706% 84.706%)"></stop>
    <stop offset="1" style="stop-color: rgb(91, 89, 89);"></stop>
  </radialGradient>
  <radialGradient gradientUnits="userSpaceOnUse" cx="69.147" cy="247.354" r="6.945" id="gradient-29" gradientTransform="matrix(0.00038, 0.605445, -7.374908, 0.004634, 2185.33374, 203.342972)">
    <stop offset="0" style="stop-color: rgb(84.706% 84.706% 84.706%)"></stop>
    <stop offset="1" style="stop-color: rgb(91, 89, 89);"></stop>
  </radialGradient>
  <g id="Number0">
  <path d="M 72.038 153.249 L 187.932 153.249 C 193.455 153.249 197.932 157.726 197.932 163.249 L 197.932 239.868 L 182.763 239.868 L 182.763 255.539 L 197.932 255.539 L 197.932 336.75 C 197.932 342.273 193.455 346.75 187.932 346.75 L 72.038 346.75 C 66.515 346.75 62.038 342.273 62.038 336.75 L 62.038 255.084 L 77.288 255.084 L 77.288 239.413 L 62.038 239.413 L 62.038 163.249 C 62.038 157.726 66.515 153.249 72.038 153.249 Z" style="fill-rule: nonzero; filter: url(#drop-shadow-filter-0); paint-order: stroke; fill: url(#gradient-0); stroke-width: 5px; stroke: url(#gradient-3);"></path>
  <text style="fill: url(#gradient-5); font-family: &quot;Readex Pro&quot;; font-size: 6.9px; filter: none;" transform="matrix(35.989521, 0, 0, 31.635418, -611.175476, -7023.276367)" x="18.834" y="232.362">0</text>
  <rect x="75.969" y="245.718" width="108.335" height="2.968" style="stroke: rgb(80, 80, 80); fill: url(#gradient-4);"></rect>
  <rect x="184.899" y="241.219" width="13.891" height="13.287" style="fill: url(#gradient-1); stroke: rgb(73, 69, 69); transform-origin: 192.313px 247.813px;"></rect>
  <rect x="61.201" y="240.711" width="13.891" height="13.287" style="fill: url(#gradient-2); stroke: rgb(68, 68, 68); transform-box: fill-box; transform-origin: 53.56115% 50%;"></rect>
  </g>
  <g id="Number1">
  <path d="M 72.038 153.249 L 187.932 153.249 C 193.455 153.249 197.932 157.726 197.932 163.249 L 197.932 239.868 L 182.763 239.868 L 182.763 255.539 L 197.932 255.539 L 197.932 336.75 C 197.932 342.273 193.455 346.75 187.932 346.75 L 72.038 346.75 C 66.515 346.75 62.038 342.273 62.038 336.75 L 62.038 255.084 L 77.288 255.084 L 77.288 239.413 L 62.038 239.413 L 62.038 163.249 C 62.038 157.726 66.515 153.249 72.038 153.249 Z" style="fill-rule: nonzero; filter: url(#drop-shadow-filter-0); paint-order: stroke; fill: url(#gradient-0); stroke-width: 5px; stroke: url(#gradient-3);"></path>
  <text style="fill: url(#gradient-5); font-family: &quot;Readex Pro&quot;; font-size: 6.9px; filter: none;" transform="matrix(35.989521, 0, 0, 31.635418, -611.175476, -7023.276367)" x="18.834" y="232.362">1</text>
  <rect x="75.969" y="245.718" width="108.335" height="2.968" style="stroke: rgb(80, 80, 80); fill: url(#gradient-4);"></rect>
  <rect x="184.899" y="241.219" width="13.891" height="13.287" style="fill: url(#gradient-1); stroke: rgb(73, 69, 69); transform-origin: 192.313px 247.813px;"></rect>
  <rect x="61.201" y="240.711" width="13.891" height="13.287" style="fill: url(#gradient-2); stroke: rgb(68, 68, 68); transform-box: fill-box; transform-origin: 53.56115% 50%;"></rect>
  </g>
  <g id="Number2">
  <path d="M 72.038 153.249 L 187.932 153.249 C 193.455 153.249 197.932 157.726 197.932 163.249 L 197.932 239.868 L 182.763 239.868 L 182.763 255.539 L 197.932 255.539 L 197.932 336.75 C 197.932 342.273 193.455 346.75 187.932 346.75 L 72.038 346.75 C 66.515 346.75 62.038 342.273 62.038 336.75 L 62.038 255.084 L 77.288 255.084 L 77.288 239.413 L 62.038 239.413 L 62.038 163.249 C 62.038 157.726 66.515 153.249 72.038 153.249 Z" style="fill-rule: nonzero; filter: url(#drop-shadow-filter-0); paint-order: stroke; fill: url(#gradient-0); stroke-width: 5px; stroke: url(#gradient-3);"></path>
  <text style="fill: url(#gradient-5); font-family: &quot;Readex Pro&quot;; font-size: 6.9px; filter: none;" transform="matrix(35.989521, 0, 0, 31.635418, -611.175476, -7023.276367)" x="18.834" y="232.362">2</text>
  <rect x="75.969" y="245.718" width="108.335" height="2.968" style="stroke: rgb(80, 80, 80); fill: url(#gradient-4);"></rect>
  <rect x="184.899" y="241.219" width="13.891" height="13.287" style="fill: url(#gradient-1); stroke: rgb(73, 69, 69); transform-origin: 192.313px 247.813px;"></rect>
  <rect x="61.201" y="240.711" width="13.891" height="13.287" style="fill: url(#gradient-2); stroke: rgb(68, 68, 68); transform-box: fill-box; transform-origin: 53.56115% 50%;"></rect>
  </g>
  <g id="Number3">
  <path d="M 72.038 153.249 L 187.932 153.249 C 193.455 153.249 197.932 157.726 197.932 163.249 L 197.932 239.868 L 182.763 239.868 L 182.763 255.539 L 197.932 255.539 L 197.932 336.75 C 197.932 342.273 193.455 346.75 187.932 346.75 L 72.038 346.75 C 66.515 346.75 62.038 342.273 62.038 336.75 L 62.038 255.084 L 77.288 255.084 L 77.288 239.413 L 62.038 239.413 L 62.038 163.249 C 62.038 157.726 66.515 153.249 72.038 153.249 Z" style="fill-rule: nonzero; filter: url(#drop-shadow-filter-0); paint-order: stroke; fill: url(#gradient-0); stroke-width: 5px; stroke: url(#gradient-3);"></path>
  <text style="fill: url(#gradient-5); font-family: &quot;Readex Pro&quot;; font-size: 6.9px; filter: none;" transform="matrix(35.989521, 0, 0, 31.635418, -611.175476, -7023.276367)" x="18.834" y="232.362">3</text>
  <rect x="75.969" y="245.718" width="108.335" height="2.968" style="stroke: rgb(80, 80, 80); fill: url(#gradient-4);"></rect>
  <rect x="184.899" y="241.219" width="13.891" height="13.287" style="fill: url(#gradient-1); stroke: rgb(73, 69, 69); transform-origin: 192.313px 247.813px;"></rect>
  <rect x="61.201" y="240.711" width="13.891" height="13.287" style="fill: url(#gradient-2); stroke: rgb(68, 68, 68); transform-box: fill-box; transform-origin: 53.56115% 50%;"></rect>
  </g>
  <g id="Number4">
  <path d="M 72.038 153.249 L 187.932 153.249 C 193.455 153.249 197.932 157.726 197.932 163.249 L 197.932 239.868 L 182.763 239.868 L 182.763 255.539 L 197.932 255.539 L 197.932 336.75 C 197.932 342.273 193.455 346.75 187.932 346.75 L 72.038 346.75 C 66.515 346.75 62.038 342.273 62.038 336.75 L 62.038 255.084 L 77.288 255.084 L 77.288 239.413 L 62.038 239.413 L 62.038 163.249 C 62.038 157.726 66.515 153.249 72.038 153.249 Z" style="fill-rule: nonzero; filter: url(#drop-shadow-filter-0); paint-order: stroke; fill: url(#gradient-0); stroke-width: 5px; stroke: url(#gradient-3);"></path>
  <text style="fill: url(#gradient-5); font-family: &quot;Readex Pro&quot;; font-size: 6.9px; filter: none;" transform="matrix(35.989521, 0, 0, 31.635418, -611.175476, -7023.276367)" x="18.834" y="232.362">4</text>
  <rect x="75.969" y="245.718" width="108.335" height="2.968" style="stroke: rgb(80, 80, 80); fill: url(#gradient-4);"></rect>
  <rect x="184.899" y="241.219" width="13.891" height="13.287" style="fill: url(#gradient-1); stroke: rgb(73, 69, 69); transform-origin: 192.313px 247.813px;"></rect>
  <rect x="61.201" y="240.711" width="13.891" height="13.287" style="fill: url(#gradient-2); stroke: rgb(68, 68, 68); transform-box: fill-box; transform-origin: 53.56115% 50%;"></rect>
  </g>
  <g id="Number5">
  <path d="M 72.038 153.249 L 187.932 153.249 C 193.455 153.249 197.932 157.726 197.932 163.249 L 197.932 239.868 L 182.763 239.868 L 182.763 255.539 L 197.932 255.539 L 197.932 336.75 C 197.932 342.273 193.455 346.75 187.932 346.75 L 72.038 346.75 C 66.515 346.75 62.038 342.273 62.038 336.75 L 62.038 255.084 L 77.288 255.084 L 77.288 239.413 L 62.038 239.413 L 62.038 163.249 C 62.038 157.726 66.515 153.249 72.038 153.249 Z" style="fill-rule: nonzero; filter: url(#drop-shadow-filter-0); paint-order: stroke; fill: url(#gradient-0); stroke-width: 5px; stroke: url(#gradient-3);"></path>
  <text style="fill: url(#gradient-5); font-family: &quot;Readex Pro&quot;; font-size: 6.9px; filter: none;" transform="matrix(35.989521, 0, 0, 31.635418, -611.175476, -7023.276367)" x="18.834" y="232.362">5</text>
  <rect x="75.969" y="245.718" width="108.335" height="2.968" style="stroke: rgb(80, 80, 80); fill: url(#gradient-4);"></rect>
  <rect x="184.899" y="241.219" width="13.891" height="13.287" style="fill: url(#gradient-1); stroke: rgb(73, 69, 69); transform-origin: 192.313px 247.813px;"></rect>
  <rect x="61.201" y="240.711" width="13.891" height="13.287" style="fill: url(#gradient-2); stroke: rgb(68, 68, 68); transform-box: fill-box; transform-origin: 53.56115% 50%;"></rect>
  </g>
  <g id="Number6">
  <path d="M 72.038 153.249 L 187.932 153.249 C 193.455 153.249 197.932 157.726 197.932 163.249 L 197.932 239.868 L 182.763 239.868 L 182.763 255.539 L 197.932 255.539 L 197.932 336.75 C 197.932 342.273 193.455 346.75 187.932 346.75 L 72.038 346.75 C 66.515 346.75 62.038 342.273 62.038 336.75 L 62.038 255.084 L 77.288 255.084 L 77.288 239.413 L 62.038 239.413 L 62.038 163.249 C 62.038 157.726 66.515 153.249 72.038 153.249 Z" style="fill-rule: nonzero; filter: url(#drop-shadow-filter-0); paint-order: stroke; fill: url(#gradient-0); stroke-width: 5px; stroke: url(#gradient-3);"></path>
  <text style="fill: url(#gradient-5); font-family: &quot;Readex Pro&quot;; font-size: 6.9px; filter: none;" transform="matrix(35.989521, 0, 0, 31.635418, -611.175476, -7023.276367)" x="18.834" y="232.362">6</text>
  <rect x="75.969" y="245.718" width="108.335" height="2.968" style="stroke: rgb(80, 80, 80); fill: url(#gradient-4);"></rect>
  <rect x="184.899" y="241.219" width="13.891" height="13.287" style="fill: url(#gradient-1); stroke: rgb(73, 69, 69); transform-origin: 192.313px 247.813px;"></rect>
  <rect x="61.201" y="240.711" width="13.891" height="13.287" style="fill: url(#gradient-2); stroke: rgb(68, 68, 68); transform-box: fill-box; transform-origin: 53.56115% 50%;"></rect>
  </g>
  <g id="Number7">
  <path d="M 72.038 153.249 L 187.932 153.249 C 193.455 153.249 197.932 157.726 197.932 163.249 L 197.932 239.868 L 182.763 239.868 L 182.763 255.539 L 197.932 255.539 L 197.932 336.75 C 197.932 342.273 193.455 346.75 187.932 346.75 L 72.038 346.75 C 66.515 346.75 62.038 342.273 62.038 336.75 L 62.038 255.084 L 77.288 255.084 L 77.288 239.413 L 62.038 239.413 L 62.038 163.249 C 62.038 157.726 66.515 153.249 72.038 153.249 Z" style="fill-rule: nonzero; filter: url(#drop-shadow-filter-0); paint-order: stroke; fill: url(#gradient-0); stroke-width: 5px; stroke: url(#gradient-3);"></path>
  <text style="fill: url(#gradient-5); font-family: &quot;Readex Pro&quot;; font-size: 6.9px; filter: none;" transform="matrix(35.989521, 0, 0, 31.635418, -611.175476, -7023.276367)" x="18.834" y="232.362">7</text>
  <rect x="75.969" y="245.718" width="108.335" height="2.968" style="stroke: rgb(80, 80, 80); fill: url(#gradient-4);"></rect>
  <rect x="184.899" y="241.219" width="13.891" height="13.287" style="fill: url(#gradient-1); stroke: rgb(73, 69, 69); transform-origin: 192.313px 247.813px;"></rect>
  <rect x="61.201" y="240.711" width="13.891" height="13.287" style="fill: url(#gradient-2); stroke: rgb(68, 68, 68); transform-box: fill-box; transform-origin: 53.56115% 50%;"></rect>
  </g>
  <g id="Number8">
  <path d="M 72.038 153.249 L 187.932 153.249 C 193.455 153.249 197.932 157.726 197.932 163.249 L 197.932 239.868 L 182.763 239.868 L 182.763 255.539 L 197.932 255.539 L 197.932 336.75 C 197.932 342.273 193.455 346.75 187.932 346.75 L 72.038 346.75 C 66.515 346.75 62.038 342.273 62.038 336.75 L 62.038 255.084 L 77.288 255.084 L 77.288 239.413 L 62.038 239.413 L 62.038 163.249 C 62.038 157.726 66.515 153.249 72.038 153.249 Z" style="fill-rule: nonzero; filter: url(#drop-shadow-filter-0); paint-order: stroke; fill: url(#gradient-0); stroke-width: 5px; stroke: url(#gradient-3);"></path>
  <text style="fill: url(#gradient-5); font-family: &quot;Readex Pro&quot;; font-size: 6.9px; filter: none;" transform="matrix(35.989521, 0, 0, 31.635418, -611.175476, -7023.276367)" x="18.834" y="232.362">8</text>
  <rect x="75.969" y="245.718" width="108.335" height="2.968" style="stroke: rgb(80, 80, 80); fill: url(#gradient-4);"></rect>
  <rect x="184.899" y="241.219" width="13.891" height="13.287" style="fill: url(#gradient-1); stroke: rgb(73, 69, 69); transform-origin: 192.313px 247.813px;"></rect>
  <rect x="61.201" y="240.711" width="13.891" height="13.287" style="fill: url(#gradient-2); stroke: rgb(68, 68, 68); transform-box: fill-box; transform-origin: 53.56115% 50%;"></rect>
  </g>
  <g id="Number9">
  <path d="M 72.038 153.249 L 187.932 153.249 C 193.455 153.249 197.932 157.726 197.932 163.249 L 197.932 239.868 L 182.763 239.868 L 182.763 255.539 L 197.932 255.539 L 197.932 336.75 C 197.932 342.273 193.455 346.75 187.932 346.75 L 72.038 346.75 C 66.515 346.75 62.038 342.273 62.038 336.75 L 62.038 255.084 L 77.288 255.084 L 77.288 239.413 L 62.038 239.413 L 62.038 163.249 C 62.038 157.726 66.515 153.249 72.038 153.249 Z" style="fill-rule: nonzero; filter: url(#drop-shadow-filter-0); paint-order: stroke; fill: url(#gradient-0); stroke-width: 5px; stroke: url(#gradient-3);"></path>
  <text style="fill: url(#gradient-5); font-family: &quot;Readex Pro&quot;; font-size: 6.9px; filter: none;" transform="matrix(35.989521, 0, 0, 31.635418, -611.175476, -7023.276367)" x="18.834" y="232.362">9</text>
  <rect x="75.969" y="245.718" width="108.335" height="2.968" style="stroke: rgb(80, 80, 80); fill: url(#gradient-4);"></rect>
  <rect x="184.899" y="241.219" width="13.891" height="13.287" style="fill: url(#gradient-1); stroke: rgb(73, 69, 69); transform-origin: 192.313px 247.813px;"></rect>
  <rect x="61.201" y="240.711" width="13.891" height="13.287" style="fill: url(#gradient-2); stroke: rgb(68, 68, 68); transform-box: fill-box; transform-origin: 53.56115% 50%;"></rect>
  </g>
  <g id="Number:">
  <path d="M 72.038 153.249 L 187.932 153.249 C 193.455 153.249 197.932 157.726 197.932 163.249 L 197.932 239.868 L 182.763 239.868 L 182.763 255.539 L 197.932 255.539 L 197.932 336.75 C 197.932 342.273 193.455 346.75 187.932 346.75 L 72.038 346.75 C 66.515 346.75 62.038 342.273 62.038 336.75 L 62.038 255.084 L 77.288 255.084 L 77.288 239.413 L 62.038 239.413 L 62.038 163.249 C 62.038 157.726 66.515 153.249 72.038 153.249 Z" style="fill-rule: nonzero; filter: url(#drop-shadow-filter-0); paint-order: stroke; fill: url(#gradient-0); stroke-width: 5px; stroke: url(#gradient-3);"></path>
  <text style="fill: url(#gradient-5); font-family: &quot;Readex Pro&quot;; font-size: 6.9px; filter: none;" transform="matrix(35.989521, 0, 0, 31.635418, -611.175476, -7023.276367)" x="19.834" y="231.362">:</text>
  <rect x="75.969" y="245.718" width="108.335" height="2.968" style="stroke: rgb(80, 80, 80); fill: url(#gradient-4);"></rect>
  <rect x="184.899" y="241.219" width="13.891" height="13.287" style="fill: url(#gradient-1); stroke: rgb(73, 69, 69); transform-origin: 192.313px 247.813px;"></rect>
  <rect x="61.201" y="240.711" width="13.891" height="13.287" style="fill: url(#gradient-2); stroke: rgb(68, 68, 68); transform-box: fill-box; transform-origin: 53.56115% 50%;"></rect>
  </g>
  </defs>
]]
