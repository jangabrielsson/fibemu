-- <file> qa download_fqa 55 test/
-- <file> qa download_unpack 55 test/
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
local function printerrf(fmt,...) fibaro.error(__TAG,string.format(fmt,...)) end
__TAG="fibtool"

local tool = {}
function tool.download_fqa(file,rsrc,name,path)
    printf("Downloading fqa %s to %s",name,path)
    local fqa,code = api.get("/quickApp/export/"..name,"hc3")
    if not fqa then
        printf("Error downloading fqa: %s",code)
        return
    end
    local name = fqa.name or "QA"
    name = name:gsub("(%s+)","_")
    local fname = path.."/"..name..".fqa"

    local stat,res = pcall(function()
        local f,err = io.open(fname,"w")
        if not f then
            printerrf("Error opening %s: %s",fname,err)
            return
        end
        f:write(json.encode(fqa))
        printf("Saved %s",fname)
    end)
    if not stat then
        printf("Error saving fqa: %s",res)
    end
    return true
end

local function writeFile(fname,content,silent)
    local f = io.open(fname,"w")
    if not f then
        printerrf("Error opening %s: %s",fname,err)
        return nil
    end
    f:write(content)
    f:close()
    if not silent then printf("Wrote %s",fname) end
    return true
end

local sortKeys = {
    "button", "slider", "label",
    "text",
    "min", "max", "value",
    "visible",
    "onRelease", "onChanged",
}
local sortOrder = {}
for i, s in ipairs(sortKeys) do sortOrder[s] = "\n" .. string.char(i + 64) .. " " .. s end
local function keyCompare(a, b)
  local av, bv = sortOrder[a] or a, sortOrder[b] or b
  return av < bv
end

local function toLua(t)
    if type(t)=='table' and t[1] then
        local res = {}
        for _,v in ipairs(t) do
            res[#res+1] = toLua(v)
        end
        return "{"..table.concat(res,",").."}"
    else
        local res,keys = {},{}
        for k,_ in pairs(t) do keys[#keys+1] = k end
        table.sort(keys,keyCompare)
        for _,k in ipairs(keys) do
            res[#res+1] = string.format('%s="%s"',k,t[k])
        end
        return "{"..table.concat(res,",").."}"
    end
end

function tool.download_unpack(file,rsrc,id,path)
    printf("Downloading QA %s to %s",name,path)
    local fqa,code = api.get("/quickApp/export/"..id,"hc3")
    if not fqa then
        printerrf("Downloading fqa %s: %s",id,code)
        return true
    end
    local name = fqa.name or "QA"
    local typ = fqa.type
    local files = fqa.files
    local props = fqa.initialProperties
    local interfaces = fqa.initialInterfaces

    local fname = name:gsub("(%s+)","_")

    local files,main = {},""
    for _,f in ipairs(fqa.files) do
        files[f.name] = {code = f.content, fname = path.."/"..fname.."_"..f.name..".lua"}
        if f.isMain then
            main = f.name
        end
    end
    local mainFD = files[main]
    files[main]=nil

    for qname,fd in pairs(files) do
        if not writeFile(fd.fname,fd.code) then return true end
    end

    local mainFname = path.."/"..fname..".lua"
    if not writeFile(mainFname,mainFD.code,true) then return true end

    local flib = fibaro.fibemu.libs.files
    local uilib = fibaro.fibemu.libs.ui
    local qa = flib.installQA(mainFname,nil,true)
    local headers={}
    local function outf(...) headers[#headers+1] = string.format(...) end
    outf("--%%%%name=%s",name)
    outf("--%%%%type=%s",typ)
    qa.UI = uilib.view2UI(fqa.initialProperties.viewLayout,fqa.initialProperties.uiCallbacks)
    for _,row in ipairs(qa.UI or {}) do
        outf("--%%%%u=%s",toLua(row))
    end
    for n,fd in pairs(files) do
        outf("--%%%%file=%s,%s;",fd.fname,n)
    end
    local theaders = table.concat(headers,"\n")
    mainFD.code = theaders.."\n"..mainFD.code.."\n\n"..mainFD.code
    if not writeFile(mainFname,mainFD.code) then return true end
    return true
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
    elseif res ~= true then
        fibaro.debug("fibtool","Success")
    end
end
fibaro.pyhooks.exit(0)