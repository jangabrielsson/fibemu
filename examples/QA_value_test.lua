--%%name=Value Test

local function printf(fmt,...) print(string.format(fmt,...)) end

printf("Sunrise: %s",fibaro.getValue(1,"sunriseHour"))
printf("Sunset: %s",fibaro.getValue(1,"sunsetHour"))
