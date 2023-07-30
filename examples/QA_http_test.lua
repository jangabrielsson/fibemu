--%%name=HTTP Test
--%%type=com.fibaro.binarySwitch
--%%debug=http:true,hc3_http:true,dark:true,callstack:true
--%%debug=logFilters:{"DeviceActionRanEvent"}

local function http(method,url,data)
    print("OK",method,url)
    net.HTTPClient():request(url,{
        options = {
            method = method,
            headers = {
                ["Accept"] = "*/*",
                ["Content-Type"] = "application/json; utf-8",
            },
            data = data and json.encode(data) or nil
        },
        success = function(response)
            print("Response",response.data)
        end,
        error = function(err)
            print("Error2",url,err)
        end
    })
    print("HTTP called") -- async, so we get answer later
end

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
            self:error("Error3",err)
        end
    })
    print("HTTP called") -- async, so we get answer later
end

http("POST","https://httpbin.org/anything",{a=1,b=2}) -- This is slow - can take >10s to complete

function QuickApp:turnOn()
    print("Turned on")
end