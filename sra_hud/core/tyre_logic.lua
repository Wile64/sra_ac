local TyreLogic = {}
TyreLogic.__index = TyreLogic

local function sectionSuffix(compoundIndex)
  if not compoundIndex or compoundIndex <= 0 then
    return ''
  end
  return '_' .. tostring(compoundIndex)
end

local function loadLut(carIndex, fileName)
  if not fileName or fileName == '' then
    return nil
  end

  local lut = ac.DataLUT11.carData(carIndex, fileName)
  if not lut then
    return nil
  end

  lut.useCubicInterpolation = true
  lut.extrapolate = false
  return lut
end

local function getPeakPoint(lut)
  if not lut then
    return nil, nil
  end

  local minBound, maxBound = lut:bounds()
  if not minBound or not maxBound then
    return nil, nil
  end

  local bestX = minBound.x
  local bestY = lut:get(bestX)
  for x = minBound.x, maxBound.x, 1 do
    local y = lut:get(x)
    if y > bestY then
      bestY = y
      bestX = x
    end
  end
  return bestX, bestY
end

local function getIdealRange(lut, thresholdRatio)
  if not lut then
    return nil, nil
  end

  local peakX, peakY = getPeakPoint(lut)
  if not peakX or not peakY or peakY <= 0 then
    return nil, nil
  end

  local minBound, maxBound = lut:bounds()
  local threshold = peakY * (thresholdRatio or 0.985)
  local rangeMin, rangeMax = nil, nil

  for x = minBound.x, maxBound.x, 1 do
    local y = lut:get(x)
    if y >= threshold then
      rangeMin = rangeMin or x
      rangeMax = x
    end
  end

  return rangeMin, rangeMax
end

function TyreLogic:new()
  return setmetatable({
    carIndex = -1,
    compoundIndex = -1,
    valid = false,
    front = {},
    rear = {},
  }, self)
end

function TyreLogic:load(carIndex, compoundIndex)
  self.carIndex = carIndex or -1
  self.compoundIndex = compoundIndex or 0
  self.valid = false
  self.front = {}
  self.rear = {}

  if self.carIndex < 0 then
    return
  end

  local tyresIni = ac.INIConfig.carData(self.carIndex, 'tyres.ini')
  if not tyresIni then
    return
  end

  local suffix = sectionSuffix(self.compoundIndex)
  local frontSection = 'FRONT' .. suffix
  local rearSection = 'REAR' .. suffix
  local thermalFrontSection = 'THERMAL_FRONT' .. suffix
  local thermalRearSection = 'THERMAL_REAR' .. suffix

  local function buildInfo(mainSection, thermalSection)
    local performanceCurve = loadLut(self.carIndex, tyresIni:get(thermalSection, 'PERFORMANCE_CURVE', ''))
    local wearCurve = loadLut(self.carIndex, tyresIni:get(mainSection, 'WEAR_CURVE', ''))
    local idealTemperature, peakPerformance = getPeakPoint(performanceCurve)
    local idealMinTemperature, idealMaxTemperature = getIdealRange(performanceCurve, 0.995)
    local wearCurveMaxKM = 0
    if wearCurve then
      local _, wearMaxBound = wearCurve:bounds()
      wearCurveMaxKM = wearMaxBound and wearMaxBound.x or 0
    end
    return {
      idealPressure = tyresIni:get(mainSection, 'PRESSURE_IDEAL', 0),
      coldPressure = tyresIni:get(mainSection, 'PRESSURE_STATIC', 0),
      falloffLevel = tyresIni:get(mainSection, 'FALLOFF_LEVEL', 0),
      performanceCurve = performanceCurve,
      wearCurve = wearCurve,
      wearCurveMaxKM = wearCurveMaxKM,
      idealTemperature = idealTemperature or 0,
      idealMinTemperature = idealMinTemperature or 0,
      idealMaxTemperature = idealMaxTemperature or 0,
      peakPerformance = peakPerformance or 1,
    }
  end

  self.front = buildInfo(frontSection, thermalFrontSection)
  self.rear = buildInfo(rearSection, thermalRearSection)
  self.valid = true
end

function TyreLogic:getAxleInfo(wheelIndex)
  if wheelIndex == 1 or wheelIndex == 2 then
    return self.front
  end
  return self.rear
end

function TyreLogic:evaluateWheel(wheelIndex, pressurePsi, coreTempC, optimumTempC, tyreVirtualKM)
  local axle = self:getAxleInfo(wheelIndex)
  local idealPressure = axle.idealPressure or 0
  local idealTemp = axle.idealTemperature or 0
  local pressureDelta = idealPressure > 0 and (pressurePsi - idealPressure) or 0

  local performanceRatio = nil
  if axle.performanceCurve and axle.peakPerformance and axle.peakPerformance > 0 then
    performanceRatio = axle.performanceCurve:get(coreTempC) / axle.peakPerformance
  end

  local wearGrip = nil
  if axle.wearCurve and axle.wearCurveMaxKM and axle.wearCurveMaxKM > 0 then
    local virtualKM = math.max(0, tyreVirtualKM or 0)
    wearGrip = axle.wearCurve:get(math.min(virtualKM, axle.wearCurveMaxKM))
  end

  return {
    idealPressure = idealPressure,
    coldPressure = axle.coldPressure or 0,
    idealTemp = idealTemp > 0 and idealTemp or (optimumTempC or 0),
    idealMinTemp = axle.idealMinTemperature or 0,
    idealMaxTemp = axle.idealMaxTemperature or 0,
    pressureDelta = pressureDelta,
    performanceRatio = performanceRatio and math.max(0, math.min(1.2, performanceRatio)) or nil,
    wearGrip = wearGrip,
    hasPerformanceCurve = axle.performanceCurve ~= nil,
    falloffLevel = axle.falloffLevel or 0,
  }
end

return TyreLogic
