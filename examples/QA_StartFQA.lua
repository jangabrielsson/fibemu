--%%name=LoadFQA
--%%type=com.fibaro.binarySwitch

local HC3_deviceID = 1883
function QuickApp:onInit()
  local fqa =  api.get("/quickApp/export/"..HC3_deviceID,"hc3")
  fibaro.fibemu.installFQA(fqa)
  a=0
end