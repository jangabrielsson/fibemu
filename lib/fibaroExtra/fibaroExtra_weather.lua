fibaro._MODULES = fibaro._MODULES or {} -- Global
local _MODULES = fibaro._MODULES
_MODULES.weather={ author = "jan@gabrielsson.com", version = '0.4', depends={'base'},
  init = function()
    local _,_ = fibaro.debugFlags,string.format
    fibaro.weather = {}
    --Exported: Returns the current temperature
    function fibaro.weather.temperature() return api.get("/weather").Temperature end
    --Exported: Returns the temperature unit
    function fibaro.weather.temperatureUnit() return api.get("/weather").TemperatureUnit end
    --Exported: Returns the current humidity
    function fibaro.weather.humidity() return api.get("/weather").Humidity end
    --Exported: Returns the current wind speed
    function fibaro.weather.wind() return api.get("/weather").Wind end
    --Exported: Returns the current condition
    function fibaro.weather.weatherCondition() return api.get("/weather").WeatherCondition end
    --Exported: Returns the current condition code
    function fibaro.weather.conditionCode() return api.get("/weather").ConditionCode end
  end
} -- Weather

