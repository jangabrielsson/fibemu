--%%name=Value Test

local function printf(fmt,...) print(string.format(fmt,...)) end

os.setTime("04/15-12:00")
printf("Sunrise: %s",fibaro.getValue(1,"sunriseHour"))
printf("Sunset: %s",fibaro.getValue(1,"sunsetHour"))
