fibaro.DECORATE = fibaro.DECORATE or {}

fibaro.DECORATE._ENCODE = json.encode
function fibaro.DECORATE._DEBUG(...)
  if fibaro.DECORATE_DEBUG then
    fibaro.trace(__TAG,...)
  end
end

local sortKeys = {"type","device","deviceID","id","value","oldValue","val","key","arg","event","events","msg","res"}
local sortOrder={}
for i,s in ipairs(sortKeys) do sortOrder[s]="\n"..string.char(i+64).." "..s end
local function keyCompare(a,b)
  local av,bv = sortOrder[a] or a, sortOrder[b] or b
  return av < bv
end

-- our own json encode, as we don't have 'pure' json structs, and sorts keys in order (i.e. "stable" output)
local function prettyJsonFlat(e0) 
  local res,seen = {},{}
  local function pretty(e)
    local t = type(e)
    if t == 'string' then res[#res+1] = '"' res[#res+1] = e res[#res+1] = '"'
    elseif t == 'number' then res[#res+1] = e
    elseif t == 'boolean' or t == 'function' or t=='thread' or t=='userdata' then res[#res+1] = tostring(e)
    elseif t == 'table' then
      if next(e)==nil then res[#res+1]='{}'
      elseif seen[e] then res[#res+1]="..rec.."
      elseif e[1] or #e>0 then
        seen[e]=true
        res[#res+1] = "[" pretty(e[1])
        for i=2,#e do res[#res+1] = "," pretty(e[i]) end
        res[#res+1] = "]"
      else
        seen[e]=true
        if e._var_  then res[#res+1] = format('"%s"',e._str) return end
        local k = {} for key,_ in pairs(e) do k[#k+1] = tostring(key) end
        table.sort(k,keyCompare)
        if #k == 0 then res[#res+1] = "[]" return end
        res[#res+1] = '{'; res[#res+1] = '"' res[#res+1] = k[1]; res[#res+1] = '":' t = k[1] pretty(e[t])
        for i=2,#k do
          res[#res+1] = ',"' res[#res+1] = k[i]; res[#res+1] = '":' t = k[i] pretty(e[t])
        end
        res[#res+1] = '}'
      end
    elseif e == nil then res[#res+1]='null'
    else error("bad json expr:"..tostring(e)) end
  end
  pretty(e0)
  return table.concat(res)
end
fibaro.DECORATE._ENCODEFAST = prettyJsonFlat

local function parseFun(name)
  local method = false
  local path = name:split(".")
  if path[#path]:match(':') then
    local m,n = path[#path]:match("(.-):(.+)")
    method = true
    path[#path] = m
    path[#path+1] = n
  end
  if #path == 1 then
    return _G[name],method,function(f) _G[name] = f end
  end
  local t = _G
  for _,s in ipairs(path) do
    t = t[s]
    if not t then break end
  end
  if not type(t)=='function' then fibaro.warning(__TAG,"No function found for "..name) end
  local function setter(f)
    local t = _G
    for i=1,#path-1 do
      t = t[path[i]]
    end
    t[path[#path]] = f
  end
  return t,method,setter
end

local function runHandlers(anots)
  for h,an in pairs(anots) do
    local handler = QuickApp[h.."_decorator"]
    if handler then
      for _,a in ipairs(an) do
        local f,method,setter = parseFun(a.info.name)
        a.info.method = method
        local afun = handler(quickApp,f,a.info,a.args)
        if afun then setter(afun) end
      end
    else 
      fibaro.warning(__TAG,"No handler for "..h)
    end
  end
end

local function parseAnnotations(file,anots)
  file:gsub("%c(%-%-@.-function%s+[%w_%.:]+%b())",
  function(m)
    local fun,argStr = m:match("function%s+([%w_%.:]+)(%b())")
    argStr = argStr:sub(2,-2)
    local args = {}
    argStr:gsub("([%w_]+),?",function(a) args[#args+1]=a end)
    local ca = nil
    m:gsub("(%-%-.-)\n",function(l) 
      local h,a = l:match("%-%-@([%w_]+):?(.-)\n")
      if h then
        if ca then
          anots[ca] = anots[ca] or {}
          local an = anots[ca]
          an[#an+1]={args=argStr,info={name=fun,args=args}}
        end
        ca = h
      elseif ca then
        local a = l:match("%-%-(.-)\n")
        local an = anots[ca]
        an.extra = an.extra or {}
        an.extra[#an.extra+1] = a
      end
    end)
    m:gsub("%-%-@([%w_]+):?(.-)\n",function(h,a) 
      anots[h] = anots[h] or {}
      local an = anots[h]
      an[#an+1]={args=a,info={name=fun,args=args}}
    end)
  end)
end

local function getAnnotations()
  local anots = {}
  local files = api.get("/quickApp/"..plugin.mainDeviceId.."/files")
  for _,f in ipairs(files) do
    local content = api.get("/quickApp/"..plugin.mainDeviceId.."/files/"..f.name).content
    parseAnnotations(content,anots)
  end
  return anots
end
local init = QuickApp.__init
function QuickApp:__init(device)
  quickApp = self
  local anots = getAnnotations()
  runHandlers(anots)
  init(self,device)
end
