
local VARNAME = "EnphaseUpdate" -- Name of global sync variable
local INTERV = 3 -- Interval to cehck variable in seconds
local refresh = false

function QuickApp:uiRefreshOnR(event)
    refresh = true 
    -- fibaro.setGlobalVariable(VARNAME,"false") -- wait for next update 
  end

  local function checkForRefresh()
    if refresh then
      if fibaro.getGlobalVariable(VARNAME) == 'true' then
        fibaro.setGlobalVariable(VARNAME,"false") -- reset the variable 
        refresh = false
        self:Refresh()
      end
    end
  end

  function QuickApp:onInit()
    api.post("/globalVariables",{name=VARNAME,value="false"}) -- create the global variable if it does not exist
    setInterval(checkForRefresh, 5*1000) -- check every minute if we need to refresh
  end

  -----
  --In other QA do
    fibaro.setGlobalVariable("EnphaseUpdate","true") -- to signal that there is new data

