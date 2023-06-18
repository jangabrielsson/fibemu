local r = {}

local keys = {
    globalVariables = "name",
    devices = "id",
    rooms = "id",
    sections = "id",
}

local rsrcs = {
    globalVariables = nil,
    devices = nil,
    rooms = nil,
    sections = nil,
}

function r.refresh()
end

function r.refresh_resource(name,key)
    rsrcs[name] = {}
    local rss = api.get("/"..name,"hc3") or {}
    for _, rs in ipairs(rss) do
        rsrcs[name][rs[key]] = rs
    end
end

function r.createGlobalVariable(name,value)
end

function r.getResource(name,id)
    --print("getResource",name,id,tostring(rsrcs[name]))
    if rsrcs[name] == nil then
        r.refresh_resource(name,keys[name])
    end
    local rs = rsrcs[name] or {}
    local res = id and rs[id] or rs
    return res
end

return r