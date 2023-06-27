--%%remote=globalVariables:A,B
--%%remote=devices:763
--%%debug=permissions:false,refresh_resource:true

--%%file=../TQAE/lib/fibaroExtra.lua,fibaroExtra;

function QuickApp:onInit()
    self:debug("Started",self.id)
    IP = fibaro.getIPaddress()
    print(IP)
end