local fmt = string.format
local HC3_TIMEOUT = 5
net = {}

local apiPatches = {}
local tostring = tostring 

local function patch(url)
    for k, v in pairs(apiPatches) do
        url = url:gsub(k, v)
    end
    return url
end

function net._setupPatches(config)
    apiPatches[':11111/api/refreshStates'] = ":" .. config.wport .. "/api/refreshStates"
    apiPatches['/localhost/'] = "/" .. config.host .. "/"
end

local http_hooks
function net.HTTPIntercept(ip,fun)
    http_hooks = http_hooks or {}
    http_hooks[ip] = fun
end
local function httpMatch(url,opts)
    local ip,path = url:match("https?://([^/]+)(.*)")
    ip = ip or ""
    local method = opts.options and opts.options.method or "GET"
    if http_hooks and http_hooks[ip] then
        local res,code = http_hooks[ip](method,path,opts)
        if code < 300 then
            if opts.success then 
                setTimeout(function() opts.success({status=code,data=json.encode(res)}) end,0)
            end
        elseif opts.error then
            setTimeout(function() opts.error(code) end,0)
        end
        return true
    end
end

local function callHC3(method, path, data, hc3)
    local lcl = hc3 ~= "hc3"
    local fibemu = fibaro and fibaro.fibemu and fibaro.fibemu.config and fibaro.fibemu or QA
    local conf = fibemu.config
    for p,_ in pairs( fibemu.passThrough or {}) do
        if path:match(p) then
            hc3,lcl = true,false
            break
        end
    end
    local host = hc3 and conf.host or conf.whost
    local port = hc3 and conf.port or conf.wport
    local creds = hc3 and conf.creds or nil
    local url = fmt("http://%s:%s/api%s", host, port, path)
    if fibemu.debugFlags.hc3_http and not path=="/globalVariables/FIBEMU" then
        fibemu.syslog(__TAG or "HC3", "%s: %s", method, url)
    end
    local options = {
        timeout = HC3_TIMEOUT,
        headers = {
            ['Authorization'] = creds,
            ["Accept"] = '*/*',
            ["X-Fibaro-Version"] = "2",
            ["Fibaro-User-PIN"] = conf.pin,
            ["Content-Type"] = "application/json; charset=utf-8",
        }
    }
    if url:match("/quickApp/") then -- Issue with empty arrays...
        data = data and json.encode2(data) or nil
    else
        data = data and json.encode2(data) or nil
    end
    local status, res, headers = fibemu.pyhooks.http(method, url, options, data or nil, lcl)
    if status >= 303 then
        return nil, status, res, headers
        --error(fmt("HTTP error %d: %s", status, res))
    end
    return res and type(res) == 'string' and res ~= "" and json.decode(res) or nil, status, headers
end

function net.HTTPClient(opts)
    opts = opts or {}
    local fibemu = fibaro and fibaro.fibemu or QA
    local debugFlags = fibemu.debugFlags or {}
    local util = fibemu.libs.util
    local timeout = opts.timeout
    local epcall = util.epcall
    local self2 = {
        request = function(_, url, opts)
            local ctx = util.getErrCtx(3)
            if debugFlags.http and not url:match("/refreshStates") then
                fibemu.syslog(__TAG, "HTTPClient: %s", url)
            end
            url = patch(url)
            if  http_hooks and httpMatch(url,opts) then return end
            local options = (opts or {}).options or {}
            local data = options.data or nil
            local errH = opts.error
            local succH = opts.success
            local function callback(status, data, headers)
                if fibaro.__dead then return end
                epcall(fibaro,__TAG,"netClient callback",true,ctx,function()
                    if status < 303 and succH and type(succH) == 'function' then
                        succH({ status = status, data = data, headers = headers })
                    elseif errH and type(errH) == 'function' then
                        errH(status, headers)
                    end
                end)
            end
            local opts = {
                headers = options.headers or {},
                timeout = options.timeout and options.timeout/1000 or timeout and timeout/1000 or nil,
                callback = callback,
                checkCertificate = options.checkCertificate,
                id = plugin.mainDeviceId or -1
            }
            return fibemu.pyhooks.httpAsync(options.method or "GET", url, opts, data, false)
        end
    }
    local pstr = "HTTPClient object: " .. tostring({}):match("%s(.*)")
    setmetatable(self2, { __tostring = function(_) return pstr end })
    return self2
end

local function createCB(cb) return { callback = cb, id = plugin.mainDeviceId or -1 } end
local function callback(f,...)
    local stat,res = pcall(f,...)
    if not stat then
        fibaro.fibemu.syslogerr(__TAG, "netClient callback: %s", res)
    end
end

