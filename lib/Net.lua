local function base64encode(data)
  __assert_type(data,"string")
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
local function basicAuthorization(user,password) 
  return "Basic "..base64encode(user..":"..password) 
end

local IPaddress = nil
local function getIPaddress(name)
  if IPaddress then return IPaddress end
  if fibaro.fibemu then return fibaro.fibemu.config.host
  else
    name = name or ".*"
    local networkdata = api.get("/proxy?url=http://localhost:11112/api/settings/network")
    for n,d in pairs(networkdata.networkConfig or {}) do
      if n:match(name) and d.enabled then IPaddress = d.ipConfig.ip; return IPaddress end
    end
  end
end

local exports = {
  base64encode = base64encode,
  basicAuthorization = basicAuthorization,
  getIPaddress = getIPaddress,
}

-- export to net.*
for k,v in pairs(exports) do net[k]=v end