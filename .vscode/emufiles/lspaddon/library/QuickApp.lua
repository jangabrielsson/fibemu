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

---Sets a QuickApp variable.
---
---@param name string Name of variable.
---@param value any Value to assign variable.
---@return nil
function QuickAppBase:setVariable(name,value) end

---Retrives a QuickApp variable.
---
---@param name string Name of variable.
---@return nil
function QuickAppBase:getVariable(name) end

---Update UI element of QuickApp.
---
---@param label string Element name
---@param field string Element field
---@param value string Element field value
---@return nil
function QuickAppBase:updateView(label,field,value) end

---Log to console with DEBUG level.
---
---@param ... any Arguments to log.
---@return nil
function QuickAppBase:debug(...)  end

---Log to console with ERROR level.
---
---@param ... any Arguments to log.
---@return nil
function QuickAppBase:error(...) end

---Log to console with WARNING level.
---
---@param ... any Arguments to log.
---@return nil
function QuickAppBase:warning(...) end

---Log to console with TRACE level.
---
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

function QuickAppBase:updateProperty(prop,val) end

function QuickApp:createChildDevice(props,deviceClass) end

function QuickApp:removeChildDevice(id) end

function QuickApp:initChildDevices(map) end

function QuickAppBase:internalStorageSet(key, val, hidden) end

function QuickAppBase:internalStorageGet(key) end

function QuickAppBase:internalStorageRemove(key) end

function QuickAppBase:internalStorageClear() end