--%%nameYahueV2
--%%type=com.fibaro.deviceController
--%%var=Hue_IP:config.Hue_IP
--%%var=Hue_User:config.Hue_user
--%%file=QAs/HueV2Engine.lua,HueEngine;
--%%file=dev/QwickAppChild.lua,Child;
--%%file=QAs/HueV2App.lua,App;
--%%file=QAs/HueV2Map.lua,Map;
--%%debug=refresh:false
--%%remote=globalVariables:HueScenes
--%%fullLua=true

fibaro.debugFlags = fibaro.debugFlags or {}
local HUE,update

local function init()
  local self = quickApp
  self:debug(HUE.appName,HUE.appVersion)

  fibaro.debugFlags.info=true
  fibaro.debugFlags.class=true
  fibaro.debugFlags.event=true
  fibaro.debugFlags.call=true
  local ip = self:getVariable("Hue_IP"):match("(%d+.%d+.%d+.%d+)")
  local key = self:getVariable("Hue_User") --:match("(.+)")
  assert(ip,"Missing Hue_IP - hub IP address")
  assert(key,"Missing Hue_User - Hue hub key")

  HUE:init(ip,key,function()
    --HUEv2Engine:dumpDevices()
    --HUE:dumpDeviceTable()
    --HUE:listAllDevicesGrouped()
    HUE:app()
    end)
end

function QuickApp:onInit()
  quickApp = self
  HUE = HUEv2Engine
  if not HUE then
    self:debug("Updating HueV2App")
    update()
    return
  else init() end
end

function update()
  local baseURL = "https://raw.githubusercontent.com/jangabrielsson/fibemu/master/"
  local file1 = baseURL.."QAs/HueV2Engine.lua"
  local file2 = baseURL.."QAs/HueV2App.lua"
  local function getFile(url,cont)
    net.HTTPClient():request(url,{
      options = { method = 'GET', checkCertificate=false, timeout=20000},
      success = function(resp)
        cont(resp.data)
      end,
      error = function(err)
        fibaro.error(__TAG,"Fetching GitHub files: "..err)
      end
    })
  end
  getFile(file1,function(data1)
    getFile(file2,function(data2)
      print("OK")
    end)
  end)
end