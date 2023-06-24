local util = {}

local format = string.format

function util.init(config, libs)
    QA.prettyJson = util.prettyJson
end

function util.timerQueue()
    local queue,ref = {},0
    local function addTimer(id, t, fun, args)
        local i = 1
        while i <= #queue and queue[i].t <= t do i = i + 1 end
        ref = ref+1
        table.insert(queue, i, { id = id, t = t, fun = fun, args = args, ref = ref })
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
            if queue[i].ref == ref then table.remove(queue, i) return end
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
            if queue[i].id == id then table.remove(queue, i) 
            else i = i + 1 end
        end
        if queue[1] == nil then return nil end
        return queue[1].t, queue[1].fun, queue[1].args
    end
    return { add = addTimer, pop = popTimer, peek = peekTimer, remove = removeTimer, removeId = removeTimerId }
end

local COLORMAP = {
    black = "\027[30m",
    brown = "\027[31m",
    green = "\027[32m",
    orange = "\027[33m",
    navy = "\027[34m",
    purple = "\027[35m",
    teal = "\027[36m",
    grey = "\027[37m",
    gray = "\027[37m",
    red = "\027[31;1m",
    tomato = "\027[31;1m",
    neon = "\027[32;1m",
    yellow = "\027[33;1m",
    blue = "\027[34;1m",
    magenta = "\027[35;1m",
    cyan = "\027[36;1m",
    white = "\027[37;1m",
    darkgrey = "\027[30;1m",
}

local fibColors = { 
    ["SYS"] = 'brown', ["SYSERR"] = 'red', ["DEBUG"] = 'green', ["TRACE"] = 'blue', ["WARNING"] = 'orange', ["ERROR"] = 'red', ['TEXT'] = 'black'
}

local function html2color(str, startColor, dflTxt)
    local st, p = { startColor or COLORMAP[dflTxt or 'TEXT']}, 1
    return str:gsub("(</?font.->)", function(s)
        if s == "</font>" then
            p = p - 1; return st[p]
        else
            local color = s:match("color=([#%w]+)")
            color = COLORMAP[color] or (fibaro.colorMap[color] and COLORMAP[fibaro.colorMap[color] or dflTxt]) or COLORMAP['black']
            p = p + 1; st[p] = color
            return color
        end
    end)
end

function util.debug(flags,tag,str,typ)
    typ = typ:upper()
    str = flags.html and html2color(str, nil, fibColors['TEXT']) or
        str:gsub("(</?font.->)", "") -- Remove color tags
    str = str:gsub("(&nbsp;)", " ")  -- remove html space
    if flags.color then
        local txt_color = COLORMAP[(fibColors['TEXT'] or "black")]
        local typ_color = COLORMAP[(fibColors[typ] or "black")]
        print(format("%s%s [%s%-6s%s] [%-7s]: %s",
            txt_color, os.date("[%d.%m.%Y] [%H:%M:%S]"),
            typ_color, typ, txt_color,
            tag,
            str
        ))
    else
        print(format("%s [%s] [%s]: %s", os.date("[%d.%m.%Y] [%H:%M:%S]"), typ, tag, str))
    end
end

util.COLORMAP = COLORMAP
util.fibColors = fibColors

function util.base64encode(data)
    local bC='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x) 
            local r,b='',x:byte() for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
            return r;
          end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
          if (#x < 6) then return '' end
          local c=0
          for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
          return bC:sub(c+1,c+1)
        end)..({ '', '==', '=' })[#data%3+1])
  end

function util.basicAuthorization(user,password) return "Basic "..util.base64encode(user..":"..password) end

function util.toarray(t)
    local a = {}
    for k,v in pairs(t) do a[#a+1] = v end
    return a
end

local function copy(o)
    if type(o) ~= 'table' then return o end
    local res = {}
    for k, v in pairs(o) do res[k] = copy(v) end
    return res
end
util.copy = copy

function util.merge(a,b)
    local m,res = {},{}
    for _,v in ipairs(a) do m[v] = true end
    for _,v in ipairs(b) do m[v] = true end
    for k,_ in pairs(m) do res[#res+1] = k end
    return res
end

function util.append(a,b)
  local res = {}
  for _,v in ipairs(a) do res[#res+1] = v end
  for _,v in ipairs(b) do res[#res+1] = v end
  return res
end

do -- Used for print device table structs - sortorder for device structs
    local sortKeys = {
      'id','name','roomID','type','baseType','enabled','visible','isPlugin','parentId','viewXml','configXml',
      'interfaces','properties','view', 'actions','created','modified','sortOrder'
    }
    local sortOrder={}
    for i,s in ipairs(sortKeys) do sortOrder[s]="\n"..string.char(i+64).." "..s end
    local function keyCompare(a,b)
      local av,bv = sortOrder[a] or a, sortOrder[b] or b
      return av < bv
    end

    local function prettyJsonStruct(t0)
      local res = {}
      local function isArray(t) return type(t)=='table' and t[1] end
      local function isEmpty(t) return type(t)=='table' and next(t)==nil end
      local function printf(tab,fmt,...) res[#res+1] = string.rep(' ',tab)..format(fmt,...) end
      local function pretty(tab,t,key)
        if type(t)=='table' then
          if isEmpty(t) then printf(0,"[]") return end
          if isArray(t) then
            printf(key and tab or 0,"[\n")
            for i,k in ipairs(t) do
              local _ = pretty(tab+1,k,true)
              if i ~= #t then printf(0,',') end
              printf(tab+1,'\n')
            end
            printf(tab,"]")
            return true
          end
          local r = {}
          for k,_ in pairs(t) do r[#r+1]=k end
          table.sort(r,keyCompare)
          printf(key and tab or 0,"{\n")
          for i,k in ipairs(r) do
            printf(tab+1,'"%s":',k)
            local _ =  pretty(tab+1,t[k])
            if i ~= #r then printf(0,',') end
            printf(tab+1,'\n')
          end
          printf(tab,"}")
          return true
        elseif type(t)=='number' then
          printf(key and tab or 0,"%s",t)
        elseif type(t)=='boolean' then
          printf(key and tab or 0,"%s",t and 'true' or 'false')
        elseif type(t)=='string' then
          printf(key and tab or 0,'"%s"',t:gsub('(%")','\\"'))
        end
      end
      pretty(0,json.decode(t0),true)
      return table.concat(res,"")
    end
    util.prettyJson = prettyJsonStruct
  end

return util