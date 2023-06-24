--%%write=globalVariables["A","B","C"]
--%%write=devices[1000,763]
--%%write=deviceNames["AB","B"]

function QuickApp:onInit()
    QuickApp:debug("Started",self.id)
    fibaro.createDevice("com.fibaro.binarySwitch",7000)
    fibaro.call(7000,"turnOn")

    fibaro.call(763,"turnOff")
end
