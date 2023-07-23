--%%debug=refresh:true

local filesToKeep = 3
local remote = 'hc3'

local function writeFile(fname, content)
    local f = io.open(fname, "w")
    assert(f)
    f:write(content)
    f:close()
end

local format = string.format 

local destDir = './dev/backup/'
local QAs = api.get("/devices?interface=quickApp",remote)
local QAs = api.get("/devices/1189",remote)
QAs = {QAs}

local listDir = fibaro.pyhooks.listDir

table.sort(QAs,function(a,b) return a.modified < b.modified end)
for _,qa in ipairs(QAs) do
    local name = qa.name:gsub('[^%w]','_')
    local date = os.date("%y%m%d_%H%M%S",qa.modified)
    local id = qa.id
    local name = format("%s_%s_%s.fqa",name,id,date) 
    local fqa = api.get("/quickApp/export/"..id,remote)
    print("Writing "..destDir..name)
    writeFile(destDir..name,json.encode(fqa))
end
local files = json.decode(listDir(destDir))
local keeps = {}
for _,f in ipairs(files) do
    local name = f:match('(.-)_%d+_%d+.fqa')
    if name then keeps[name] = keeps[name] or {}; table.insert(keeps[name],f) end
end
for name,files in pairs(keeps) do
    table.sort(files,function(a,b) return a > b end)
    if #files > filesToKeep then
        for i=filesToKeep+1,#files do
            print("Removing "..destDir..files[i])
            os.remove(destDir..files[i])
        end
    end
end