local function equal(e1,e2)
  if e1==e2 then return true
  else
    if type(e1) ~= 'table' or type(e2) ~= 'table' then return false
    else
      for k1,v1 in pairs(e1) do if e2[k1] == nil or not equal(v1,e2[k1]) then return false end end
      for k2,_  in pairs(e2) do if e1[k2] == nil then return false end end
      return true
    end
  end
end

local function copy(t) if type(t) ~= 'table' then return t end local r = {} for k,v in pairs(t) do r[k] = copy(v) end return r end
local function copyShallow(t) local r={} for k,v in pairs(t) do r[k]=v end return r end
local function append(t1,t2) local r=copyShallow(t1); for _,e in ipairs(t2) do r[#r+1]=e end return r end
local function maxn(t) local c=0 for _ in pairs(t) do c=c+1 end return c end
local function member(k,tab) for i,v in ipairs(tab) do if equal(v,k) then return i end end return false end
local function map(f,l,s) s = s or 1; local r,m={},maxn(l) for i=s,m do r[#r+1] = f(l[i]) end return r end
local function mapf(f,l,s) s = s or 1; local e=true for i=s,maxn(l) do e = f(l[i]) end return e end
local function delete(k,tab) local i = member(tab,k); if i then table.remove(tab,i) return i end end
local function mapAnd(f,l,s) s = s or 1; local e=true for i=s,table.maxn(l) do e = f(l[i]) if not e then return false end end return e end
local function mapOr(f,l,s) s = s or 1; for i=s,table.maxn(l) do local e = f(l[i]) if e then return e end end return false end
local function reduce(f,l) local r = {}; for _,e in ipairs(l) do if f(e) then r[#r+1]=e end end; return r end
local function membermap(list) local r = {}; for _,e in ipairs(list) do r[e]=true end; return r end
local function keys(list) local r = {}; for k,_ in pairs(list) do r[#r+1]=k end; return r end
local function values(list) local r = {}; for _,v in pairs(list) do r[#r+1]=v end; return r end
local function union(l1,l2) local r = membermap(l1); for _,e in ipairs(l2) do if not r[e] then r[e]=true end end; return keys(r) end
local function keyUnion(l1,l2) local r = copyShallow(l1); for k,v in pairs(l2) do r[k]=v end; return r end
local function intersection(l1,l2) local l,r = membermap(l1),{}; for _,e in ipairs(l2) do if r[e] then r[#r+1]=e end end; return r end
local function mapk(f,l) local r={}; for k,v in pairs(l) do r[k]=f(v) end; return r end
local function mapkv(f,l) local r={}; for k,v in pairs(l) do k,v=f(k,v) if k then r[k]=v end end; return r end
local function mapkl(f,l) local r={} for i,j in pairs(l) do r[#r+1]=f(i,j) end return r end

local function gensym(s) return (s or "G")..tostring({}):match("%s(.*)") end

local encode
do -- fastEncode
  local fmt = string.format
  local function encTsort(a,b) return a[1] < b[1] end
  local sortKeys = {"type","device","deviceID","id","value","oldValue","val","key","arg","event","events","msg","res"}
  local sortOrder,sortF={},nil
  for i,s in ipairs(sortKeys) do sortOrder[s]="\n"..string.char(i+64).." "..s end
  local function encEsort(a,b)
    a,b=a[1],b[1]; a,b = sortOrder[a] or a, sortOrder[b] or b
    return tostring(a) < tostring(b)
  end
  function table.maxn(t) local c=0 for _ in pairs(t) do c=c+1 end return c end
  local encT={}
  encT['nil'] = function(n,out) out[#out+1]='nil' end
  function encT.number(n,out) out[#out+1]=tostring(n) end
  function encT.userdata(u,out) out[#out+1]=tostring(u) end
  function encT.thread(t,out) out[#out+1]=tostring(t) end
  encT['function'] = function(f,out) out[#out+1]=tostring(f) end
  function encT.string(str,out) out[#out+1]='"' out[#out+1]=str out[#out+1]='"' end
  function encT.boolean(b,out) out[#out+1]=b and "true" or "false" end
  function encT.table(t,out,f)
    local mt = getmetatable(t) if mt and (not f) and mt.__tostring then return mt.__tostring(t) end
    if next(t)==nil then out[#out+1]= "{}" return -- Empty table
    elseif t[1]==nil then -- key value table
      local r = {}; for k,v in pairs(t) do r[#r+1]={k,v} end table.sort(r,sortF)
      out[#out+1]='{'
      local e = r[1]
      out[#out+1]=e[1]; out[#out+1]='='; encT[type(e[2])](e[2],out)
      for i=2,table.maxn(r) do local e = r[i]; out[#out+1]=','; out[#out+1]=e[1]; out[#out+1]='='; encT[type(e[2])](e[2],out) end
      out[#out+1]='}'
    else -- array table
      out[#out+1]='['
      encT[type(t[1])](t[1],out)
      for i=2,table.maxn(t) do out[#out+1]=',' encT[type(t[ i])](t[i],out) end
      out[#out+1]=']'
    end
  end
  
  function encode(o,sort,f)
    local out = {}
    sortF = (not sort) and encEsort or encTsort
    encT[type(o)](o,out,f)
    return table.concat(out)
  end
end

local exports = {
  equal = equal,
  copy = copy,
  copyShallow = copyShallow,
  append = append,
  maxn = table.maxn or maxn,
  member = member,
  map = map,
  mapf = mapf,
  delete = delete,
  mapAnd = mapAnd,
  mapOr = mapOr,
  reduce = reduce,
  membermap = membermap,
  keys = keys,
  values = values,
  union = union,
  keyUnion = keyUnion,
  intersection = intersection,
  mapk = mapk,
  mapkv = mapkv,
  mapkl = mapkl,
  gensym = gensym,
  encode = encode,
}

-- Export to table.*
for k,v in pairs(exports) do table[k] = v end
if json then json.encodeFast = encode end