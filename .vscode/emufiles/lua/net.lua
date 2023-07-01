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
            local opts = {
                headers = options.headers or {},
                callback = callback,
                id = plugin.mainDeviceId or -1
            }
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

local function createCB(cb) return { callback = cb, id = plugin.mainDeviceId or -1 } end

function net.TCPSocket(opts2)
    local self2 = { opts = opts2 or {} }
    self2.sock = net._createTCPSocket()
    if tonumber(self2.opts.timeout) then
        self2.sock:settimeout(opts2.timeout) -- timeout in ms
    end
    function self2:connect(ip, port, opts)
        for k, v in pairs(self.opts) do opts[k] = v end
        local function cb(err, errstr)
            if err == 0 and opts and opts.success then
                opts.success()
            elseif opts and opts.error then
                opts.error(errstr)
            end
        end
        self2.sock:connect(ip, port, createCB(cb))
    end

    function self2:read(opts) -- I interpret this as reading as much as is available...?
        local function cb(err, res)
            if err == 0 and opts and opts.success then
                opts.success(res)
            elseif res == nil and opts and opts.error then
                opts.error(err)
            end
        end
        self2.sock:recieve(createCB(cb))
    end

    function self2:readUntil(delimiter, opts) -- Read until the cows come home, or closed
        assert(nil, "Not implemented")
        local function cb(res, err)
            if res and opts and opts.success then
                opts.success(res)
            elseif res == nil and opts and opts.error then
                opts.error(err)
            end
        end
        self2.sock:recieveUntil(delimiter, createCB(cb))
    end

    function self2:write(data, opts)
        local err, sent = self.sock:send(data)
        if err == 0 and opts and opts.success then
            opts.success(sent)
        elseif err == 1 and opts and opts.error then
            opts.error(sent)
        end
    end

    function self2:close() self.sock:close() end

    local pstr = "TCPSocket object: " .. tostring(self2):match("%s(.*)")
    setmetatable(self2, { __tostring = function(_) return pstr end })
    return self2
end

function net.UDPSocket(opts2)
    local self2 = { opts = opts2 or {} }
    self2.sock = net._createTCPSocket()
    if self2.opts.broadcast ~= nil then
        self2.sock:setsockname(EM.IPAddress, 0)
        self2.sock:setoption("broadcast", self2.opts.broadcast)
    end
    if tonumber(self2.opts.timeout) then
        self2.sock:settimeout(self2.opts.timeout)
    end

    function self2:bind(ip, port) self.sock:setsockname(ip, port) end

    function self2:sendTo(datagram, ip, port, callbacks)
        local stat, res = self.sock:sendto(datagram, ip, port)
        if stat and callbacks.success then
            pcall(callbacks.success, 1)
        elseif stat == nil and callbacks.error then
            pcall(callbacks.error, res)
        end
    end

    function self2:receive(callbacks)
        local function cb(stat, res)
            if stat and callbacks.success then
                pcall(callbacks.success, stat, res)
            elseif stat == nil and callbacks.error then
                pcall(callbacks.error, res)
            end
        end
        self.sock:receivefrom(createCB(cb))
    end

    function self2:close() self.sock:close() end

    local pstr = "UDPSocket object: " .. tostring(self2):match("%s(.*)")
    setmetatable(self2, { __tostring = function(_) return pstr end })
    return self2
end

function net.WebSocketClientTls()
    local POLLINTERVAL = 1000
    local conn, err, lt = nil
    local self2 = {}
    local handlers = {}
    local function dispatch(h, ...)
        if handlers[h] then
            h = handlers[h]
            local args = { ... }
            FB.setTimeout(function() h(table.unpack(args)) end, 0)
        end
    end
    local function listen()
        if not conn then return end
        local function loop()
            if lt == nil then return end
            websocket.wsreceive(conn)
            if lt then lt = EM.systemTimer(loop, POLLINTERVAL, "WebSocket") end
        end
        lt = EM.systemTimer(loop, 0, "WebSocket")
    end
    local function stopListen() if lt then
            EM.clearTimeout(lt)
            lt = nil
        end end
    local function disconnected()
        websocket.wsclose(conn)
        conn = nil; stopListen(); dispatch("disconnected")
    end
    local function connected()
        self2.co = true; listen(); dispatch("connected")
    end
    local function dataReceived(data) dispatch("dataReceived", data) end
    local function error(err2) dispatch("error", err2) end
    local function message_handler(conn2, opcode, data, ...)
        if not opcode then
            error(data)
            disconnected()
        else
            dataReceived(data)
        end
    end
    function self2:addEventListener(h, f) handlers[h] = f end

    function self2:connect(url, headers)
        if conn then return false end
        conn, err = websocket.wsopen(url, message_handler, { upgrade_headers = headers }) --options )
        if not err then
            connected(); return true
        else
            return false, err
        end
    end

    function self2:send(data)
        if not conn then return false end
        if not websocket.wssend(conn, 1, data) then return disconnected() end
        return true
    end

    function self2:isOpen() return conn and true end

    function self2:close() if conn then
            disconnected()
            return true
        end end

    local pstr = "WebSocket object: " .. tostring(self2):match("%s(.*)")
    setmetatable(self2, { __tostring = function(_) return pstr end })
    return self2
end

function net.WebSocketClient()
    local self = {}
    function self:connect(url)
        local function cb(event,...)
            local f = self._callback[event]
            if f then f(...) end
        end
        self._sock = net._createWebSocketClient(url,createCB(cb))
    end
    function self:addEventListener(event, callback)
        self._callback[event] = callback
    end
    -- self.sock:addEventListener("connected", function() self:handleConnected() end)
    -- self.sock:addEventListener("disconnected", function() self:handleDisconnected() end)
    -- self.sock:addEventListener("error", function(error) self:handleError(error) end)
    -- self.sock:addEventListener("dataReceived", function(data) self:handleDataReceived(data) end)
 
end

api = {
    get = function(url, hc3) return callHC3("GET", patch(url), nil, hc3) end,
    post = function(url, data, hc3) return callHC3("POST", url, data, hc3) end,
    put = function(url, data, hc3) return callHC3("PUT", url, data, hc3) end,
    delete = function(url, data, hc3) return callHC3("DELETE", url, data, hc3) end,
}
