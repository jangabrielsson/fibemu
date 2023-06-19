--%%name=FibEmuTester
--%%type=com.fibaro.bianrySwitch
--%%file=qa3_1.lua,extra;

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

    self:testGlobalVariables()
    self:testQA()
end

function QuickApp:testGlobalVariables()
    api.post("/globalVariables",{ name = "A42", value = "B" })
    local val,t = fibaro.getGlobalVariable("A42")
    printf("Global 'A42' = %s (%s)",val,os.date('%c',t))
    t = os.milliclock()
    fibaro.setGlobalVariable("A42","C")
    printf("setGlobalVariable took %f",os.milliclock()-t)
    val,t = fibaro.getGlobalVariable("A42")
    printf("Global 'A42' = %s (%s)",val,os.date('%c',t))
    api.delete("/globalVariables/A42")
end

function QuickApp:testQA_fun(a,b) self:debug("testQA_fun",a,b) end
function QuickApp:testQA_button(a,b) self:debug("testQA_button pressed") end

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
end