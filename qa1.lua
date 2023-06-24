--%%write=globalVariables["A","B","C"]
--%%write=devices[763]

function QuickApp:onInit()
    QuickApp:debug("Started",self.id)
    fibaro.createDevice("com.fibaro.binarySwitch",7000)
    fibaro.call(7000,"turnOn")

    fibaro.call(763,"turnOff")
end
