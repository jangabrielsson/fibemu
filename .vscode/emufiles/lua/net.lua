local fmt = string.format 

net = {}

function net.HTTPClient()
    return {
        request = function(_, url, opts)
            local options = (opts or {}).options or {}
            local data = options.data and json.encode(options.data) or nil
            local status,res,headers = os.http(options.method or "GET", url, options, data, false )
            if status < 303 and opts.success and type(opts.success)=='function' then
                setTimeout(function() opts.success({status=status, data=res,headers=headers}) end,0)
            elseif opts.error and type(opts.error)=='function' then
                setTimeout(function() opts.error(status,headers) end,0)
            end
        end
    }
end

local function callHC3(method, path, data, hc3)
    local lcl = hc3 ~= "hc3"
    local conf = fibaro and fibaro.config or QA.config
    local host = hc3 and conf.host or conf.whost
    local port = hc3 and conf.port or conf.wport
    local creds = hc3 and conf.creds or nil
    local url = fmt("http://%s:%s/api%s", host, port, path)
    local options = { 
        headers = {
            ['Authorization'] = creds,
            ["Accept"] = '*/*', ["X-Fibaro-Version"] = "2", ["Fibaro-User-PIN"] = conf.pin,
            ["Content-Type"] = "application/json",
        }
    }
    local status, res, headers = os.http(method, url, options, data and json.encode(data) or nil, lcl)
    if status >= 303 then
        return nil,status
        --error(fmt("HTTP error %d: %s", status, res))
    end
    return res and type(res)=='string' and res~="" and json.decode(res) or nil,status
end

api = {
    get = function(url,hc3) return callHC3("GET", url, nil, hc3) end,
    post = function(url, data, hc3) return callHC3("POST", url, data, hc3) end,
    put = function(url, data, hc3) return callHC3("PUT", url, data, hc3) end,
    delete = function(url, data, hc3) return callHC3("DELETE", url, data, hc3) end,
}