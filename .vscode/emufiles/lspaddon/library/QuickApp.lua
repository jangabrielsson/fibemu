--https://github.com/LuaLS/lua-language-server/wiki/Annotations

---@meta

---@class QuickAppBase
---@field id number The deviceID of the QA
---@field name string The name of the QA
---@field parentId number The deviceID of the parent device
QuickAppBase = {}

---@class QuickAppChild : QuickAppBase
QuickAppChild = {}

---@class QuickApp : QuickAppBase
---@field childDevices table<number,QuickAppBase> Mapping of childDevieIDs to QuickAppChild objects
QuickApp = {}

---Called when QuickApp starts.
---
---@return nil
function QuickAppBase:onInit() end


---The method for setting device variables.
---
-- The variable is created if it's not already defined. The variable can be used in the device configuration or in the code of the device. The variable's value can be of any type.
---@param name string Name of variable.
---@param value any Value to assign variable.
---@return nil
function QuickAppBase:setVariable(name,value) end

---Retrives a QuickApp variable.
---
-- The method is used to get the Quick App variables. Variables can be added from the device configuration or the method QuickApp:setVariable. If the variable doesn't exist, the method returns "".
---@param name string Name of variable.
---@return any
function QuickAppBase:getVariable(name) end

---Update UI element of QuickApp.
---
---@param label string Element name. ID of element
---@param field string Element field, "text" or "value"
---@param value string Element field value. Must be string
---@return nil
function QuickAppBase:updateView(label,field,value) end

---Log to console with DEBUG level.
---
---A method for displaying messages of type DEBUG in the log window (under the code editor). The values can be of any type, as they will be converted into text using the tostring function and separated by a single space.
---@param ... any Arguments to log.
---@return nil
function QuickAppBase:debug(...)  end

---Log to console with ERROR level.
---
---A method for displaying messages of type ERROR in the log window (under the code editor). The values can be of any type, as they will be converted into text using the tostring function and separated by a single space.
---@param ... any Arguments to log.
---@return nil
function QuickAppBase:error(...) end

---Log to console with WARNING level.
---
---A method for displaying messages of type WARNING in the log window (under the code editor). The values can be of any type, as they will be converted into text using the tostring function and separated by a single space.
---@param ... any Arguments to log.
---@return nil
function QuickAppBase:warning(...) end

---Log to console with TRACE level.
---
---A method for displaying messages of type TRACE in the log window (under the code editor). The values can be of any type, as they will be converted into text using the tostring function and separated by a single space.
---@param ... any Arguments to log.
---@return nil
function QuickAppBase:trace(...)   end

---Call a QuickApp method.
---
---@param name string Name of method to call.
---@param ... any Arguments to pass to method.
---@return nil
function QuickAppBase:callAction(name,...) end

---Changes name of QuickApp
---
---@param name string New name of QuickApp
---@return nil
function QuickAppBase:setName(name) end

---Enables the QuickApp
---
---@param bool boolean Enable or disable QuickApp
---@return nil
function QuickAppBase:setEnabled(bool) end

---Sets the visibility of QuickApp
---
---@param bool boolean Visible or invisible QuickApp
---@return nil
function QuickAppBase:setVisible(bool) end

---Checks if QuickApp is of type
---
---@param typ string Type to check
---@return boolean
function QuickAppBase:isTypeOf(typ) end

---Add interfaces to QuickApp
---
---@param ifs table<string> Table of interfaces to add.
---@return nil
function QuickAppBase:addInterfaces(ifs) end

---Delete interfaces from QuickApp
---@param ifs table<string> Table of interfaces to delete.
---@return nil
function QuickAppBase:deleteInterfaces(ifs) end

---Update property of QA
---
---@param prop string Property to update.
---@param val any Value to set property to.
---@return nil
function QuickAppBase:updateProperty(prop,val) end

---Create a child device QA
---
---@param props table Initial data for child.
---@param deviceClass QuickAppChild Class of child device
---@return table Child object
function QuickApp:createChildDevice(props,deviceClass) end

---Remove child device
---
---@param id number DeviceID of child to remove
---@return nil
function QuickApp:removeChildDevice(id) end

---Remove child device
---@param map table of child devices to add
---@return nil
function QuickApp:initChildDevices(map) end

function QuickAppBase:internalStorageSet(key, val, hidden) end

function QuickAppBase:internalStorageGet(key) end

function QuickAppBase:internalStorageRemove(key) end

function QuickAppBase:internalStorageClear() end