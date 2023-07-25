local util = {}

local format = string.format

function util.init(config, libs)
  QA.prettyJson = util.prettyJson
end

function util.timerQueue()
  local queue, ref = {}, 0
  local sleepers = {}

  local function addTimer(id, t, fun, args, nosleep)
    ref = ref + 1
    local tstruct = { id = id, t = t, fun = fun, args = args, ref = ref }
    if sleepers[id] and not nosleep then
      sleepers[id][#sleepers[id] + 1] = tstruct
      return ref
    end
    local i = 1
    while i <= #queue and queue[i].t <= t do i = i + 1 end
    table.insert(queue, i, tstruct)
    return ref
  end

  local function popTimer()
    local t = queue[1]
    table.remove(queue, 1)
    return t.t, t.fun, t.args
  end
  local function removeTimer(ref)
    local i = 1
    while i <= #queue do
      if queue[i].ref == ref then
        table.remove(queue, i)
        return
      end
      i = i + 1
    end
  end
  local function peekTimer()
    if queue[1] == nil then return nil end
    return queue[1].t, queue[1].fun, queue[1].args
  end
  local function removeTimerId(id)
    local i = 1
    while i <= #queue do
      if queue[i].id == id then
        table.remove(queue, i)
      else
        i = i + 1
      end
    end
    if queue[1] == nil then return nil end
    return queue[1].t, queue[1].fun, queue[1].args
  end

  local function saveTimers(id)
    local sq = {}
    sleepers[id] = sq
    local i = 1
    while i <= #queue do
      if queue[i].id == id then
        sq[#sq + 1] = table.remove(queue, i)
      else
        i = i + 1
      end
    end
  end

  local function restoreTimers(id)
    local timers = sleepers[id]
    if timers == nil then return end
    sleepers[id] = nil
    if #timers == 0 then return end
    local i, qs = 1, #queue
    for _, t in ipairs(timers) do
      while i <= qs and queue[i].t <= t.t do i = i + 1 end
      if i > qs then
        queue[#queue + 1] = t
      else
        table.insert(queue, i, t)
        i = i + 1
      end
    end
  end

  return {
    add = addTimer,
    pop = popTimer,
    peek = peekTimer,
    remove = removeTimer,
    removeId = removeTimerId,
    save = saveTimers,
    restore = restoreTimers
  }
end

local COLORMAP = {
  aqua = "\027[38;5;14m",
  aquamarine1 = "\027[38;5;122m",
  aquamarine3 = "\027[38;5;79m",
  black = "\027[38;5;0m",
  blue = "\027[38;5;12m",
  blue1 = "\027[38;5;21m",
  blue3 = "\027[38;5;20m",
  blueviolet = "\027[38;5;57m",
  cadetblue = "\027[38;5;73m",
  chartreuse1 = "\027[38;5;118m",
  chartreuse2 = "\027[38;5;112m",
  chartreuse3 = "\027[38;5;76m",
  chartreuse4 = "\027[38;5;64m",
  cornflowerblue = "\027[38;5;69m",
  cornsilk1 = "\027[38;5;230m",
  cyan1 = "\027[38;5;51m",
  cyan2 = "\027[38;5;50m",
  cyan3 = "\027[38;5;43m",
  darkblue = "\027[38;5;18m",
  darkcyan = "\027[38;5;36m",
  darkgoldenrod = "\027[38;5;136m",
  darkgreen = "\027[38;5;22m",
  darkkhaki = "\027[38;5;143m",
  darkmagenta = "\027[38;5;91m",
  darkolivegreen1 = "\027[38;5;192m",
  darkolivegreen2 = "\027[38;5;155m",
  darkolivegreen3 = "\027[38;5;149m",
  darkorange = "\027[38;5;208m",
  darkorange3 = "\027[38;5;166m",
  darkred = "\027[38;5;88m",
  darkseagreen = "\027[38;5;108m",
  darkseagreen1 = "\027[38;5;193m",
  darkseagreen2 = "\027[38;5;157m",
  darkseagreen3 = "\027[38;5;150m",
  darkseagreen4 = "\027[38;5;71m",
  darkslategray1 = "\027[38;5;123m",
  darkslategray2 = "\027[38;5;87m",
  darkslategray3 = "\027[38;5;116m",
  darkturquoise = "\027[38;5;44m",
  darkviolet = "\027[38;5;128m",
  deeppink1 = "\027[38;5;199m",
  deeppink2 = "\027[38;5;197m",
  deeppink3 = "\027[38;5;162m",
  deeppink4 = "\027[38;5;125m",
  deepskyblue1 = "\027[38;5;39m",
  deepskyblue2 = "\027[38;5;38m",
  deepskyblue3 = "\027[38;5;32m",
  deepskyblue4 = "\027[38;5;25m",
  dodgerblue1 = "\027[38;5;33m",
  dodgerblue2 = "\027[38;5;27m",
  dodgerblue3 = "\027[38;5;26m",
  fuchsia = "\027[38;5;13m",
  gold1 = "\027[38;5;220m",
  gold3 = "\027[38;5;178m",
  green = "\027[38;5;2m",
  green1 = "\027[38;5;46m",
  green3 = "\027[38;5;40m",
  green4 = "\027[38;5;28m",
  greenyellow = "\027[38;5;154m",
  grey = "\027[38;5;8m",
  grey0 = "\027[38;5;16m",
  grey100 = "\027[38;5;231m",
  grey11 = "\027[38;5;234m",
  grey15 = "\027[38;5;235m",
  grey19 = "\027[38;5;236m",
  grey23 = "\027[38;5;237m",
  grey27 = "\027[38;5;238m",
  grey3 = "\027[38;5;232m",
  grey30 = "\027[38;5;239m",
  grey35 = "\027[38;5;240m",
  grey37 = "\027[38;5;59m",
  grey39 = "\027[38;5;241m",
  grey42 = "\027[38;5;242m",
  grey46 = "\027[38;5;243m",
  grey50 = "\027[38;5;244m",
  grey53 = "\027[38;5;102m",
  grey54 = "\027[38;5;245m",
  grey58 = "\027[38;5;246m",
  grey62 = "\027[38;5;247m",
  grey63 = "\027[38;5;139m",
  grey66 = "\027[38;5;248m",
  grey69 = "\027[38;5;145m",
  grey7 = "\027[38;5;233m",
  grey70 = "\027[38;5;249m",
  grey74 = "\027[38;5;250m",
  grey78 = "\027[38;5;251m",
  grey82 = "\027[38;5;252m",
  grey84 = "\027[38;5;188m",
  grey85 = "\027[38;5;253m",
  grey89 = "\027[38;5;254m",
  grey93 = "\027[38;5;255m",
  honeydew2 = "\027[38;5;194m",
  hotpink = "\027[38;5;206m",
  hotpink2 = "\027[38;5;169m",
  hotpink3 = "\027[38;5;168m",
  indianred = "\027[38;5;167m",
  indianred1 = "\027[38;5;204m",
  khaki1 = "\027[38;5;228m",
  khaki3 = "\027[38;5;185m",
  lightcoral = "\027[38;5;210m",
  lightcyan1 = "\027[38;5;195m",
  lightcyan3 = "\027[38;5;152m",
  lightgoldenrod1 = "\027[38;5;227m",
  lightgoldenrod2 = "\027[38;5;222m",
  lightgoldenrod3 = "\027[38;5;179m",
  lightgreen = "\027[38;5;120m",
  lightpink1 = "\027[38;5;217m",
  lightpink3 = "\027[38;5;174m",
  lightpink4 = "\027[38;5;95m",
  lightsalmon1 = "\027[38;5;216m",
  lightsalmon3 = "\027[38;5;173m",
  lightseagreen = "\027[38;5;37m",
  lightskyblue1 = "\027[38;5;153m",
  lightskyblue3 = "\027[38;5;110m",
  lightslateblue = "\027[38;5;105m",
  lightslategrey = "\027[38;5;103m",
  lightsteelblue = "\027[38;5;147m",
  lightsteelblue1 = "\027[38;5;189m",
  lightsteelblue3 = "\027[38;5;146m",
  lightyellow3 = "\027[38;5;187m",
  lime = "\027[38;5;10m",
  magenta1 = "\027[38;5;201m",
  magenta2 = "\027[38;5;200m",
  magenta3 = "\027[38;5;164m",
  maroon = "\027[38;5;1m",
  mediumorchid = "\027[38;5;134m",
  mediumorchid1 = "\027[38;5;207m",
  mediumorchid3 = "\027[38;5;133m",
  mediumpurple = "\027[38;5;104m",
  mediumpurple1 = "\027[38;5;141m",
  mediumpurple2 = "\027[38;5;140m",
  mediumpurple3 = "\027[38;5;98m",
  mediumpurple4 = "\027[38;5;60m",
  mediumspringgreen = "\027[38;5;49m",
  mediumturquoise = "\027[38;5;80m",
  mediumvioletred = "\027[38;5;126m",
  mistyrose1 = "\027[38;5;224m",
  mistyrose3 = "\027[38;5;181m",
  navajowhite1 = "\027[38;5;223m",
  navajowhite3 = "\027[38;5;144m",
  navy = "\027[38;5;4m",
  navyblue = "\027[38;5;17m",
  olive = "\027[38;5;3m",
  orange1 = "\027[38;5;214m",
  orange3 = "\027[38;5;172m",
  orange4 = "\027[38;5;94m",
  orangered1 = "\027[38;5;202m",
  orchid = "\027[38;5;170m",
  orchid1 = "\027[38;5;213m",
  orchid2 = "\027[38;5;212m",
  palegreen1 = "\027[38;5;156m",
  palegreen3 = "\027[38;5;114m",
  paleturquoise1 = "\027[38;5;159m",
  paleturquoise4 = "\027[38;5;66m",
  palevioletred1 = "\027[38;5;211m",
  pink1 = "\027[38;5;218m",
  pink3 = "\027[38;5;175m",
  plum1 = "\027[38;5;219m",
  plum2 = "\027[38;5;183m",
  plum3 = "\027[38;5;176m",
  plum4 = "\027[38;5;96m",
  purple0 = "\027[38;5;93m",
  purple3 = "\027[38;5;56m",
  purple4 = "\027[38;5;55m",
  purple5 = "\027[38;5;129m",
  purples = "\027[38;5;5m",
  red = "\027[38;5;9m",
  red1 = "\027[38;5;196m",
  red3 = "\027[38;5;160m",
  rosybrown = "\027[38;5;138m",
  royalblue1 = "\027[38;5;63m",
  salmon1 = "\027[38;5;209m",
  sandybrown = "\027[38;5;215m",
  seagreen1 = "\027[38;5;85m",
  seagreen2 = "\027[38;5;83m",
  seagreen3 = "\027[38;5;78m",
  silver = "\027[38;5;7m",
  skyblue1 = "\027[38;5;117m",
  skyblue2 = "\027[38;5;111m",
  skyblue3 = "\027[38;5;74m",
  slateblue1 = "\027[38;5;99m",
  slateblue3 = "\027[38;5;62m",
  springgreen1 = "\027[38;5;48m",
  springgreen2 = "\027[38;5;47m",
  springgreen3 = "\027[38;5;41m",
  springgreen4 = "\027[38;5;29m",
  steelblue = "\027[38;5;67m",
  steelblue1 = "\027[38;5;81m",
  steelblue3 = "\027[38;5;68m",
  tan = "\027[38;5;180m",
  teal = "\027[38;5;6m",
  thistle1 = "\027[38;5;225m",
  thistle3 = "\027[38;5;182m",
  turquoise2 = "\027[38;5;45m",
  turquoise4 = "\027[38;5;30m",
  violet = "\027[38;5;177m",
  wheat1 = "\027[38;5;229m",
  wheat4 = "\027[38;5;101m",
  white = "\027[38;5;15m",
  yellow = "\027[38;5;11m",
  yellow1 = "\027[38;5;226m",
  yellow2 = "\027[38;5;190m",
  yellow3 = "\027[38;5;184m",
  yellow4 = "\027[38;5;106m",
}
COLORMAP.brown = COLORMAP.sandybrown
os.COLORMAP = COLORMAP
local colorEnd = '\027[0m'

local fibColors = {
  ["SYS"] = 'brown',
  ["SYSERR"] = 'red',
  ["DEBUG"] = 'green',
  ["TRACE"] = 'blue',
  ["WARNING"] = 'orange',
  ["ERROR"] = 'red',
  ['TEXT'] = 'black',
  ['DARKTEXT'] = 'grey82'
}

local function html2color(str, startColor, dflTxt)
  local st, p = { startColor or COLORMAP[dflTxt or 'TEXT'] }, 1
  return str:gsub("(</?font.->)", function(s)
    if s == "</font>" then
      p = p - 1; return st[p]
    else
      local color = s:match("color=([#%w]+)")
      color = COLORMAP[color] or (fibaro.colorMap[color] and COLORMAP[fibaro.colorMap[color] or dflTxt]) or
          COLORMAP['black']
      p = p + 1; st[p] = color
      return color
    end
  end)
end

function util.debug(flags, tag, str, typ)
  if flags.logFilters and #flags.logFilters > 0 then
    for _,filter in ipairs(flags.logFilters or {}) do
        if str:match(filter) then return end
    end
  end
  typ = typ:upper()
  str = flags.html and html2color(str, nil, fibColors['TEXT']) or
      str:gsub("(</?font.->)", "") -- Remove color tags
  str = str:gsub("(&nbsp;)", " ")  -- remove html space
  if flags.color then
    local txt_color = COLORMAP[(fibColors['TEXT'] or "black")]
    local typ_color = COLORMAP[(fibColors[typ] or "black")]
    local outstr = format("%s%s [%s%-6s%s] [%-7s]: %s%s",
      txt_color, os.date("[%d.%m.%Y] [%H:%M:%S]"),
      typ_color, typ, txt_color,
      tag,
      str,
      colorEnd
    )
    print(outstr) --io.write(outstr,"\r\n")
  else
    print(format("%s [%s] [%s]: %s", os.date("[%d.%m.%Y] [%H:%M:%S]"), typ, tag, str))
  end
end

util.COLORMAP = COLORMAP
util.fibColors = fibColors

function util.base64encode(data)
  local bC = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  return ((data:gsub('.', function(x)
    local r, b = '', x:byte()
    for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') end
    return r;
  end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
    if (#x < 6) then return '' end
    local c = 0
    for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
    return bC:sub(c + 1, c + 1)
  end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

function util.basicAuthorization(user, password) return "Basic " .. util.base64encode(user .. ":" .. password) end

function util.toarray(t)
  local a = {}
  for k, v in pairs(t) do a[#a + 1] = v end
  return a
end

local function copy(o)
  if type(o) ~= 'table' then return o end
  local res = {}
  for k, v in pairs(o) do res[k] = copy(v) end
  return res
end
util.copy = copy

function util.merge(a, b)
  local m, res = {}, {}
  for _, v in ipairs(a) do m[v] = true end
  for _, v in ipairs(b) do m[v] = true end
  for k, _ in pairs(m) do res[#res + 1] = k end
  return res
end

function util.append(a, b)
  local res = {}
  for _, v in ipairs(a) do res[#res + 1] = v end
  for _, v in ipairs(b) do res[#res + 1] = v end
  return res
end

function util.member(e, t)
  for _,e0 in ipairs(t) do if e==e0 then return true end end
end

do -- Used for print device table structs - sortorder for device structs
  local sortKeys = {
    'id', 'name', 'roomID', 'type', 'baseType', 'enabled', 'visible', 'isPlugin', 'parentId', 'viewXml', 'configXml',
    'interfaces', 'properties', 'view', 'actions', 'created', 'modified', 'sortOrder',
  }
  local sortOrder = {}
  for i, s in ipairs(sortKeys) do sortOrder[s] = "\n" .. string.char(i + 64) .. " " .. s end
  local function keyCompare(a, b)
    local av, bv = sortOrder[a] or a, sortOrder[b] or b
    return av < bv
  end

  local function prettyJsonStruct(t0)
    local res = {}
    local function isArray(t) return type(t) == 'table' and t[1] end
    local function isEmpty(t) return type(t) == 'table' and next(t) == nil end
    local function printf(tab, fmt, ...) res[#res + 1] = string.rep(' ', tab) .. format(fmt, ...) end
    local function pretty(tab, t, key)
      if type(t) == 'table' then
        if isEmpty(t) then
          printf(0, "[]")
          return
        end
        if isArray(t) then
          printf(key and tab or 0, "[\n")
          for i, k in ipairs(t) do
            local _ = pretty(tab + 1, k, true)
            if i ~= #t then printf(0, ',') end
            printf(tab + 1, '\n')
          end
          printf(tab, "]")
          return true
        end
        local r = {}
        for k, _ in pairs(t) do r[#r + 1] = k end
        table.sort(r, keyCompare)
        printf(key and tab or 0, "{\n")
        for i, k in ipairs(r) do
          printf(tab + 1, '"%s":', k)
          local _ = pretty(tab + 1, t[k])
          if i ~= #r then printf(0, ',') end
          printf(tab + 1, '\n')
        end
        printf(tab, "}")
        return true
      elseif type(t) == 'number' then
        printf(key and tab or 0, "%s", t)
      elseif type(t) == 'boolean' then
        printf(key and tab or 0, "%s", t and 'true' or 'false')
      elseif type(t) == 'string' then
        printf(key and tab or 0, '"%s"', t:gsub('(%")', '\\"'))
      end
    end
    pretty(0, json.decode(t0), true)
    return table.concat(res, "")
  end
  util.prettyJson = prettyJsonStruct
end

function util.getErrCtx(level)
  return debug.getinfo(level or 2)
end

local stackSkips = { ["breakForError"] = true, ["luaError"] = true, ["error"] = true, ["assert"] = true }
local unpack = table.unpack
function util.epcall(fib,TAG,pre,stackPrint,cctx,f, ...)
    local args,calledFrom = {...},""
    if cctx then
      calledFrom = format(" called from %s:%s",cctx.source,cctx.currentline)
    end
    return xpcall(function() f(unpack(args)) end, function(err)
        local i = 2
        local ctx = os.debug.getinfo(i)
        while ctx and (ctx.what and ctx.what == 'C' or ctx.name and stackSkips[ctx.name or ""]) do
            --print("SKIP, ", ctx.name)
            i = i + 1
            ctx = os.debug.getinfo(i)
        end
        local res = {}
        while ctx.func ~= f do
            table.insert(res, ctx)
            i = i + 1
            ctx = os.debug.getinfo(i)
        end
        res[#res + 1] = ctx
        local line, errmsg = err:match(".-:(%d+):%s*(.*)")
        local c = table.remove(res, 1)
        local name = c.name and (c.name .. ":") or ""
        errmsg = format("%s, %s:%s%s%s", errmsg, c.source, name, c.currentline, calledFrom)
        local out = { pre and (pre..":"..errmsg) or errmsg }
        if stackPrint then
            local last = nil
            if #res == 0 then 
              fib.error(TAG,out[1])
              return 
            end
            local c = res[1]
            local name = c.name and (c.name .. ":") or ""
            local last = format("--> %s:%s%s", c.source, name, c.currentline)
            local rep = 0
            for i = 2, #res do
                local c = res[i]
                local name = c.name and (c.name .. ":") or ""
                local new = format("--> %s:%s%s", c.source, name, c.currentline)
                if new ~= last then
                    out[#out + 1] = last .. (rep > 0 and format(" (%s)", rep) or "")
                    last = new
                    rep = 0
                else
                    rep = rep + 1
                end
            end
            fib.error(TAG,table.concat(out, "\n"))
        else
            fib.error(TAG,out[1])
        end
    end)
end

return util
