local fmt = string.format

local r = {}

function r.start(config)
     local url = fmt("http://%s:%s/api/refreshStates?lang=en&rand=0.09580020181569104&logs=false&last=",config.host,config.port)
        local options = {
            headers = {
                ['Authorization'] = config.creds,
                ["Accept"] = '*/*', ["X-Fibaro-Version"] = "2", ["Fibaro-User-PIN"] = config.pin,
                ["Content-Type"] = "application/json",
            }
        }
    __REFRESH(true, url, options)
end

return r