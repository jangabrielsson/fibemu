
local function readFile(fname)
    local f = io.open(fname, "rb")
    assert(f)
    local content = f:read("*all")
    f:close()
    return content
end

local fqa = readFile("examples/QA.fqa")
fqa = json.decode(fqa)
local s,c = api.post("/quickApp/",fqa)
fibaro.call(s.id,"updateView","label1","text","Hello World")
fibaro.call(s.id,"setVariable","x","42")


fqa = api.post("/quickApp/export/"..s.id)
print(fqa)

