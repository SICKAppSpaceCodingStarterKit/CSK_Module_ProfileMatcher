---@diagnostic disable: undefined-global, redundant-parameter, missing-parameter, undefined-doc-name
--*****************************************************************
-- Inside of this script, you will find the module definition
-- including its parameters and functions
--*****************************************************************

--**************************************************************************
--**********************Start Global Scope *********************************
--**************************************************************************
local nameOfModule = 'CSK_ProfileMatcher'

local profileMatcher_Model = {}

-- Check if CSK_UserManagement module can be used if wanted
profileMatcher_Model.userManagementModuleAvailable = CSK_UserManagement ~= nil or false

-- Check if CSK_PersistentData module can be used if wanted
profileMatcher_Model.persistentModuleAvailable = CSK_PersistentData ~= nil or false

-- Default values for persistent data
-- If available, following values will be updated from data of CSK_PersistentData module (check CSK_PersistentData module for this)
profileMatcher_Model.parametersName = 'CSK_ProfileMatcher_Parameter' -- name of parameter dataset to be used for this module
profileMatcher_Model.parameterLoadOnReboot = false -- Status if parameter dataset should be loaded on app/device reboot

-- Load script to communicate with the ProfileMatcher_Model interface and give access
-- to the ProfileMatcher_Model object.
-- Check / edit this script to see/edit functions which communicate with the UI
local setProfileMatcher_ModelHandle = require('ScanProcessing/ProfileMatcher/ProfileMatcher_Controller')
setProfileMatcher_ModelHandle(profileMatcher_Model)

--Loading helper functions if needed
profileMatcher_Model.helperFuncs = require('ScanProcessing/ProfileMatcher/helper/funcs')

--Loading static parameters
profileMatcher_Model.statics = require('ScanProcessing/ProfileMatcher/helper/LiDARStatics')

-- Handle of provider
profileMatcher_Model.scanProviderHandle = nil

-- Create parameters / instances for this module
profileMatcher_Model.scanQueue = Script.Queue.create() -- Queue to stop processing if increasing too much
profileMatcher_Model.scanQueue:setPriority("MID")
profileMatcher_Model.scanQueue:setMaxQueueSize(1)

-- Amount of instances (defined within CSK_Module_MultiRemoteLiDAR module)
profileMatcher_Model.availableInstancesAmount = 1

-- Viewer to show profile in UI
profileMatcher_Model.viewer = View.create('profileViewer')

-- Profile Matcher
profileMatcher_Model.profileMatcher = Profile.Matching.PatternMatcher.create()

-- definitions to visualize profile range
profileMatcher_Model.matchLineStartPointLeft = Point.create(0, 0)
profileMatcher_Model.matchLineEndPointLeft = Point.create(0, -1500)
profileMatcher_Model.matchLineStartPointRight = Point.create(0 , 0)
profileMatcher_Model.matchLineEndPointRight = Point.create(0, -1500)

profileMatcher_Model.matchLineStart = Shape.createLineSegment(profileMatcher_Model.matchLineStartPointLeft, profileMatcher_Model.matchLineEndPointLeft)
profileMatcher_Model.matchLineEnd = Shape.createLineSegment(profileMatcher_Model.matchLineStartPointRight, profileMatcher_Model.matchLineEndPointRight)

-- holding last matched position
profileMatcher_Model.matchPosInt = 0

-- Parameters to be saved permanently if wanted
profileMatcher_Model.parameters = {}
profileMatcher_Model.parameters.selectedLiDARInstance = 1 -- LiDAR instance to register on

profileMatcher_Model.parameters.teachedProfile = false -- Status if a profile was teached
profileMatcher_Model.parameters.matchProfile = nil -- Teached Profile
profileMatcher_Model.parameters.profileSize = 30 -- Size of the profile to match
profileMatcher_Model.parameters.matchScore = 0.9 -- Acceptable score for matching

-- ROI of the profile
profileMatcher_Model.profileRange = {}
table.insert(profileMatcher_Model.profileRange, -15.0)
table.insert(profileMatcher_Model.profileRange, 15.0)

-- Line segments to show ROI within viewer
profileMatcher_Model.minLine = Shape.createLineSegment(Point.create(profileMatcher_Model.profileRange[1], 0), Point.create(profileMatcher_Model.profileRange[1], -1500))
profileMatcher_Model.maxLine = Shape.createLineSegment(Point.create(profileMatcher_Model.profileRange[2], 0), Point.create(profileMatcher_Model.profileRange[2], -1500))

--**************************************************************************
--********************** End Global Scope **********************************
--**************************************************************************
--**********************Start Function Scope *******************************
--**************************************************************************

--- Function to teach current selected profile
local function teachProfile()
  Profile.Matching.PatternMatcher.setMaximumInvalidValues(profileMatcher_Model.profileMatcher, 20)
  local suc = Profile.Matching.PatternMatcher.teach(profileMatcher_Model.profileMatcher, profileMatcher_Model.parameters.matchProfile, "SAD")
  _G.logger:info(nameOfModule .. ": Profile teach success = " .. tostring(suc))
  profileMatcher_Model.parameters.teachedProfile = suc
end
profileMatcher_Model.teachProfile = teachProfile

