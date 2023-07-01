--%%name=Include File QA
--%%type=com.fibaro.binarySwitch
--%%file=examples/include_file.lua,extra;
--%%debug=libraryfiles:false,userfilefiles:true

local function printf(fmt,...) print(string.format(fmt,...)) end
function QuickApp:onInit()
    foo()
end