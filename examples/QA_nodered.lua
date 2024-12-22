--%%name="NodeRed test"
--%%type="com.fibaro.binarySwitch"

QuickApp.EVENT = {}

function QuickApp:fromNodeRed(event)
  event = json.decode(event)
  event._from = nil
  event._IP = nil
  event._transID = nil
  if quickApp.EVENT[event.type] then
    quickApp.EVENT[event.type](quickApp,event)
  else
    print("Unknown event",json.encode(event))
  end
end

function fibaro.getIPaddress(name)
  if IPaddress then return IPaddress end
  if hc3_emulator then return hc3_emulator.IPaddress end
  if fibaro.fibemu then 
    return fibaro.fibemu.config.hostIP..":"..fibaro.fibemu.config.wport
  end
  name = name or ".*"
  local networkdata = api.get("/proxy?url=http://localhost:11112/api/settings/network")
  for n,d in pairs(networkdata.networkConfig or {}) do
    if n:match(name) and d.enabled then 
      IPaddress = d.ipConfig.ip
      return IPaddress 
    end
  end
end

local NRIP = "192.168.1.181"
local function send2NR(event,tag)
  local url = "http://"..NRIP..":1880/HC3"
  event._transID = tag or ""
  event._from = plugin.mainDeviceId
  event._IP = fibaro.getIPaddress()
  net.HTTPClient():request(url,{
    options = {
      method = 'POST',
      timeout = 4000,
      headers = {
        ['Content-Type'] = 'application/json',
        ['Accept']='application/json'
      },
      data = json.encode(event)
    },
    success = function(resp)
      if resp.status ~= 200 then
        fibaro.error(__TAG,"NodeRed",json.encode(resp))
      end
    end,
    error = function(err)
      fibaro.error(__TAG,"NodeRed",err)
    end
  })
end

function QuickApp:postNR(event) send2NR(event) end

function QuickApp:hueCmd(name,data)
  local event = {
    type = "hueCmd",
    name = name,
    data = data
  }
  self:postNR(event)
end

---------- QuickApp code starts here ----------

function QuickApp:onInit()
  self:postNR({type="echo",value=42})
  setTimeout(function()
    self:hueCmd('Right window',{on=false})
  end,5000)
  setTimeout(function()
    self:hueCmd('Right window',{on=true})
  end,10000)
end

function QuickApp.EVENT:echo(event)
  print("ECHO",json.encode(event))
end

function QuickApp.EVENT:ping(event)
  print("PING",os.date("%c",event.time//1000))
end

function QuickApp.EVENT:HueEvent(event)
  print("HUE",json.encode(event))
end