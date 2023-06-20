local devices = nil

local function init(fname)
    local file = io.open(fname, "r")
    assert(file, fname.." not found")
    local data = json.decode(file:read("*a"))
    file:close()
    return data
end

local function getDeviceStruct(typ)
    return devices[typ]
end

return { getDeviceStruct = getDeviceStruct, init = init }
