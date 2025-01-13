
function MODULE_configs()
  
  -- Customizing QA names, usually entities' names are used
  function HASS.nameNewQA(name) return name.." (HASS)" end
  HASS.defaultRoom = "Default Room" -- Default room for QAs created (name or id)

  -- Remapping of entity_id to types (<domain>_<device_category>)
  -- Ex. sensor.sonos_favorites has no device_category and is difficult to
  -- recognize as a sensor. This remaps it to sensor_favorites
  HASS.customTypes['sensor%.sonos_favorites'] = 'sensor_favorites'
  -- Detecting type of light and remapping type to light_rgb or light_dim
  HASS.customTypes['^light'] = function(e) 
    if e.attributes.rgb_color then return 'light_rgb'
    elseif e.attributes.brightness then return 'light_dim' end
  end
  
  -- Skip entities with specific attributes
  HASS.entityFilter['.attributes.fibaro_id'] = false -- Skip entities with fibaro_id
  HASS.entityFilter['.entity_id'] = "^update" -- Skip entities with entity_id starting with update
  --HASS.entityFilter['.state'] = "unavailable" -- Ex. Skip unavailale entities
  --HASS.entityFilter['.state'] = function(val) -- Ex. skip entities with state < 10
  --  val = tonumber(val)
  --  if val == nil then return nil end
  --  return val < 10 
  --end
  
  HASS.classes.Temperature.auto='sensor_temperature'
  HASS.classes.Lux.auto='sensor_illuminance'
    HASS.classes.Speaker.auto='media_player_speaker'
  -- HASS.classes.RGBLight.qa = {
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