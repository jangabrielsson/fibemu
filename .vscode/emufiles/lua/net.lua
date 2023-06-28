local fmt = string.format 

net = {}

local apiPatches = {}

local function patch(url)
    for k,v in pairs(apiPatches) do
       url = url:gsub(k,v)
       end
   return url
end

function net._setupPatches(config)
    apiPatches[':11111/api/refreshStates'] = ":"..config.wport.."/api/refreshStates"
end

function net.HTTPClient()
    return {
        request = function(_, url, opts)
            url = patch(url)
            local options = (opts or {}).options or {}
            local data = options.data and json.encode(options.data) or nil
            local errH = opts.error
            local succH = opts.success
            local function callback(status, data, headers)
                if fibaro.__dead then return end
                local stat,res = pcall(function()
                    if status < 303 and succH and type(succH)=='function' then
                        succH({status=status, data=data ,headers=headers})
                    elseif errH and type(errH)=='function' then
                        errH(status, headers)
                    end
                end)
                if not stat then
                    fibaro.error(__TAG,"netClient callback:",res)
                end
            end
            local opts = {headers = options.headers or {}, callback = callback}
            return os.httpAsync(options.method or "GET", url, opts, data, false )
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
    get = function(url,hc3) return callHC3("GET", patch(url), nil, hc3) end,
    post = function(url, data, hc3) return callHC3("POST", url, data, hc3) end,
    put = function(url, data, hc3) return callHC3("PUT", url, data, hc3) end,
    delete = function(url, data, hc3) return callHC3("DELETE", url, data, hc3) end,
}