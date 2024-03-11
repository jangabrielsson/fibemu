--%%name=TestFS
--%%type=com.fibaro.binarySwitch
--%%debug=refresh_resource:true
--%%remote=devices:1491

function QuickApp:fopp()
  print"fopp"
end

function QuickApp:onInit()
  fibaro.call(1491, "turnOn")
  fibaro.call(200, "turnOn")
  fibaro.call(5000, "fopp")
end