function net.TCPSocket(opts2)
    local self2 = { opts = opts2 or {} }
    local fibemu = fibaro and fibaro.fibemu or QA
    self2.sock = fibemu.pyhooks.createTCPSocket()
    if tonumber(self2.opts.timeout) then
        self2.sock:settimeout(opts2.timeout) -- timeout in ms
    end
    function self2:connect(ip, port, opts)
        for k, v in pairs(self.opts) do opts[k] = v end
        local function cb(err, errstr)
            if err == 0 and opts and opts.success then
                callback(opts.success)
            elseif opts and opts.error then
                callback(opts.error,errstr)
            end
        end
        self2.sock:connect(ip, port, createCB(cb))
    end

    function self2:read(opts) -- I interpret this as reading as much as is available...?
        local function cb(err, res)
            if err == 0 and opts and opts.success then
                local msg = string.char(table.unpack(res))
                callback(opts.success,msg)
            elseif res == nil and opts and opts.error then
                callback(opts.error,err)
            end
        end
        self2.sock:recieve(createCB(cb))
    end

    function self2:readUntil(delimiter, opts) -- Read until the cows come home, or closed
        assert(nil, "Not implemented")
        local function cb(res, err)
            if res and opts and opts.success then
                local msg = string.char(table.unpack(res))
                callback(opts.success,msg)
            elseif res == nil and opts and opts.error then
                callback(opts.error,err)
            end
        end
        self2.sock:recieveUntil(delimiter, createCB(cb))
    end

    function self2:write(data, opts)
        data = {string.byte(data,1,-1)}
        local err, sent = self.sock:send(data)
        if err == 0 and opts and opts.success then
            setTimeout(function() callback(opts.success,sent) end,0)
        elseif err == 1 and opts and opts.error then
            setTimeout(function() callback(opts.error,sent) end,0)
        end
    end

    function self2:close() self.sock:close() end

    local pstr = "TCPSocket object: " .. tostring(self2):match("%s(.*)")
    setmetatable(self2, { __tostring = function(_) return pstr end })
    return self2
end

function net.UDPSocket(opts2)
    local self2 = { opts = opts2 or {} }
    self2.sock = fibaro.fibemu.pyhooks.createUDPSocket()
    if tonumber(self2.opts.timeout) then
        self2.sock:settimeout(self2.opts.timeout)
    end
    if self2.opts.broadcast ~= nil then
        --self2.sock:bind("127.0.0.1", 0)
        self2.sock:setoption("broadcast", self2.opts.broadcast)
    end
    if self2.opts.reuseport ~= nil then
        --self2.sock:bind("127.0.0.1", 0)
        self2.sock:setoption("reuseport", self2.opts.reuseport)
    end
    if self2.opts.reuseaddrt ~= nil then
        --self2.sock:bind("127.0.0.1", 0)
        self2.sock:setoption("reuseaddr", self2.opts.reuseaddr)
    end
    function self2:setsockname(ip, port)
        local stat, err = self.sock:setsockname(ip, port)
        if stat ~= 0 then error(err, 2) end
    end
    function self2:bind(ip, port)
        local stat, err = self.sock:bind(ip, port)
        if stat ~= 0 then error(err, 2) end
    end

    function self2:sendTo(datagram, ip, port, callbacks)
        local function cb(stat,res,e)
            if callbacks and stat == 0 and callbacks.success then
                callback(callbacks.success, res)
            elseif callbacks and stat == 1 and callbacks.error then
                callback(callbacks.error, res)
            end
        end
        self.sock:sendto({string.byte(datagram,1,-1)}, ip, port, createCB(cb))
    end

    function self2:receive(callbacks)
        local function cb(stat, res, ip, port)
            if callbacks and stat == 0 and callbacks.success then
                local msg = string.char(table.unpack(res))
                callback(callbacks.success, msg, ip, port)
            elseif callbacks and stat == 1 and callbacks.error then
                callback(callbacks.error, res)
            end
        end
        self.sock:recieve(createCB(cb))
    end

    function self2:close() self.sock:close() end

    local pstr = "UDPSocket object: " .. tostring(self2):match("%s(.*)")
    setmetatable(self2, { __tostring = function(_) return pstr end })
    return self2
end

function net.WebSocketClient(opts)
    local self = { _callback = {} }
    function self:connect(url, headers)
        local function cb(event, ...)
            local f = self._callback[event]
            if f then f(...) end
        end
        if headers then headers = json.encode(headers) end
        self._sock = fibaro.fibemu.pyhooks.createWebSocket(url, headers, createCB(cb))
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

