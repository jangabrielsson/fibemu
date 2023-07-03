--%%name=API Test

--%%remote=globalVariables:A,B
--%%remote=devices:763
--%%debug=permissions:false,refresh_resource:true

local function printf(fmt,...) print(string.format(fmt,...)) end
function QuickApp:onInit()
    quickApp = self
    self:debug("QA name",self.name,"id",self.id,"type",self.type)
    self:trace("Trace message")
    self:warning("Warning message")
    self:error("Error message") 
    self:debug("fibaro.config")
    for k,v in pairs(fibaro.config) do
        printf("   %s=%s",k,json.encode(v))
    end

    self:testAPI()
    self:testGlobalVariables()
    self:testRooms()
    self:testSections()
    self:testCustomEvents()
    self:testDevices()

    self:testQA()
end

function QuickApp:testAPI()

    api.get("/globalVariables/A")
    api.get("/devices/99") 
    api.get("/rooms/55")
    api.get("/sections")
    api.get("/customEvents")
    api.get("/settings/location")
    api.get("/settings/info")
    api.get("/settings/led")
    api.get("/settings/network")
    api.get("/alarms/v1/partitions")
    print(json.encode((api.get("/alarms/v1/partitions/1"))))
    api.get("/alarms/v1/devices")
    api.get("/notificationCenter")
    api.get("/profiles")
    api.get("/users")
    api.get("/icons")
    api.get("/weather")
    api.get("/debugMessages")
    api.get("/home")
    api.get("/iosDevices")
    api.get("/energy/devices")
    api.get("/panels/location")
    api.get("/panels/notifications")
    --api.get("/panels/family")
    api.get("/panels/sprinklers")
    api.get("/panels/humidity']")
    api.get("/panels/favoriteColors")
    api.get("/diagnostics")
    -- api.get("/sortOrder")
    -- api.get("/loginStatus")
    -- api.get("/RGBprograms")

    api.put("/weather", { Temperature = 20.25 })
end

function QuickApp:testGlobalVariables()
    api.post("/globalVariables",{ name = "A42", value = "B" })
    local val,t = fibaro.getGlobalVariable("A42")
    printf("Global 'A42' = %s (%s)",val,os.date('%c',t))
    t = fibaro.pyhooks.clock()
    fibaro.setGlobalVariable("A42","C")
    printf("setGlobalVariable took %f",fibaro.pyhooks.clock()-t)
    val,t = fibaro.getGlobalVariable("A42")
    printf("Global 'A42' = %s (%s)",val,os.date('%c',t))
    api.delete("/globalVariables/A42")
end

function QuickApp:testRooms()
    local room,code = api.post("/rooms",{ name = "roomA" })
    print(fibaro.getRoomName(room.id))
    room,code = api.put("/rooms/"..room.id,{ name = "roomB" })
    print(fibaro.getRoomName(room.id))
    api.delete("/rooms/"..room.id)
end

function QuickApp:testSections()
    local section,code = api.post("/sections",{ name = "sectionA" })
    local val = api.get("/sections/"..section.id)
    print(val.name)
    local section,code = api.put("/sections/"..section.id,{ name = "sectionB" })
    val = api.get("/sections/"..section.id)
    print(val.name)
    api.delete("/sections/"..section.id)
end

function QuickApp:testCustomEvents()
    local ce,code = api.post("/customEvents",{ name = "eventA" })
    local val = api.get("/customEvents/"..ce.name)
    print(val.name)
    ce,code = api.put("/customEvents/"..ce.name,{ name = "eventB" })
    val,code = api.get("/customEvents/eventB")
    print(val.name)
    api.post("/customEvents/eventB")
    api.delete("/customEvents/"..ce.name)
end

function QuickApp:testDevices()
end

function QuickApp:testQA_fun(a,b) self:debug("testQA_fun",a,b) end
function QuickApp:testQA_button(a,b) self:debug("testQA_button pressed") end

local testContent = [[
    function QuickApp:hello()
        local str = "Hello from file 'new'"
        self:debug(str)
        return str
    end
]]

function QuickApp:testQA()
    print("Calling testQA")
    local res,code = api.post("/devices/"..self.id.."/action/testQA_fun",{args={ "A",  "B" }})
    print(json.encode({code,res}))
    fibaro.call(self.id,"testQA_fun","C","D")
    self:registerUICallback("test", "onReleased", "testQA_button")
    fibaro.callUI(self.id,"onReleased","test")
    self:setVariable("test",{42})
    local val = self:getVariable("test")
    printf("Variable 'test' = %s",json.encode(val))

    res,code = api.get("/quickApp/"..self.id.."/files/main")
    print("file",res.name,"found")
    res,code = api.get("/quickApp/"..self.id.."/files/new")
    if code ~= 200 then
        print("file 'new' not found, code",code)
        local file = {isMain=false,type='lua',isOpen=false,name="new",content=testContent}
        res,code = api.post("/quickApp/"..self.id.."/files",file)
        print("Adding file 'new', code",code)
    else
        print("file 'new' found, code",code)
        self:hello()
        return
    end

    local rid = 1090
    local fqa,code = api.get("/quickApp/export/"..rid)
    if code == 200 then
        print("exported fqa",rid)
        local res,code = api.post("/quickApp/import",{file=json.encode(fqa)})
        print("imported fqa",rid)

        setTimeout(function()
            fibaro.call(5001,"test",42,8)
        end,1000)
        
    else
        print("fqa",rid,"not found, code",code)
    end
end
