local ShiftLogic = {}
ShiftLogic.__index = ShiftLogic

local function readGearRatios(drivetrainIni)
  local count = drivetrainIni:get('GEARS', 'COUNT', 0)
  if count <= 1 then
    return nil
  end

  local ratios = {}
  for i = 1, count do
    ratios[i] = drivetrainIni:get('GEARS', 'GEAR_' .. i, 0)
  end
  return ratios, drivetrainIni:get('GEARS', 'FINAL', 1)
end

local function loadPowerCurve(carIndex, engineIni)
  local lutName = engineIni:get('HEADER', 'POWER_CURVE', '')
  if lutName == '' then
    return nil
  end

  local lut = ac.DataLUT11.carData(carIndex, lutName)
  if not lut then
    return nil
  end

  lut.useCubicInterpolation = true
  lut.extrapolate = false
  return lut
end

local function getLutBounds(lut)
  local minBound, maxBound = lut:bounds()
  return minBound.x, maxBound.x
end

local function computeShiftRpm(powerCurve, ratioCurrent, ratioNext, minRpm, maxRpm)
  local rpmRatio = ratioNext / ratioCurrent
  local best = maxRpm

  for rpm = minRpm, maxRpm, 25 do
    local nextRpm = rpm * rpmRatio
    if nextRpm >= minRpm then
      local currentForce = powerCurve:get(rpm) * ratioCurrent
      local nextForce = powerCurve:get(nextRpm) * ratioNext
      if nextForce >= currentForce then
        best = rpm
        break
      end
    end
  end

  return math.floor(best + 0.5)
end

function ShiftLogic:new()
  return setmetatable({
    carIndex = -1,
    gearCount = 0,
    limiterRpm = 0,
    shiftRpms = {},
    valid = false,
  }, self)
end

function ShiftLogic:load(carIndex)
  self.carIndex = carIndex or -1
  self.gearCount = 0
  self.limiterRpm = 0
  self.shiftRpms = {}
  self.valid = false

  if carIndex == nil or carIndex < 0 then
    return
  end

  local engineIni = ac.INIConfig.carData(carIndex, 'engine.ini')
  local drivetrainIni = ac.INIConfig.carData(carIndex, 'drivetrain.ini')
  if not engineIni or not drivetrainIni then
    return
  end

  local gearRatios, finalRatio = readGearRatios(drivetrainIni)
  local powerCurve = loadPowerCurve(carIndex, engineIni)
  if not gearRatios or not powerCurve then
    return
  end

  local minCurveRpm, maxCurveRpm = getLutBounds(powerCurve)
  local minRpm = math.max(engineIni:get('ENGINE_DATA', 'MINIMUM', minCurveRpm), minCurveRpm)
  local limiterRpm = engineIni:get('ENGINE_DATA', 'LIMITER', maxCurveRpm)
  local maxRpm = math.min(limiterRpm, maxCurveRpm)

  self.gearCount = #gearRatios
  self.limiterRpm = limiterRpm

  for i = 1, #gearRatios - 1 do
    local currentRatio = gearRatios[i] * finalRatio
    local nextRatio = gearRatios[i + 1] * finalRatio
    self.shiftRpms[i] = computeShiftRpm(powerCurve, currentRatio, nextRatio, minRpm, maxRpm)
  end

  self.valid = true
end

function ShiftLogic:getShiftRpm(gear)
  if not self.valid or not gear or gear <= 0 then
    return nil
  end
  return self.shiftRpms[gear]
end

function ShiftLogic:shouldShift(gear, rpm)
  local shiftRpm = self:getShiftRpm(gear)
  if not shiftRpm or not rpm then
    return false
  end
  return rpm >= shiftRpm
end

return ShiftLogic
