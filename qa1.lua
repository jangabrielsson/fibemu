--%%write=globalVariables:A,B
--%%write=devices:763
--%%shadow=weather:*
--%%debug=permissions:false,refresh_resource:true

function QuickApp:onInit()
    QuickApp:debug("Started",self.id)
    -- fibaro.createDevice("com.fibaro.binarySwitch",7000)
    -- fibaro.call(7000,"turnOn")

    -- api.get("/globalVariables/A")
    -- api.get("/devices/99") 
    -- api.get("/rooms/55")
    -- api.get("/sections")
    -- api.get("/customEvents")
    -- api.get("/settings/location")
    -- api.get("/settings/info")
    -- api.get("/settings/led")
    -- api.get("/settings/network")
    -- api.get("/alarms/v1/partitions")
    -- print(json.encode((api.get("/alarms/v1/partitions/1"))))
    -- api.get("/alarms/v1/devices")
    -- api.get("/notificationCenter")
    -- api.get("/profiles")
    -- api.get("/users")
    -- api.get("/icons")
    -- api.get("/weather")
    -- api.get("/debugMessages")
    -- api.get("/home")
    -- api.get("/iosDevices")
    -- api.get("/energy/devices")
    -- api.get("/panels/location")
    -- api.get("/panels/notifications")
    -- --api.get("/panels/family")
    -- api.get("/panels/sprinklers")
    -- api.get("/panels/humidity']")
    -- api.get("/panels/favoriteColors")
    -- api.get("/diagnostics")
    -- api.get("/sortOrder")
    -- api.get("/loginStatus")
    -- api.get("/RGBprograms")

    api.put("/weather", { Temperature = 20.25 })
    -- local a = fibaro.getGlobalVariable("A")
    -- print("A=",a)
    -- a,b = fibaro.setGlobalVariable("A","E3")
    -- print(json.encode({a or "nil",b}))
    -- a = fibaro.getGlobalVariable("A")
    -- print("A=",a)
end
