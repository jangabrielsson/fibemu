-- <file> qa download_fqa 55 test/
-- <file> qa download_unpack 55 test/
-- <file> qa upload <file>
-- <file> qa package <file>
-- <file> qa upload test/foo.lua
-- <file> qa upload test/foo.fqa
-- <file> qa upload <file> test/foo.fqa
local fibemu = fibaro.fibemu
local file = fibemu.config.extra[1]
local rsrc = fibemu.config.extra[2]
local cmd = fibemu.config.extra[3]
local name = fibemu.config.extra[4]
local path = fibemu.config.extra[5]
local function printf(fmt, ...) print(string.format(fmt, ...)) end
local function printerrf(fmt, ...) fibaro.error(__TAG, string.format(fmt, ...)) end
__TAG = "fibtool"

local function copy(obj)
    if type(obj) == 'table' then
        local res = {}
        for k, v in pairs(obj) do res[k] = copy(v) end
        return res
    else
        return obj
    end
end

local tool = {}
function tool.download_fqa(file, rsrc, name, path)
    printf("Downloading fqa %s to %s", name, path)
    local fqa, code = api.get("/quickApp/export/" .. name, "hc3")
    if not fqa then
        printf("Error downloading fqa: %s", code)
        return
    end
    local name = fqa.name or "QA"
    name = name:gsub("(%s+)", "_")
    local fname = path .. "/" .. name .. ".fqa"

    local stat, res = pcall(function()
        local f, err = io.open(fname, "w")
        if not f then
            printerrf("Error opening %s: %s", fname, err)
            return
        end
        f:write(json.encode(fqa))
        printf("Saved %s", fname)
    end)
    if not stat then
        printf("Error saving fqa: %s", res)
    end
    return true
end

