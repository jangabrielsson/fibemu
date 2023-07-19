
local function readFile(fname)
    local f = io.open(fname, "rb")
    assert(f)
    local content = f:read("*all")
    f:close()
    return content
end

local fqa = readFile("examples/QA.fqa") -- read in the fqa file
fqa = json.decode(fqa)
local s,c = api.post("/quickApp/",fqa)  -- Install the QA in the emulator
fibaro.call(s.id,"updateView","label1","text","Hello World") -- Set label1 to "Hello World"
fibaro.call(s.id,"setVariable","x","42")                     -- and set variable x to 42
fqa = api.get("/quickApp/export/"..s.id) -- export the QA from the emulator

print(json.encode(fqa.initialProperties.quickAppVariables)) -- Have a look at the quickAppVariables
