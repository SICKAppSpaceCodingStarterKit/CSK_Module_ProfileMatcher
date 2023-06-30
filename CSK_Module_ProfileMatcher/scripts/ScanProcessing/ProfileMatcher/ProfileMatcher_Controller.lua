---@diagnostic disable: undefined-global, redundant-parameter, missing-parameter

--***************************************************************
-- Inside of this script, you will find the necessary functions,
-- variables and events to communicate with the ProfileMatcher_Model
--***************************************************************

--**************************************************************************
--************************ Start Global Scope ******************************
--**************************************************************************
local nameOfModule = 'CSK_ProfileMatcher'

-- Timer to update UI via events after page was loaded
local tmrProfileMatcher = Timer.create()
tmrProfileMatcher:setExpirationTime(300)
tmrProfileMatcher:setPeriodic(false)

-- Reference to global handle
local profileMatcher_Model

-- ************************ UI Events Start ********************************

Script.serveEvent('CSK_ProfileMatcher.OnNewLiDARProviderInstanceAmountList', 'ProfileMatcher_OnNewLiDARProviderInstanceAmountList')
Script.serveEvent('CSK_ProfileMatcher.OnNewStatusSelectedProviderInstance', 'ProfileMatcher_OnNewStatusSelectedProviderInstance')

Script.serveEvent('CSK_ProfileMatcher.OnNewStatusProfileMatchRange', 'ProfileMatcher_OnNewStatusProfileMatchRange')
Script.serveEvent('CSK_ProfileMatcher.OnNewStatusMinimalScore', 'ProfileMatcher_OnNewStatusMinimalScore')
Script.serveEvent('CSK_ProfileMatcher.OnNewStatusCurrentScore', 'ProfileMatcher_OnNewStatusCurrentScore')
Script.serveEvent('CSK_ProfileMatcher.OnNewStatusCurrentScoreString', 'ProfileMatcher_OnNewStatusCurrentScoreString')
Script.serveEvent('CSK_ProfileMatcher.OnNewStatusMatchResult', 'ProfileMatcher_OnNewStatusMatchResult')

Script.serveEvent("CSK_ProfileMatcher.OnNewStatusLoadParameterOnReboot", "ProfileMatcher_OnNewStatusLoadParameterOnReboot")
Script.serveEvent("CSK_ProfileMatcher.OnPersistentDataModuleAvailable", "ProfileMatcher_OnPersistentDataModuleAvailable")
Script.serveEvent("CSK_ProfileMatcher.OnNewParameterName", "ProfileMatcher_OnNewParameterName")
Script.serveEvent("CSK_ProfileMatcher.OnDataLoadedOnReboot", "ProfileMatcher_OnDataLoadedOnReboot")

Script.serveEvent('CSK_ProfileMatcher.OnUserLevelOperatorActive', 'ProfileMatcher_OnUserLevelOperatorActive')
Script.serveEvent('CSK_ProfileMatcher.OnUserLevelMaintenanceActive', 'ProfileMatcher_OnUserLevelMaintenanceActive')
Script.serveEvent('CSK_ProfileMatcher.OnUserLevelServiceActive', 'ProfileMatcher_OnUserLevelServiceActive')
Script.serveEvent('CSK_ProfileMatcher.OnUserLevelAdminActive', 'ProfileMatcher_OnUserLevelAdminActive')

-- ************************ UI Events End **********************************
--**************************************************************************
--********************** End Global Scope **********************************
--**************************************************************************
--**********************Start Function Scope *******************************
--**************************************************************************

-- Functions to forward logged in user roles via CSK_UserManagement module (if available)
-- ***********************************************
--- Function to react on status change of Operator user level
---@param status boolean Status if Operator level is active
local function handleOnUserLevelOperatorActive(status)
  Script.notifyEvent("ProfileMatcher_OnUserLevelOperatorActive", status)
end

--- Function to react on status change of Maintenance user level
---@param status boolean Status if Maintenance level is active
local function handleOnUserLevelMaintenanceActive(status)
  Script.notifyEvent("ProfileMatcher_OnUserLevelMaintenanceActive", status)
end

--- Function to react on status change of Service user level
---@param status boolean Status if Service level is active
local function handleOnUserLevelServiceActive(status)
  Script.notifyEvent("ProfileMatcher_OnUserLevelServiceActive", status)
end

--- Function to react on status change of Admin user level
---@param status boolean Status if Admin level is active
local function handleOnUserLevelAdminActive(status)
  Script.notifyEvent("ProfileMatcher_OnUserLevelAdminActive", status)
end

