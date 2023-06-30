---@diagnostic disable: undefined-global, redundant-parameter, missing-parameter, undefined-field
--***************************************************************
-- Inside of this script, you will find static parameters / functions
-- to be used from the LiDAR class.
--***************************************************************

--**************************************************************************
--**********************Start Global Scope *********************************
--**************************************************************************

local params = {}

-- use to crop scan range of -45° - 45°
params.scanFilter =  Scan.AngleRangeFilter.create()
params.scanFilter:setThetaRange(math.rad(-45.1), math.rad(45))

-- TIM angle values (-45° - 45° in 0.33° steps --> 271 steps)
local angles = {}
angles[#angles + 1] = -44.99 / 180 * math.pi

params.anglesValues = {}
params.anglesValues[#params.anglesValues + 1] = -44.99

for i = -45, 44, 1 do
  for j = 1, 3 do
    angles[#angles + 1] = ((j*0.33)+i) / 180 * math.pi
    params.anglesValues[#params.anglesValues + 1] = ((j*0.33)+i)
  end
end

-- Calculate cos correction of the values
params.correctness = {}
for _ = 1, 271, 1 do
    params.correctness[#params.correctness + 1] = math.cos(angles[#params.correctness + 1])
end

-- scan viewer Decoration
params.decoProfile = View.GraphDecoration.create()
params.decoProfile:setPolarPlot(false)
params.decoProfile:setGraphColor(0, 0, 255, 255)
params.decoProfile:setGraphType('LINE')
params.decoProfile:setDynamicSizing(true)
params.decoProfile:setYBounds(-1500, 0)
params.decoProfile:setXBounds(-45, 45)
params.decoProfile:setAxisVisible(true)
params.decoProfile:setLabelsVisible(true)
params.decoProfile:setGridVisible(true)
params.decoProfile:setTicksVisible(false)

-- decorations for viewer elements
params.lineDeco = View.ShapeDecoration.create()
params.lineDeco:setLineColor(255, 210, 0)
params.lineDeco:setLineWidth(0.3)

params.lineDecoGood = View.ShapeDecoration.create()
params.lineDecoGood:setLineColor(0, 255, 0)
params.lineDecoGood:setLineWidth(0.5)

return params

--**************************************************************************
--**********************End Global Scope ***********************************
--**************************************************************************