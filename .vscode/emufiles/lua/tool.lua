-- <file> qa download_fqa 55 test/
-- <file> qa download_split 55 test/
-- <file> qa upload <file>
-- <file> qa package <file>
-- <file> qa upload test/foo.lua
-- <file> qa upload test/foo.fqa
-- <file> qa upload <file> test/foo.fqa
local file = fibaro.config.extra[1]
local rsrc = fibaro.config.extra[2]
local cmd = fibaro.config.extra[3]
local name = fibaro.config.extra[4]
local path = fibaro.config.extra[5]
local function printf(fmt,...) print(string.format(fmt,...)) end

local tool = {}
function tool.download_fqa(file,rsrc,name,path)
    printf("Downloading fqa %s to %s",name,path)
    local fqa = api.get("/quickApp/export/"..name) 
    print("fqa",fqa)
end

function tool.download_split(file,rsrc,name,path)
end

function tool.upload(file,rsrc,name,path)
end

function tool.package(file,rsrc,name,path)
end

if not tool[cmd] then
    fibaro.debug("fibtool","Unknown command: "..cmd)
else
    local stat,res = pcall(tool[cmd],file,rsrc,name,path)
    if not stat then 
        fibaro.error("fibtool","Error: "..res)
    else
        fibaro.debug("fibtool","Success")
    end
end
fibaro.pyhooks.exit(0)