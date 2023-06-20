local devices = nil

local function init(conf, fname, libs)
    local file = io.open(fname, "r")
    assert(file, fname.." not found")
    devices = json.decode(file:read("*a"))
    file:close()
    return devices
end

local function getDeviceStruct(typ)
    return devices[typ]
end

return { getDeviceStruct = getDeviceStruct, init = init }
