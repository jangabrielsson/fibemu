--%%name=TestFS
--%%type=com.fibaro.binarySwitch
--%%fullLua=true

--%% f ile=/QuickApps/53 MyEventRunner4/fibaroExtra.lua,extra;

function QuickApp:onInit()
  io.write("Hello, World!\n")
  os.exit()
end

