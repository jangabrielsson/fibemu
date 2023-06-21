--%%name=FibEmuTester
--%%type=com.fibaro.binarySwitch
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

    -- self:testGlobalVariables()
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

local testContent = [[
    function QuickApp:hello()
        local str = "Hello from file 'new'"
        self:debug(str)
        return str
    end
]]

function QuickApp:testQA()
    -- print("Calling testQA")
    -- local res,code = api.post("/devices/"..self.id.."/action/testQA_fun",{args={ "A",  "B" }})
    -- print(json.encode({code,res}))
    -- fibaro.call(self.id,"testQA_fun","C","D")
    -- self:registerUICallback("test", "onReleased", "testQA_button")
    -- fibaro.callUI(self.id,"onReleased","test")
    -- self:setVariable("test",{42})
    -- local val = self:getVariable("test")
    -- printf("Variable 'test' = %s",json.encode(val))

    -- res,code = api.get("/quickApp/"..self.id.."/files/main")
    -- print("file",res.name,"found")
    -- res,code = api.get("/quickApp/"..self.id.."/files/new")
    -- if code ~= 200 then
    --     print("file 'new' not found, code",code)
    --     local file = {isMain=false,type='lua',isOpen=false,name="new",content=testContent}
    --     res,code = api.post("/quickApp/"..self.id.."/files",file)
    --     print("Adding file 'new', code",code)
    -- else
    --     print("file 'new' found, code",code)
    --     self:hello()
    -- end

    local rid = 1090
    local fqa,code = api.get("/quickApp/export/"..rid)
    if code == 200 then
        print("exported fqa",rid)
        local res,code = api.post("/quickApp/import",{file=json.encode(fqa)})
        print("imported fqa",rid)
    end
    setTimeout(function()
        fibaro.call(5001,"test",42,8)
    end,1000)
end
