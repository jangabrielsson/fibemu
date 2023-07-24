local dir = "examples/"
local fileName = dir.."QA_websocket_test.lua"
local qaName = fileName:gsub("%.lua",".fqa")
local docFile = fileName:gsub("%.lua",".doc")

local format = string.format
local files = fibaro.fibemu.libs.files

local function setVariable(fqa,name,value)
    for _,v in ipairs(fqa.initialProperties.quickAppVariables or {}) do
        if v.name == name then
            v.value = value
            return
        end
    end
    fqa.initialProperties.quickAppVariables = fqa.initialProperties.quickAppVariables or {}
    table.insert(fqa.initialProperties.quickAppVariables, {name=name, value=value})
end

local code
local fqa = files.file2FQA(fileName)
setVariable(fqa,"ip","0.0.0.0")
setVariable(fqa,"debug","true")
for _,f in ipairs(fqa.files) do
    if f.isMain then code = f.content; break end
end
local version = code:match("version = \"(.-)\"")
local funs = {}
code:gsub("--EXPORT%s*[\n\r]+function QuickApp:([^\n\r]+)",function(fun)
    table.insert(funs,fun)
end)
table.sort(funs)

local file = io.open(docFile,"w")
assert(file)
local function printf(...) file:write(string.format(...).."\n") end
printf("Documentation for %s",qaName)
printf("Version: %s",version)
printf("Functions:")
for _,f in ipairs(funs) do
    printf("  QuickApp:%s",f)
end
file:close()
print("Wrote "..docFile)
file = io.open(qaName,"w")
assert(file)
file:write(json.encode(fqa))
file:close()
print("Wrote "..qaName)

version = version:gsub("%.","_")
local zipName = qaName:gsub("%.fqa","_"..version..".zip")
zipName = zipName:gsub(dir,"")
qaName = qaName:gsub(dir,"")
docFile = docFile:gsub(dir,"")
os.execute(format("cd %s; zip %s %s %s; rm %s; rm %s",dir,zipName,qaName,docFile,qaName,docFile))