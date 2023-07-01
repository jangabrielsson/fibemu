
--%%name=HTTP Test
--%%type=com.fibaro.binarySwitch

function QuickApp:onInit()
    self:debug("Started",self.id)
    
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
end