mqtt = {
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
    --local host, port = string.match(args.uri, "([^:]+):?(%d*)")
    args.host = args.uri
    args.port = tonumber(options.port) or 1883
    args.username = options.username
    args.password = options.password
    args.cleansession = options.cleanSession
    if args.cleanSession == nil then args.cleanSession = true end
    args.lastWill = options.lastWill
    args.keep_alive = options.keepAlivePeriod
    args.clientId = options.clientId

    --cafile="...", certificate="...", key="..." (default false)
    if options.clientCertificate then -- Not in place...
        args.secure = {
            certificate = options.clientCertificate,
            cafile = options.certificateAuthority,
            key = "",
        }
    end

    local client,chandlers
    local function cb(event, ...)
        local args = {...}
        local f = chandlers[event]
        if f then f(table.unpack(args)) end
    end
    local args2 = json.encode(args)
    local _client = fibaro.fibemu.pyhooks.createMQTTClient(args2,createCB(cb))
    client = { _client = _client, _callbacks = {} }
    function client:addEventListener(message, handler)
        self._callbacks[message] = handler
    end

    function client:subscribe(topic, options)
        return self._client:subscribe(topic, options)
    end

    function client:unsubscribe(topics, options)
        if type(topics) == 'string' then
            return self._client:unsubscribe(topics)
        else
            local res
            for _, t in ipairs(topics) do res = self:unsubscribe(t) end
            return res
        end
    end

    function client:publish(topic, payload, options)
        return self._client:publish(topic,payload)
    end

    function client:disconnect(options)
        options = options or {}
        local args = {}
        args.callback = options.callback
        return self._client:disconnect(args)
    end

    --function client:acknowledge() end
    local function DEBUG(a, b, c) print(a,b,c) end
    local function encode(t) return t and json.encode(t) or "nil" end
    local function safeJson(t) return t and json.encode(t) or "nil" end

    chandlers = {
        --{"type":2,"sp":false,"rc":0}
        on_connect = function(flags,rc)
            DEBUG("mqtt", "trace", "MQTT connect:" .. encode(rc))
            if client._callbacks['connected'] then
                client._callbacks['connected']({ sessionPresent = flags, returnCode = rc })
            end
        end,
        on_subscribe = function(event)
            DEBUG("mqtt", "trace", "MQTT subscribe:" .. encode(event))
            if client._callbacks['subscribed'] then client._callbacks['subscribed'](safeJson(event)) end
        end,
        on_unsubscribe = function(event)
            DEBUG("mqtt", "trace", "MQTT unsubscribe:" .. encode(event))
            if client._callbacks['unsubscribed'] then client._callbacks['unsubscribed'](safeJson(event)) end
        end,
        on_message = function(msg, ff)
            DEBUG("mqtt", "trace", "MQTT message:" .. encode(msg))
            local msgt = mqtt.MSGMAP[msg.type]
            if msgt and client._callbacks[msgt] then
                client._callbacks[msgt](msg)
            elseif client._callbacks['message'] then
                client._callbacks['message'](msg)
            end
        end,
        on_acknowledge = function(event)
            DEBUG("mqtt", "trace", "MQTT acknowledge:" .. encode(event))
            if client._callbacks['acknowledge'] then client._callbacks['acknowledge']() end
        end,
        on_error = function(err)
            DEBUG("mqtt", "error", "MQTT error:" .. err)
            if client._callbacks['error'] then client._callbacks['error'](err) end
        end,
        on_close = function(event)
            DEBUG("mqtt", "trace", "MQTT close:" .. encode(event))
            event = safeJson(event)
            if client._callbacks['closed'] then client._callbacks['closed'](safeJson(event)) end
        end,
        on_auth = function(event)
            DEBUG("mqtt", "trace", "MQTT auth:" .. encode(event))
            if client._callbacks['auth'] then client._callbacks['auth'](safeJson(event)) end
        end,
    }

    local pstr = "MQTT object: " .. tostring(client):match("%s(.*)")
    setmetatable(client, { __tostring = function(_) return pstr end })
    client._client:connect(args.host,args.port,60)
    return client
end
-----------------------------------------------------------------------------

local _intercepts = { GET={}, POST={}, PUT={}, DELETE={}, PATCH={} }
local function callHC3S(x,y,z,w) -- sleep to let threads catch up (ex. importFQA)
    if (_intercepts[x] or {})[y] then
        if _intercepts[x][y](x,y,z,w) then return end
    end
    local a,b,c = callHC3(x,y,z,w)
    if (w ~= 'hc3' and fibaro) and (fibaro.sleep ~= nil) then fibaro.sleep(0) end
    return a,b,c
end

api = {
    get = function(url, hc3) return callHC3S("GET", patch(url), nil, hc3) end,
    post = function(url, data, hc3) return callHC3S("POST", url, data, hc3) end,
    put = function(url, data, hc3) return callHC3S("PUT", url, data, hc3) end,
    delete = function(url, data, hc3) return callHC3S("DELETE", url, data, hc3) end,
    _intercept = function(method, url, fun) 
        _intercepts[method][url] = fun
     end
}
