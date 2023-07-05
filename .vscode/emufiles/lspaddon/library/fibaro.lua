--https://github.com/LuaLS/lua-language-server/wiki/Annotations

---@meta

---@alias deviceId integer The ID of a device
---@alias roomId integer The ID of a room
---@alias sectionId integer The ID of a section 
---@alias sceneId integer The ID of a scene 

---@class fibaro
fibaro = {}

--@alias hub fibaro

function string.split(str, sep) end

---Alarm
---
---@param arg1 string Name of variable.
---@param action string Name of variable.
---@return nil
function fibaro.alarm(arg1, action) end

---House alarm
---
---@param action string Name of variable.
---@return nil
function fibaro.__houseAlarm(action) end

---Alert
---
---@param alertType string Name of variable.
---@param ids string Name of variable.
---@param notification string Name of variable.
---@param isCritical string Name of variable.
---@param subject string Name of variable.
---@return nil
function fibaro.alert( alertType , ids , notification , isCritical , subject ) end

---Emits a custom event.
---@param name string Name of event.
---@return nil
function fibaro.emitCustomEvent(name) end

---Calls a device method
---
---@param deviceId number ID of device.
---@param actionName string Name of method to call.
---@return nil
function fibaro.call(deviceId, actionName, ...) end

---Retrieves a QuickApp variable.
---
---@param actionName string Name of method to call.
---@param actionData table 
---@return nil
function fibaro.callGroupAction(actionName, actionData) end

---Retrieves a device property.
---
---@param deviceId deviceId ID of device.
---@param propertyName string Name of property.
---@return any,integer
function fibaro.get(deviceId, propertyName) end

---Retrieves a device property.
---
---@param deviceId deviceId ID of device.
---@return any
function fibaro.getValue(deviceId, propertyName) end

---Retrieves a device type
---
---@param deviceId deviceId ID of device.
---@return string
function fibaro.getType(deviceId) end

---Retrieves name of device
---
---@param deviceId deviceId ID of device.
---@return deviceId
function fibaro.getName(deviceId) end

---Retrieves room ID of device
---
---@param deviceId deviceId ID of device.
---@return roomId
function fibaro.getRoomID(deviceId) end

---Retrieves section ID of device
---
---@param deviceId deviceId
---@return sectionId
function fibaro.getSectionID(deviceId) end

---Retrieves name of room
---
---@param roomId roomId ID of room.
---@return string
function fibaro.getRoomName(roomId) end

---Retrieves room name of device
---
---@param deviceId deviceId
---@return string
function fibaro.getRoomNameByDeviceID(deviceId) end

---Retrieves a QuickApp variable.
---
---@param filter table
---@return table
function fibaro.getDevicesID(filter) end

---Retrieves a QuickApp variable.
---
---@param devices table
---@return table<deviceId>
function fibaro.getIds(devices) end

---Retrieves a global variable value
---
---@param name string Name of variable.
---@return nil
function fibaro.getGlobalVariable(name) end

---Assigns a value to a global variable
---
---@param name string Name of variable.
---@param value string Value to assign.
---@return nil
function fibaro.setGlobalVariable (name, value) end

---Start a scene
---
---@param action string Name of action.
---@param ids table<sceneId>
---@return nil
function fibaro.scene(action, ids) end

---Sets profile
---
---@param action string Name of action.
---@param profileId number ID of profile.
---@return nil
function fibaro.profile(action, profileId) end

---Retrieves a partition
---
---@param id number ID of partition.
---@return nil
function fibaro.getPartition(id) end

---Schedule a function to runa after a given time.
---
---@param timeout number Time in milliseconds.
---@param action function Function to run.
---@return nil
function fibaro.setTimeout(timeout, action) end

---Cancel a previously set timeout.
---
---@param timeoutRef any Reference of timeout to cancel.
---@return nil
function fibaro.clearTimeout(timeoutRef) end

---Wakes up a dead device
---
---@param deviceID number ID of device
---@return nil
function fibaro.wakeUpDeadDevice(deviceID) end

---Pause the execution of the QA for a given time.
---
---@param ms number Time in milliseconds.
---@return nil
function fibaro.sleep(ms) end

---Logs to the consolue with DEBUG level.
---
---@param tag string Name of tag, usually __TAG
---@param ... any Arguments to be printed.
---@return nil
function fibaro.debug(tag,...)  end

---Logs to the consolue with WARNING level.
---
---@param tag string Name of tag, usually __TAG
---@param ... any Arguments to be printed.
---@return nil
function fibaro.warning(tag,...) end

---Logs to the consolue with TRACE level.
---
---@param tag string Name of tag, usually __TAG
---@param ... any Arguments to be printed.
---@return nil
function fibaro.trace(tag,...) end

---Set async call mode
---
---@param value boolean
---@return nil
function fibaro.useAsyncHandler(value) end

---Return the armed state of the home
---
---@return boolean
function fibaro.getHomeArmState() end

---Check of any partition is breached
---
---@return boolean
function fibaro.isHomeBreached() end

---Checks if partition is breached
---
---@param id number
---@return boolean
function fibaro.isPartitionBreached(id) end

---Get state  of alarm partition
---
---@param id number ID of partition.
---@return nil
function fibaro.getPartitionArmState(id) end

---Retrieves a Alarm partitions
---
---@return nil
function fibaro.getPartitions() end

---Calls QuickApp UI element, button or slider
---
---@param id number QA deviceId
---@param action string Ation to perform, "onReleased" or "onChanged"
---@param element string Name of UI element
---@param value table {value={<value>}}
---@return nil
function fibaro.callUI(id, action, element, value) end