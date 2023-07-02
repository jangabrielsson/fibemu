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

local function callHC3(method, path, data, hc3)
    local lcl = hc3 ~= "hc3"
    local conf = fibaro and fibaro.config or QA.config
    local host = hc3 and conf.host or conf.whost
    local port = hc3 and conf.port or conf.wport
    local creds = hc3 and conf.creds or nil
    local url = fmt("http://%s:%s/api%s", host, port, path)
    if net._debugFlags.hc3_http then
        if fibaro then
            fibaro.trace(__TAG, fmt("HC3 %s: %s", method, url))
        else
            QA.syslog("HC3", "%s: %s", method, url)
        end
    end
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

function net.HTTPClient()
    local debugFlags = net._debugFlags or {}
    return {
        request = function(_, url, opts)
            if debugFlags.http and not url:match("/refreshStates") then
                fibaro.trace(__TAG, fmt("HTTPClient: %s", url))
            end
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
    self2.sock = net._createUDPSocket()
    if self2.opts.broadcast ~= nil then
        --self2.sock:bind("127.0.0.1", 0)
        self2.sock:setoption("broadcast", self2.opts.broadcast)
    end
    if tonumber(self2.opts.timeout) then
        self2.sock:settimeout(self2.opts.timeout)
    end

    function self2:bind(ip, port) self.sock:bind(ip, port) end

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
            if stat==0 and callbacks.success then
                pcall(callbacks.success, res, stat)
            elseif stat == 1 and callbacks.error then
                pcall(callbacks.error, res)
            end
        end
        self.sock:recieve(createCB(cb))
    end

    function self2:close() self.sock:close() end

    local pstr = "UDPSocket object: " .. tostring(self2):match("%s(.*)")
    setmetatable(self2, { __tostring = function(_) return pstr end })
    return self2
end

function net.WebSocketClient()
    local self = { _callback = {} }
    function self:connect(url, headers)
        local function cb(event, ...)
            local f = self._callback[event]
            if f then f(...) end
        end
        self._sock = net._createWebSocket(url, headers, createCB(cb))
    end

    function self:addEventListener(event, callback)
        self._callback[event] = callback
    end

    function self:send(data)
        return self._sock:send(data)
    end

    function self:isOpen() -- bool
        return self._sock:close()
    end

    function self:close()
        self._sock:close()
    end

    local pstr = "WebSocket object: " .. tostring(self):match("%s(.*)")
    setmetatable(self, { __tostring = function(_) return pstr end })
    return self
    -- self.sock:addEventListener("connected", function() self:handleConnected() end)
    -- self.sock:addEventListener("disconnected", function() self:handleDisconnected() end)
    -- self.sock:addEventListener("error", function(error) self:handleError(error) end)
    -- self.sock:addEventListener("dataReceived", function(data) self:handleDataReceived(data) end)
end

net.WebSocketClientTls = net.WebSocketClient -- only differ on URL?

local mqtt = {
    interval = 1000,
    Client = {},
    QoS = { EXACTLY_ONCE = 1 }
}
mqtt.MSGT = {
    CONNECT = 1,
    CONNACK = 2,
    PUBLISH = 3,
    PUBACK = 4,
    PUBREC = 5,
    PUBREL = 6,
    PUBCOMP = 7,
    SUBSCRIBE = 8,
    SUBACK = 9,
    UNSUBSCRIBE = 10,
    UNSUBACK = 11,
    PINGREQ = 12,
    PINGRESP = 13,
    DISCONNECT = 14,
    AUTH = 15,
}
mqtt.MSGMAP = {
    [9] = 'subscribed',
    [11] = 'unsubscribed',
    [4] = 'published', -- Should be onpublished according to doc?
    [14] = 'closed',
}

function mqtt.Client.connect(uri, options)
    options = options or {}
    local args = {}
    args.uri = uri
    args.uri = string.gsub(uri, "mqtt://", "")
    args.username = options.username
    args.password = options.password
    args.clean = options.cleanSession
    if args.clean == nil then args.clean = true end
    args.will = options.lastWill
    args.keep_alive = options.keepAlivePeriod
    args.id = options.clientId

    --cafile="...", certificate="...", key="..." (default false)
    if options.clientCertificate then -- Not in place...
        args.secure = {
            certificate = options.clientCertificate,
            cafile = options.certificateAuthority,
            key = "",
        }
    end

    local _client = net._mqttClient(args)
    local client = { _client = _client, _callbacks = {} }
    function client:addEventListener(message, handler)
        self._callbacks[message] = handler
    end

    function client:subscribe(topic, options)
        options = options or {}
        local args = {}
        args.topic = topic
        args.qos = options.qos or 0
        args.callback = options.callback
        return self._client:subscribe(args)
    end

    function client:unsubscribe(topics, options)
        if type(topics) == 'string' then
            return self._client:unsubscribe({ topic = topics })
        else
            local res
            for _, t in ipairs(topics) do res = self:unsubscribe(t) end
            return res
        end
    end

    function client:publish(topic, payload, options)
        options = options or {}
        local args = {}
        args.topic = topic
        args.payload = payload
        args.qos = options.qos or 0
        args.retain = options.retain or false
        args.callback = options.callback
        return self._client:publish(args)
    end

    function client:disconnect(options)
        options = options or {}
        local args = {}
        args.callback = options.callback
        return self._client:disconnect(args)
    end

    --function client:acknowledge() end
    local function DEBUG(a,b,c) end
    local function encode(t) return t and json.encode(t) or "nil" end
    local function safeJson(t) return t and json.encode(t) or "nil" end
    
    _client:on {
        --{"type":2,"sp":false,"rc":0}
        connect = function(connack)
            DEBUG("mqtt", "trace", "MQTT connect:" .. encode(connack))
            if client._handlers['connected'] then
                client._handlers['connected']({ sessionPresent = connack.sp, returnCode = connack.rc })
            end
        end,
        subscribe = function(event)
            DEBUG("mqtt", "trace", "MQTT subscribe:" .. encode(event))
            if client._handlers['subscribed'] then client._handlers['subscribed'](safeJson(event)) end
        end,
        unsubscribe = function(event)
            DEBUG("mqtt", "trace", "MQTT unsubscribe:" .. encode(event))
            if client._handlers['unsubscribed'] then client._handlers['unsubscribed'](safeJson(event)) end
        end,
        message = function(msg)
            DEBUG("mqtt", "trace", "MQTT message:" .. encode(msg))
            local msgt = mqtt.MSGMAP[msg.type]
            if msgt and client._handlers[msgt] then
                client._handlers[msgt](msg)
            elseif client._handlers['message'] then
                client._handlers['message'](msg)
            end
        end,
        acknowledge = function(event)
            DEBUG("mqtt", "trace", "MQTT acknowledge:" .. encode(event))
            if client._handlers['acknowledge'] then client._handlers['acknowledge']() end
        end,
        error = function(err)
            DEBUG("mqtt", "error", "MQTT error:" .. err)
            if client._handlers['error'] then client._handlers['error'](err) end
        end,
        close = function(event)
            DEBUG("mqtt", "trace", "MQTT close:" .. encode(event))
            event = safeJson(event)
            if client._handlers['closed'] then client._handlers['closed'](safeJson(event)) end
        end,
        auth = function(event)
            DEBUG("mqtt", "trace", "MQTT auth:" .. encode(event))
            if client._handlers['auth'] then client._handlers['auth'](safeJson(event)) end
        end,
    }

    local pstr = "MQTT object: " .. tostring(client):match("%s(.*)")
    setmetatable(client, { __tostring = function(_) return pstr end })

    return client
end

api = {
    get = function(url, hc3) return callHC3("GET", patch(url), nil, hc3) end,
    post = function(url, data, hc3) return callHC3("POST", url, data, hc3) end,
    put = function(url, data, hc3) return callHC3("PUT", url, data, hc3) end,
    delete = function(url, data, hc3) return callHC3("DELETE", url, data, hc3) end,
}
