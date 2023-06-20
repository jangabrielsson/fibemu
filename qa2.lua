
--%%name=Test
--%%type=com.fibaro.binarySwitch
 
 a = 0

function QuickApp:onInit()
    QuickApp:debug("Started",self.id)
    print("CONF",json.encode(fibaro.config))
    local gs = api.get("/globalVariables")
    print("#vars = ",#gs)
    --jkjkjk()
    local function loop(str,delay)
        local function loop1()
            QuickApp:debug("Loop",str,a)
            a = a+1
            setTimeout(loop1,delay,str)
        end
        loop1()
    end

   loop("A",2000)
   loop("B",2500)
    setTimeout(function()
        fooo()
    end,2000)
    
    net.HTTPCall():request("http://worldtimeapi.org/api/timezone/Europe/Stockholm",{
        options = {
            method = "GET",
            headers = {
                ["Accept"] = "application/json"
            }
        }, 
        success = function(response)
            self:debug("Response",response.data)
        end,
        error = function(err)
            self:error("Error",err)
        end
    })

    local val,t = fibaro.getGlobalVariable("A")
    self:debug("Global variable 'A'=",val,os.date("%c",t))
end

--foo()

function QuickApp:test()
    QuickApp:debug("Test pressed")
end

function QuickApp:foo(a,b)
    QuickApp:debug("Foo",a,b)
end
