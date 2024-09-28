--%%fullLua=true
--%%mergePath=lib/fibaroExtra/fibaroExtra_
--%%merge=base.lua,os.lua,climate.lua,cron.lua,customEvents.lua,debug.lua,error.lua,event.lua,globals.lua,hc3.lua,net.lua,profiles.lua,pubsub.lua,qa.lua,quickerChild.lua,rpc.lua,sun.lua,time.lua,trace.lua,triggers.lua,utilities.lua,weather.lua,lib/fibaroExtra/fibaroExtra.lua

local f = io.open("lib/fibaroExtra/fibaroExtra.lua","r")
local s = f:read("*a")
f:close()
s = s:split("\n")
local n,len = 1,#s
local out = {}
local function pr(fmt,...) out[#out+1] = fmt:format(...) end
while n <= len do
  local line = s[n]
  local tag = line:match("%-%-%-%-%-%-%- ([%w_%.]+)") 
  if tag then
    pr("%s",("-"):rep(40))
    pr("Module: %s",tag)
  end
  local exp = line:match("--Exported: (.+)")
  if exp then
    n = n+1
    local fun = s[n]:match("function%s*(.-%))")
    pr(" %s -- %s",fun,exp)
  end
  n = n+1
end
print(table.concat(out,"\n"))
