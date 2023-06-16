
 a = 0

function QuickApp:onInit()
    QuickApp:debug("Started",self.id)

    local gs = api.get("/globalVariables")

    local function loop(str)
        local function loop1()
            QuickApp:debug("Loop",str,a)
            a = a+1
            setTimeout(loop1,1000,str)
        end
        loop1()
    end

    loop("A")
    loop("B")
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
end

--foo()

function QuickApp:test()
    QuickApp:debug("Test pressed")
end

function QuickApp:foo(a,b)
    QuickApp:debug("Foo",a,b)
end
