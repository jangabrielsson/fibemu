
function MODULE_configs()
  
  -- Customizing QA names, usually entities' names are used
  function HASS.nameNewQA(name) return name.." (HASS)" end
  HASS.defaultRoom = "Default Room" -- Default room for QAs created (name or id)
  HASS.proposeBattery = true -- Try to match battery entities with QAs

  -- Remapping of entity_id to types (<domain>_<device_class>)
  -- Ex. sensor.sonos_favorites has no device_class and is difficult to
  -- recognize as a sensor. This remaps it to sensor_favorites
  HASS.customTypes['sensor%.sonos_favorites'] = 'sensor_favorites'
  -- Detecting type of light and remapping type to light_rgb or light_dim
  HASS.customTypes['^light%.'] = function(e) 
    if e.attributes.rgb_color then return 'light_rgb'
    elseif e.attributes.brightness then return 'light_dim' end
  end
  HASS.customTypes['^sensor%.'] = function(e) 
    if e.attributes.Location then return 'sensor_location' end
  end
  HASS.customTypes['^sensor%.'] = function(e) 
    local a = e.attributes
    if a.state_class=='measurement' and not a.device_class then return 'sensor_measurement' end
  end
  HASS.customTypes['^climate%.'] = function(e) 
    if e.attributes.hvac_modes then return 'climate_hvac' end
  end

  -- Skip entities with specific attributes.
  -- Return true if entity should be skipped/filtered
  HASS.entityFilter['.attributes.fibaro_id'] = true -- Skip entities with fibaro_id
  HASS.entityFilter['.entity_id'] = "^update%." -- Skip entities with entity_id starting with update
  --HASS.entityFilter['.state'] = "unavailable" -- Ex. Skip unavailale entities
  --HASS.entityFilter['.state'] = function(val) -- Ex. skip entities with state < 10
  --  val = tonumber(val)
  --  if val == nil then return nil end
  --  return val < 10 
  --end
  
  -- Automatically define QA classes based on enity type 
  local AUTO = false
  if AUTO or quickApp.qvar.auto=='true' then

    HASS.classes.Temperature.auto='sensor_temperature' -- Define all temperature sensors as Tmperature
    HASS.classes.Lux.auto='sensor_illuminance'         -- Define all illuminance sensors as Lux
    HASS.classes.Speaker.auto='media_player_speaker'   -- Define all media player speakers as Speaker
    HASS.classes.TV.auto='media_player_tv'             -- Define all media player tv as TV
    --HASS.classes.InputText.auto='input_text'         -- Define all input texts
    HASS.classes.DoorSensor.auto = {                   -- Define all door sensors as DoorSensor
    'binary_sensor_door',
    'binary_sensor_garage_door',
    'binary_sensor_opening'
    }
    HASS.classes.SmokeSensor.auto='binary_sensor_smoke'   -- Define all smoke sensors as Smoke
    HASS.classes.WindowSensor.auto='binary_sensor_window' -- Define all window sensors as WindowSensor
    HASS.classes.Motion.auto={                            -- Define all motion sensors as MotionSensor
    'binary_sensor_motion',
    'binary_sensor_occupancy',
    'binary_sensor_presence',
    'binary_sensor_moving'}
    HASS.classes.Humidity.auto='sensor_humidity'            -- Define all humidity sensors as Humidity
    HASS.classes.Pm25.auto='sensor_pm25'                    -- Define all PM25 sensors as PM25
    HASS.classes.Pm10.auto='sensor_pm10'                    -- Define all PM10 sensors as PM10
    HASS.classes.Pm1.auto='sensor_pm1'                      -- Define all PM1 sensors as PM1
    HASS.classes.Co.auto='sensor_carbon_monoxide'           -- Define all CO sensors as CO
    HASS.classes.DeviceTracker.auto='device_tracker'        -- Define all device tracker
    HASS.classes.Zone.auto='zone'                           -- Define all zones
    HASS.classes.Measurement.auto='sensor_measurement'      -- Define all measurements
    HASS.classes.Calendar.auto='calendar'                   -- Define all calendars
    --HASS.classes.Thermostat.auto = 'climate_hvac'          -- TBD
    
  -- HASS.classes.RGBLight.qa = { -- Predefined QAs for RGB lights
  --   ['myQA_1'] = {
  --     entities = {
  --       "light.kitchen1",
  --       "light.livingroom",
  --     },
  --     --room = "kitchen", -- Optional, use name or roomId
  --     name == nil,        -- Use first entity_id's name
  --   },
  --   ['myQA_2'] = {
  --     entities = {
  --       "light.kitchen2",
  --       "light.livingroom",
  --     },
  --     --room = "kitchen",
  --     name == nil,  -- Use first entity_id's name
  --   },
  -- }
  
  end

end