--%%name=Value Test

local function printf(fmt, ...) print(string.format(fmt, ...)) end

for i = 1, 12 do
    local d = string.format("%02d/15-12:00",i)
    print(d)
    os.setTime(d)
    printf("Sunrise: %s", fibaro.getValue(1, "sunriseHour"))
    printf("Sunset: %s", fibaro.getValue(1, "sunsetHour"))
end