--- Function to process incoming scan data
---@param scan Scan Scan data to process
local function handleOnNewProcessing(scan)

  -- crop just the relevant values (degrees) out of full profile
  local reducedScan = profileMatcher_Model.statics.scanFilter:filter(scan)

  -- create profile out of scan and smooth it
  local profile = Scan.toProfile(reducedScan, "DISTANCE")
  local profileSmoothed = Profile.blur(profile, 5)

  -- mirror values (TIM is measuring from above)
  Profile.multiplyConstantInplace(profileSmoothed, -1)

  local scanVector = Profile.toVector(profileSmoothed)
  local correctedScanVactor = {}

  -- calculate values incl. cos correction
  for i = 1, 271, 1 do
    correctedScanVactor[i] = scanVector[i]*profileMatcher_Model.statics.correctness[(i)]
  end

  local correctedProfile = Profile.createFromVector(correctedScanVactor, profileMatcher_Model.statics.anglesValues)

  profileMatcher_Model.viewer:addProfile(correctedProfile, profileMatcher_Model.statics.decoProfile, "profile")

  if profileMatcher_Model.doTeach then

    -- Teach new profile

    local cropedTeachProfile = Profile.crop(correctedProfile, (profileMatcher_Model.profileRange[1]+45)*3, (profileMatcher_Model.profileRange[2]+45)*3)
    profileMatcher_Model.parameters.matchProfile = cropedTeachProfile
    profileMatcher_Model.parameters.profileSize = profileMatcher_Model.profileRange[2] - profileMatcher_Model.profileRange[1]
    teachProfile()
    profileMatcher_Model.doTeach = false

  elseif profileMatcher_Model.parameters.teachedProfile then

    --Check teached Profile if available
    local matchFound

    -- Search for match
    local matchPos, score = Profile.Matching.PatternMatcher.match(profileMatcher_Model.profileMatcher, correctedProfile)
    Script.notifyEvent("ProfileMatcher_OnNewStatusCurrentScoreString", string.format("%.2f", score))

    -- Check if and where profile matched
    if matchPos ~= nil and score >=  profileMatcher_Model.parameters.matchScore then
      matchFound = true
      -- transform from table position to angle
      profileMatcher_Model.matchPosInt = math.floor((matchPos/3)-45)
    else
      matchFound = nil
    end

    -- Show found profile section on UI
    if matchFound ~= nil then
      profileMatcher_Model.matchLineStartPointLeft:setXY(profileMatcher_Model.matchPosInt, 0)
      profileMatcher_Model.matchLineEndPointLeft:setXY(profileMatcher_Model.matchPosInt, -1500)
      profileMatcher_Model.matchLineStartPointRight:setXY(profileMatcher_Model.matchPosInt + profileMatcher_Model.parameters.profileSize, 0)
      profileMatcher_Model.matchLineEndPointRight:setXY(profileMatcher_Model.matchPosInt + profileMatcher_Model.parameters.profileSize, -1500)
      profileMatcher_Model.matchLineStart = Shape.createLineSegment(profileMatcher_Model.matchLineStartPointLeft, profileMatcher_Model.matchLineEndPointLeft)
      profileMatcher_Model.matchLineEnd = Shape.createLineSegment(profileMatcher_Model.matchLineStartPointRight, profileMatcher_Model.matchLineEndPointRight)

      profileMatcher_Model.viewer:addShape(profileMatcher_Model.matchLineStart, profileMatcher_Model.statics.lineDecoGood, "graphLineFound1", "profile")
      profileMatcher_Model.viewer:addShape(profileMatcher_Model.matchLineEnd, profileMatcher_Model.statics.lineDecoGood, "graphLineFound2", "profile")

      Script.notifyEvent("ProfileMatcher_OnNewStatusMatchResult", true)
    else
      Script.notifyEvent("ProfileMatcher_OnNewStatusMatchResult", false)
    end

  else
    -- if no profile teached -> show possible teach selection
    profileMatcher_Model.viewer:addShape(profileMatcher_Model.minLine, profileMatcher_Model.statics.lineDeco, "graphLineID1", "profile")
    profileMatcher_Model.viewer:addShape(profileMatcher_Model.maxLine, profileMatcher_Model.statics.lineDeco, "graphLineID2", "profile")
  end
  profileMatcher_Model.viewer:present("LIVE")
end

--- Function to register on 'OnNewScan' event of handle provided by CSK_MultiRemoteLiDAR module
local function registerToLiDARProvider()
  if profileMatcher_Model.scanProviderHandle then
    -- Make sure to not double registering to OnNewScan event
    Scan.Provider.RemoteScanner.deregister(profileMatcher_Model.scanProviderHandle, "OnNewScan", handleOnNewProcessing)
    Script.releaseObject(profileMatcher_Model.scanProviderHandle)
    profileMatcher_Model.scanProviderHandle = nil
  end

  profileMatcher_Model.scanProviderHandle = CSK_MultiRemoteLiDAR.getLiDARHandle(profileMatcher_Model.parameters.selectedLiDARInstance)
  if profileMatcher_Model.scanProviderHandle then
    _G.logger:info(nameOfModule .. ": Register LiDAR sensor " .. tostring(profileMatcher_Model.parameters.selectedLiDARInstance))
    Scan.Provider.RemoteScanner.register(profileMatcher_Model.scanProviderHandle, "OnNewScan", handleOnNewProcessing)
    profileMatcher_Model.scanQueue:setFunction(handleOnNewProcessing)
  else
    _G.logger:warning(nameOfModule .. ": No provider available to register.")
  end
end
profileMatcher_Model.registerToLiDARProvider = registerToLiDARProvider

--*************************************************************************
--********************** End Function Scope *******************************
--*************************************************************************

return profileMatcher_Model