local function writeFile(fname, content, silent)
    local f,err = io.open(fname, "w")
    if not f then
        printerrf("Error opening %s: %s", fname, err)
        printerrf("Does the path exist?")
        return nil
    end
    f:write(content)
    f:close()
    if not silent then printf("Wrote %s", fname) end
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
    if type(t) == 'table' and t[1] then
        local res = {}
        for _, v in ipairs(t) do
            res[#res + 1] = toLua(v)
        end
        return "{" .. table.concat(res, ",") .. "}"
    else
        local res, keys = {}, {}
        for k, _ in pairs(t) do keys[#keys + 1] = k end
        table.sort(keys, keyCompare)
        for _, k in ipairs(keys) do
            res[#res + 1] = string.format('%s="%s"', k, t[k])
        end
        return "{" .. table.concat(res, ",") .. "}"
    end
end

function tool.download_unpack(file, rsrc, id, path)
    printf("Downloading QA %s to %s", name, path)
    local fqa, code = api.get("/quickApp/export/" .. id, "hc3")
    if not fqa then
        printerrf("Downloading QA %s: %s", id, code)
        return true
    end
    local name = fqa.name or "QA"
    local typ = fqa.type
    local files = fqa.files
    local props = fqa.initialProperties
    local interfaces = fqa.initialInterfaces

    local fname = name:gsub("(%s+)", "_")

    local files, main = {}, ""
    for _, f in ipairs(fqa.files) do
        files[f.name] = { code = f.content, fname = path .. "/" .. fname .. "_" .. f.name .. ".lua" }
        if f.isMain then
            main = f.name
        end
    end
    local mainFD = files[main]
    files[main] = nil

    for qname, fd in pairs(files) do
        if not writeFile(fd.fname, fd.code) then return true end
    end

    local mainFname = path .. "/" .. fname .. ".lua"
    if not writeFile(mainFname, mainFD.code, true) then return true end

    local flib = fibemu.libs.files
    local uilib = fibemu.libs.ui
    local qa = flib.installQA(mainFname, {silent=true})
    local headers = {}
    local function outf(...) headers[#headers + 1] = string.format(...) end
    outf("--%%%%name=%s", name)
    outf("--%%%%type=%s", typ)
    outf("--%%%%id=%s", id)
    qa.UI = uilib.view2UI(fqa.initialProperties.viewLayout, fqa.initialProperties.uiCallbacks)
    for _, row in ipairs(qa.UI or {}) do
        outf("--%%%%u=%s", toLua(row))
    end
    for n, fd in pairs(files) do
        outf("--%%%%file=%s,%s;", fd.fname, n)
    end
    local theaders = table.concat(headers, "\n")
    mainFD.code = theaders .. "\n" .. mainFD.code .. "\n\n" .. mainFD.code
    if not writeFile(mainFname, mainFD.code) then return true end
    return true
end

function tool.upload(file, rsrc, name, path)
    if name == '.' then name = file end
    local flib = fibemu.libs.files

    local fqa,err = pcall(flib.file2FQA,name)
    if not fqa then
        printerrf("Error parsing %s: %s", name, err)
        return true
    end
    fqa = err
    local stat, res, info = api.post("/quickApp/", fqa, "hc3")
    if not stat then
        printerrf("Error uploading QA: %s %s", res, tostring(info))
        return true
    else
        printf("Uploaded QA %s", stat.id)
    end
end

function tool.update(file, rsrc, name, path) -- move logic to files?
    local updateQvs,id = true,nil
    if name == '.' then name = file end
    if name == '-' then name = file; updateQvs = false end
    if tonumber(name) then
        id = tonumber(name)
        if id < 0 then
            updateQvs = false
            id = -id
        end
        name = file
    end
    local flib = fibemu.libs.files
    local qa = flib.installQA(name, {silent=true})
    if not id and not qa.definedId then
        printerrf("QA need to define --%%id=<HC3ID>\nso we know what QA to update on HC3")
        return true
    elseif not id then
        id = qa.definedId
    end
    local dev = qa.dev
    local files = qa.files
    flib.loadFiles(qa.dev.id)
    for _, f in ipairs(files) do
        f.qa = nil
        f.fname = nil
        f.isOpen = false
        f.type = 'lua'
    end
    local currFiles = api.get("/quickApp/" .. id .. "/files", "hc3")
    if not currFiles then
        printerrf("Error getting QA files for id:%s", id)
        return true
    end
    local oldMap, newMap = {}, {}
    for _, f in ipairs(currFiles) do oldMap[f.name] = f end
    for _, f in ipairs(files) do newMap[f.name] = f end
    for newF, d in pairs(newMap) do
        if not oldMap[newF] then
            printf("Creating file %s", newF)
            local stat, res = api.post("/quickApp/" .. id .. "/files", d, "hc3")
            if not stat then
                printerrf("Error creating QA file %s: %s", newF, res)
                return true
            end
        end
    end
    printf("Updating existing files")
    local stat, res = api.put("/quickApp/" .. id .. "/files", files, "hc3")
    if not stat then
        printerrf("Error updating QA files %s", res)
        return true
    end
    for oldF, _ in pairs(oldMap) do
        if not newMap[oldF] then
            printf("Deleting file %s", oldF)
            api.delete("/quickApp/" .. id .. "/files/" .. oldF, "hc3")
        end
    end
    if updateQvs then
        printf("Updating quickAppVariables, viewLayout, and uiCallbacks...")
    else
        printf("Updating viewLayout and uiCallbacks...")
    end

    local viewLayout,uiCallbacks = fibemu.libs.ui.pruneStock(dev.properties)

    local stat, res = api.put("/devices/" .. id, {
        properties = {
            uiCallbacks = uiCallbacks,
            viewLayout = viewLayout,
            quickAppVariables = updateQvs and dev.properties.quickAppVariables or nil,
        }
    }, "hc3")
    if not stat then
        printerrf("Error updating QA props %s", res)
        return true
    end
    printf("QA %s updated", id)
end

if not tool[cmd] then
    fibaro.debug("fibtool", "Unknown command: " .. cmd)
else
    local stat, res = pcall(tool[cmd], file, rsrc, name, path)
    if not stat then
        fibaro.error("fibtool", "Error: " .. tostring(res))
    elseif res ~= true then
        fibaro.debug("fibtool", "Success")
    end
end
fibemu.pyhooks.exit(0)
