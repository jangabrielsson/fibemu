local fmt = string.format

net = {}

local apiPatches = {}

local function patch(url)
    for k, v in pairs(apiPatches) do
        url = url:gsub(k, v)
    end
    return url
end

function net._setupPatches(config)
    apiPatches[':11111/api/refreshStates'] = ":" .. config.wport .. "/api/refreshStates"
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
                local stat, res = pcall(function()
                    if status < 303 and succH and type(succH) == 'function' then
                        succH({ status = status, data = data, headers = headers })
                    elseif errH and type(errH) == 'function' then
                        errH(status, headers)
                    end
                end)
                if not stat then
                    fibaro.error(__TAG, "netClient callback:", res)
                end
            end
            local opts = { headers = options.headers or {}, callback = callback }
            return os.httpAsync(options.method or "GET", url, opts, data, false)
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
            ["Accept"] = '*/*',
            ["X-Fibaro-Version"] = "2",
            ["Fibaro-User-PIN"] = conf.pin,
            ["Content-Type"] = "application/json",
        }
    }
    local status, res, headers = os.http(method, url, options, data and json.encode(data) or nil, lcl)
    if status >= 303 then
        return nil, status
        --error(fmt("HTTP error %d: %s", status, res))
    end
    return res and type(res) == 'string' and res ~= "" and json.decode(res) or nil, status
end

function net.TCPSocket(opts2)
    local self2 = { opts = opts2 or {} }
    self2.sock = EM.socket.tcp()
    if EM.copas then
        self2.sock = EM.copas.wrap(self2.sock)
        if tonumber(opts2.timeout) then
            self2.sock:settimeout(opts2.timeout / 1000) -- timeout in ms
        end
    end
    function self2:connect(ip, port, opts)
        for k, v in pairs(self.opts) do opts[k] = v end
        local _, err = self.sock:connect(ip, port)
        if err == nil and opts and opts.success then
            opts.success()
        elseif opts and opts.error then
            opts.error(err)
        end
    end

    function self2:read(opts) -- I interpret this as reading as much as is available...?
        local data, res = {}
        local b, err = self.sock:receive(1)
        if not err then
            data[#data + 1] = b
            while EM.socket.select({ self.sock.socket }, nil, 0.1)[1] do
                b, err = self.sock:receive(1)
                if b then data[#data + 1] = b else break end
            end
            res = table.concat(data)
        end
        if res and opts and opts.success then
            opts.success(res)
        elseif res == nil and opts and opts.error then
            opts.error(err)
        end
    end

    local function check(data, del)
        local n = #del
        for i = 1, #del do if data[#data - n + i] ~= del:sub(i, i) then return false end end
        return true
    end
    function self2:readUntil(delimiter, opts) -- Read until the cows come home, or closed
        local data, ok, res = {}, true, nil
        local b, err = self.sock:receive(sock, 1)
        if not err then
            data[#data + 1] = b
            if not check(data, delimiter) then
                ok = false
                while true do
                    b, err = self.sock:receive(sock, 1)
                    if b then
                        data[#data + 1] = b
                        if check(data, delimiter) then
                            ok = true
                            break
                        end
                    else
                        break
                    end
                end -- while
            end
            if ok then
                for i = 1, #delimiter do table.remove(data, #data) end
                res = table.concat(data)
            end
        end
        if res and opts and opts.success then
            opts.success(res)
        elseif res == nil and opts and opts.error then
            opts.error(err)
        end
    end

    function self2.readUntil(_, delimiter, callbacks) end

    function self2:write(data, opts)
        local res, err = self.sock:send(data)
        if res and opts and opts.success then
            opts.success(res)
        elseif res == nil and opts and opts.error then
            opts.error(err)
        end
    end

    function self2:close() self.sock:close() end

    local pstr = "TCPSocket object: " .. tostring(self2):match("%s(.*)")
    setmetatable(self2, { __tostring = function(_) return pstr end })
    return self2
end

function net.UDPSocket(opts2)
    local self2 = { opts = opts2 or {} }
    self2.sock = EM.socket.udp()
    if self2.opts.broadcast ~= nil then
        self2.sock:setsockname(EM.IPAddress, 0)
        self2.sock:setoption("broadcast", self2.opts.broadcast)
    end
    if self2.opts.timeout ~= nil then self2.sock:settimeout(self2.opts.timeout / 1000) end

    function self2:sendTo(datagram, ip, port, callbacks)
        local stat, res = self.sock:sendto(datagram, ip, port)
        if stat and callbacks.success then
            pcall(callbacks.success, 1)
        elseif stat == nil and callbacks.error then
            pcall(callbacks.error, res)
        end
    end

    function self2:bind(ip, port) self.sock:setsockname(ip, port) end

    function self2:receive(callbacks)
        local stat, res = self.sock:receivefrom()
        if stat and callbacks.success then
            pcall(callbacks.success, stat, res)
        elseif stat == nil and callbacks.error then
            pcall(callbacks.error, res)
        end
    end

    function self2:close() self.sock:close() end

    local pstr = "UDPSocket object: " .. tostring(self2):match("%s(.*)")
    setmetatable(self2, { __tostring = function(_) return pstr end })
    return self2
end

api = {
    get = function(url, hc3) return callHC3("GET", patch(url), nil, hc3) end,
    post = function(url, data, hc3) return callHC3("POST", url, data, hc3) end,
    put = function(url, data, hc3) return callHC3("PUT", url, data, hc3) end,
    delete = function(url, data, hc3) return callHC3("DELETE", url, data, hc3) end,
}
