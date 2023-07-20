
--%%name=HTTP Test
--%%type=com.fibaro.binarySwitch
--%%debug=http:true,hc3_http:true,dark:true,callstack:true
function foo()
    bar()
end

function bar() error("OK") end

function QuickApp:onInit()
    self:debug("Started",self.id)
    foo()
    net.HTTPClient():request("http://worldtimeapi.org/api/timezone/Europe/Stockholm",{
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
    print("HTTP called") -- async, so we get answer later

    fibaro.call(self.id,"turnOn")
end

function QuickApp:turnOn()
    self:debug("Turned on")
end