--- Function to get access to the profileMatcher_Model object
---@param handle handle Handle of profileMatcher_Model  object
local function setProfileMatcher_Model_Handle(handle)
  profileMatcher_Model = handle
  if profileMatcher_Model.userManagementModuleAvailable then
    -- Register on events of CSK_UserManagement module if available
    Script.register('CSK_UserManagement.OnUserLevelOperatorActive', handleOnUserLevelOperatorActive)
    Script.register('CSK_UserManagement.OnUserLevelMaintenanceActive', handleOnUserLevelMaintenanceActive)
    Script.register('CSK_UserManagement.OnUserLevelServiceActive', handleOnUserLevelServiceActive)
    Script.register('CSK_UserManagement.OnUserLevelAdminActive', handleOnUserLevelAdminActive)
  end
  Script.releaseObject(handle)
end

--- Function to update user levels
local function updateUserLevel()
  if profileMatcher_Model.userManagementModuleAvailable then
    -- Trigger CSK_UserManagement module to provide events regarding user role
    CSK_UserManagement.pageCalled()
  else
    -- If CSK_UserManagement is not active, show everything
    Script.notifyEvent("ProfileMatcher_OnUserLevelAdminActive", true)
    Script.notifyEvent("ProfileMatcher_OnUserLevelMaintenanceActive", true)
    Script.notifyEvent("ProfileMatcher_OnUserLevelServiceActive", true)
    Script.notifyEvent("ProfileMatcher_OnUserLevelOperatorActive", true)
  end
end

--- Function to send all relevant values to UI on resume
local function handleOnExpiredTmrProfileMatcher()

  updateUserLevel()

  Script.notifyEvent("ProfileMatcher_OnNewLiDARProviderInstanceAmountList", profileMatcher_Model.helperFuncs.createStringListBySize(profileMatcher_Model.availableInstancesAmount))
  Script.notifyEvent("ProfileMatcher_OnNewStatusSelectedProviderInstance", profileMatcher_Model.parameters.selectedLiDARInstance)

  Script.notifyEvent("ProfileMatcher_OnNewStatusProfileMatchRange", profileMatcher_Model.profileRange)
  Script.notifyEvent("ProfileMatcher_OnNewStatusMinimalScore", profileMatcher_Model.parameters.matchScore)

  Script.notifyEvent("ProfileMatcher_OnNewStatusLoadParameterOnReboot", profileMatcher_Model.parameterLoadOnReboot)
  Script.notifyEvent("ProfileMatcher_OnPersistentDataModuleAvailable", profileMatcher_Model.persistentModuleAvailable)
  Script.notifyEvent("ProfileMatcher_OnNewParameterName", profileMatcher_Model.parametersName)
end
Timer.register(tmrProfileMatcher, "OnExpired", handleOnExpiredTmrProfileMatcher)

-- ********************* UI Setting / Submit Functions Start ********************

local function pageCalled()
  updateUserLevel() -- try to hide user specific content asap
  tmrProfileMatcher:start()
  return ''
end
Script.serveFunction("CSK_ProfileMatcher.pageCalled", pageCalled)

local function selectLiDARProviderInstance(instanceNo)
  _G.logger:info(nameOfModule .. ": Select scan provider instance no. " .. tostring(instanceNo) .. " and register to it.")
  profileMatcher_Model.parameters.selectedLiDARInstance = instanceNo
  profileMatcher_Model.registerToLiDARProvider()
end
Script.serveFunction('CSK_ProfileMatcher.selectLiDARProviderInstance', selectLiDARProviderInstance)

local function registerToLiDARProvider()
  profileMatcher_Model.registerToLiDARProvider()
end
Script.serveFunction('CSK_ProfileMatcher.registerToLiDARProvider', registerToLiDARProvider)

local function setMatchRange(range)
  profileMatcher_Model.profileRange[1] = range[1]
  profileMatcher_Model.profileRange[2] = range[2]

  local startPointMin = Point.create(range[1], 0)
  local endPointMin = Point.create(range[1], -1500)
  local startPointMax = Point.create(range[2], 0)
  local endPointMax = Point.create(range[2], -1500)
  profileMatcher_Model.minLine = Shape.createLineSegment(startPointMin, endPointMin)
  profileMatcher_Model.maxLine = Shape.createLineSegment(startPointMax, endPointMax)
end
Script.serveFunction('CSK_ProfileMatcher.setMatchRange', setMatchRange)

local function setMinScore(minScore)
  _G.logger:info(nameOfModule .. ": Set minimal valid score to " .. tostring(minScore))
  profileMatcher_Model.parameters.matchScore = minScore
end
Script.serveFunction('CSK_ProfileMatcher.setMinScore', setMinScore)

local function teachProfile()
  profileMatcher_Model.doTeach = true
  _G.logger:info(nameOfModule .. ": Set ROI range to " .. tostring(profileMatcher_Model.profileRange[1]) .. " - " .. tostring(profileMatcher_Model.profileRange[2]))
end
Script.serveFunction('CSK_ProfileMatcher.teachProfile', teachProfile)

local function clearTeach()
  _G.logger:info(nameOfModule .. ": Clear teach")
  profileMatcher_Model.parameters.teachedProfile = false
  profileMatcher_Model.parameters.matchProfile = nil
