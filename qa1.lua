function QuickApp:onInit()
    QuickApp:debug("Started",self.id)
    fibaro.createDevice("com.fibaro.binarySwitch",7000)
end
