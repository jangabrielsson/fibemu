-- <file> qa download 55 test/ fqa
-- <file> qa download 55 test/ split
-- <file> qa upload file
-- <file> qa package file
-- <file> qa upload test/foo.lua
-- <file> qa upload test/foo.fqa
local file = fibaro.config.extra[1]
print("QA is",file)
fibaro.pyhooks.exit(0)