end
Script.serveFunction('CSK_ProfileMatcher.clearTeach', clearTeach)

-- *****************************************************************
-- Following function can be adapted for CSK_PersistentData module usage
-- *****************************************************************

local function setParameterName(name)
  _G.logger:info(nameOfModule .. ": Set parameter name: " .. tostring(name))
  profileMatcher_Model.parametersName = name
end
Script.serveFunction("CSK_ProfileMatcher.setParameterName", setParameterName)

local function sendParameters()
  if profileMatcher_Model.persistentModuleAvailable then
    CSK_PersistentData.addParameter(profileMatcher_Model.helperFuncs.convertTable2Container(profileMatcher_Model.parameters), profileMatcher_Model.parametersName)
    CSK_PersistentData.setModuleParameterName(nameOfModule, profileMatcher_Model.parametersName, profileMatcher_Model.parameterLoadOnReboot)
    _G.logger:info(nameOfModule .. ": Send ProfileMatcher parameters with name '" .. profileMatcher_Model.parametersName .. "' to CSK_PersistentData module.")
    CSK_PersistentData.saveData()
  else
    _G.logger:warning(nameOfModule .. ": CSK_PersistentData module not available.")
  end
end
Script.serveFunction("CSK_ProfileMatcher.sendParameters", sendParameters)

local function loadParameters()
  if profileMatcher_Model.persistentModuleAvailable then
    local data = CSK_PersistentData.getParameter(profileMatcher_Model.parametersName)
    if data then
      _G.logger:info(nameOfModule .. ": Loaded parameters from CSK_PersistentData module.")
      profileMatcher_Model.parameters = profileMatcher_Model.helperFuncs.convertContainer2Table(data)

      -- Configure module with new loaded data
      if profileMatcher_Model.parameters.teachedProfile then
        profileMatcher_Model.teachProfile()
      end

      CSK_ProfileMatcher.pageCalled()
    else
      _G.logger:warning(nameOfModule .. ": Loading parameters from CSK_PersistentData module did not work.")
    end
  else
    _G.logger:warning(nameOfModule .. ": CSK_PersistentData module not available.")
  end
end
Script.serveFunction("CSK_ProfileMatcher.loadParameters", loadParameters)

local function setLoadOnReboot(status)
  profileMatcher_Model.parameterLoadOnReboot = status
  _G.logger:info(nameOfModule .. ": Set new status to load setting on reboot: " .. tostring(status))
end
Script.serveFunction("CSK_ProfileMatcher.setLoadOnReboot", setLoadOnReboot)

--- Function to react on initial load of persistent parameters
local function handleOnInitialDataLoaded()

  if string.sub(CSK_PersistentData.getVersion(), 1, 1) == '1' then

    _G.logger:warning(nameOfModule .. ': CSK_PersistentData module is too old and will not work. Please update CSK_PersistentData module.')

    profileMatcher_Model.persistentModuleAvailable = false
  else

    local parameterName, loadOnReboot = CSK_PersistentData.getModuleParameterName(nameOfModule)

    if parameterName then
      profileMatcher_Model.parametersName = parameterName
      profileMatcher_Model.parameterLoadOnReboot = loadOnReboot
    end

    if profileMatcher_Model.parameterLoadOnReboot then
      loadParameters()
    end
    Script.notifyEvent('ProfileMatcher_OnDataLoadedOnReboot')
  end
end
Script.register("CSK_PersistentData.OnInitialDataLoaded", handleOnInitialDataLoaded)

--- Function to react on update of instance amount of CSK_MultiRemoteLiDAR module
local function handleOnNewStatusInstanceAmount()
  profileMatcher_Model.availableInstancesAmount = CSK_MultiRemoteLiDAR.getInstancesAmount()
  CSK_ProfileMatcher.pageCalled()
end
Script.register('CSK_MultiRemoteLiDAR.OnNewStatusInstanceAmount', handleOnNewStatusInstanceAmount)

--- Function to react on 'OnDataLoadedOnReboot' event of CSK_MultiRemoteLiDAR module
local function handleOnDataLoadedOnReboot()
  handleOnNewStatusInstanceAmount()
  if profileMatcher_Model.parameters.selectedLiDARInstance <= profileMatcher_Model.availableInstancesAmount then
    CSK_ProfileMatcher.selectLiDARProviderInstance(profileMatcher_Model.parameters.selectedLiDARInstance)
  else
    _G.logger:warning(nameOfModule .. ': LiDAR provider instance to register not available...')
  end
end
Script.register('CSK_MultiRemoteLiDAR.OnDataLoadedOnReboot', handleOnDataLoadedOnReboot)


-- *************************************************
-- END of functions for CSK_PersistentData module usage
-- *************************************************

return setProfileMatcher_Model_Handle

--**************************************************************************
--**********************End Function Scope *********************************
--**************************************************************************

