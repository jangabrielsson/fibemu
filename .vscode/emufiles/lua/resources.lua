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

function r.getResource(name,id)
    if rsrcs[name] == nil then
        r.refresh_resource(name,keys[name])
    end
    local rs = rsrcs[name] or {}
    local res = id and rs[id] or rs
    return res
end

function r.createGlobalVariable(name, value, d)
end

function r.removeGlobalVariable(name)
end

function r.updateGlobalVariable(name, value, d)
end

function r.createDevice(id, d)
end

function r.removeDevice(id)
end

function r.updatePropDevice(deviceId, value, d)
end


function r.createRoom(id, d)
end

function r.removeRoom(id)
end

function r.updateRoom(id, d)
end

function r.createSection(id, d)
end

function r.removeSection(id)
end

function r.updateSection(id, d)
end

return r