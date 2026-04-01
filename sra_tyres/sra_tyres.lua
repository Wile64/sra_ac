--
-- Created by Wile64 on october 2023
--

VERSION = 1.5

local function loadTyreInfo(self)
  local tyreini = ac.INIConfig.carData(0, 'tyres.ini')
  local front = "FRONT"
  local rear = "REAR"
  if self.carState.compoundIndex > 0 then
    front = front .. "_" .. tostring(self.carState.compoundIndex)
    rear = rear .. "_" .. tostring(self.carState.compoundIndex)
  end
  local suffix = self.carState.compoundIndex > 0 and ('_' .. tostring(self.carState.compoundIndex)) or ''

  self.frontWearCurve = tyreini:tryGetLut('FRONT' .. suffix, 'WEAR_CURVE') or tyreini:tryGetLut('FRONT', 'WEAR_CURVE')
  self.rearWearCurve = tyreini:tryGetLut('REAR' .. suffix, 'WEAR_CURVE') or tyreini:tryGetLut('REAR', 'WEAR_CURVE')
  self.frontThermalCurve = tyreini:tryGetLut('THERMAL_FRONT' .. suffix, 'PERFORMANCE_CURVE')
      or tyreini:tryGetLut('THERMAL_FRONT', 'PERFORMANCE_CURVE')
  self.rearThermalCurve = tyreini:tryGetLut('THERMAL_REAR' .. suffix, 'PERFORMANCE_CURVE')
      or tyreini:tryGetLut('THERMAL_REAR', 'PERFORMANCE_CURVE')
  self.surfaceData.front.available =
      tyreini:get('THERMAL_FRONT' .. suffix, 'GRAIN_GAIN', 0) > 0
      or tyreini:get('THERMAL_FRONT' .. suffix, 'BLISTER_GAIN', 0) > 0
      or tyreini:get('THERMAL_FRONT', 'GRAIN_GAIN', 0) > 0
      or tyreini:get('THERMAL_FRONT', 'BLISTER_GAIN', 0) > 0

  self.surfaceData.rear.available =
      tyreini:get('THERMAL_REAR' .. suffix, 'GRAIN_GAIN', 0) > 0
      or tyreini:get('THERMAL_REAR' .. suffix, 'BLISTER_GAIN', 0) > 0
      or tyreini:get('THERMAL_REAR', 'GRAIN_GAIN', 0) > 0
      or tyreini:get('THERMAL_REAR', 'BLISTER_GAIN', 0) > 0

  self.idealFrontPressure = tyreini:get('FRONT' .. suffix, 'PRESSURE_IDEAL', 0) or
      tyreini:get('FRONT', 'PRESSURE_IDEAL', 0)
  self.idealRearPressure = tyreini:get('REAR' .. suffix, 'PRESSURE_IDEAL', 0) or tyreini:get('REAR', 'PRESSURE_IDEAL', 0)

  self.minThermal = 0
  self.maxThermal = 0
  if self.frontThermalCurve ~= nil then
    for i = 0, #self.frontThermalCurve - 1 do
      if self.frontThermalCurve:getPointOutput(i) > 0.99 then
        local input = self.frontThermalCurve:getPointInput(i)
        if self.maxThermal < input then
          self.maxThermal = input
        end
        if self.minThermal == 0 then
          self.minThermal = input
        end
      end
    end
  else
    self.minThermal = 80
    self.maxThermal = self:getTyreFL().tyreOptimumTemperature
  end
end

local function loadDiscInfo(self)
  local brakeini = ac.INIConfig.carData(0, 'brakes.ini')

  local frontCurve = brakeini:tryGetLut("TEMPS_FRONT", "PERF_CURVE")
  if frontCurve ~= nil then
    self.isDiscLoaded = true
    self.isDiscAvailable = true

    local min, max = frontCurve:bounds()
    self.discData.minFrontTemp = min.x
    self.discData.maxFrontTemp = max.x
    for i = 0, #frontCurve - 1 do
      if frontCurve:getPointOutput(i) == 1 then
        local input = frontCurve:getPointInput(i)
        if self.discData.idealMaxFrontTemp < input then
          self.discData.idealMaxFrontTemp = input
        end
        if self.discData.idealMinFrontTemp == 0 then
          self.discData.idealMinFrontTemp = input
        end
      end
    end
  else
    self.isDiscLoaded = false
    self.isDiscAvailable = false
    return
  end

  local rearCurve = brakeini:tryGetLut("TEMPS_REAR", "PERF_CURVE")
  if rearCurve ~= nil then
    self.isDiscLoaded = true
    self.isDiscAvailable = true

    local min, max = rearCurve:bounds()
    self.discData.minRearTemp = min.x
    self.discData.maxRearTemp = max.x
    for i = 0, #rearCurve - 1 do
      if rearCurve:getPointOutput(i) == 1 then
        local input = rearCurve:getPointInput(i)
        if self.discData.idealMaxRearTemp < input then
          self.discData.idealMaxRearTemp = input
        end
        if self.discData.idealMinRearTemp == 0 then
          self.discData.idealMinRearTemp = input
        end
      end
    end
  else
    self.isDiscLoaded = false
    self.isDiscAvailable = false
    return
  end
end

local carData = {
  carState = nil,
  idealFrontPressure = 0,
  idealRearPressure = 0,
  carID = 0,
  currentCompoundIndex = -1,
  frontWearCurve = nil,
  rearWearCurve = nil,
  frontThermalCurve = nil,
  rearThermalCurve = nil,
  minThermal = 0,
  maxThermal = 0,
  isDiscLoaded = false,
  isDiscAvailable = true,
  isDiscLiveAvailable = false,
  discData = {
    minFrontTemp = 0,
    maxFrontTemp = 0,
    idealMinFrontTemp = 0,
    idealMaxFrontTemp = 0,
    idealMaxFrontMaxEff = 0,
    minRearTemp = 0,
    maxRearTemp = 0,
    idealMinRearTemp = 0,
    idealMaxRearTemp = 0,
    idealMaxRearMaxEff = 0,
  },
  discLiveData = {
    mode = 'unknown',
    timer = 0,
    discMoved = false,
    brakeMoved = false,
    lastDisc = { [0] = nil, [1] = nil, [2] = nil, [3] = nil },
    lastBrake = { [0] = nil, [1] = nil, [2] = nil, [3] = nil },
  },
  surfaceData = {
    front = {
      available = false,
    },
    rear = {
      available = false,
    },
  }
}

function carData:setCarID(id)
  if self.carID ~= id then
    self.carID = id
  end
end

function carData:getTyreFL()
  return self.carState.wheels[0]
end

function carData:getTyreFR()
  return self.carState.wheels[1]
end

function carData:getTyreRL()
  return self.carState.wheels[2]
end

function carData:getTyreRR()
  return self.carState.wheels[3]
end

function carData:safeDiscTemperature(tyre)
  local ok, value = pcall(function() return tyre.discTemperature end)
  if ok then return value end
  return nil
end

function carData:safeBrakeTemperature(tyre)
  local ok, value = pcall(function() return tyre.brakeTemperature end)
  if ok then return value end
  return nil
end

function carData:updateDiscLiveData(dt)
  if not self.carState or not self.isDiscLoaded then
    return
  end

  self.discLiveData.timer = self.discLiveData.timer + dt
  for wheelID = 0, 3 do
    local wheel = self.carState.wheels[wheelID]
    local discTemp = wheel and self:safeDiscTemperature(wheel) or nil
    local brakeTemp = wheel and self:safeBrakeTemperature(wheel) or nil

    if discTemp ~= nil and self.discLiveData.lastDisc[wheelID] ~= nil and
        math.abs(discTemp - self.discLiveData.lastDisc[wheelID]) > 0.05 then
      self.discLiveData.discMoved = true
    end
    if brakeTemp ~= nil and self.discLiveData.lastBrake[wheelID] ~= nil and
        math.abs(brakeTemp - self.discLiveData.lastBrake[wheelID]) > 0.05 then
      self.discLiveData.brakeMoved = true
    end

    self.discLiveData.lastDisc[wheelID] = discTemp
    self.discLiveData.lastBrake[wheelID] = brakeTemp
  end

  if self.discLiveData.discMoved then
    self.discLiveData.mode = 'disc'
    self.isDiscLiveAvailable = true
  elseif self.discLiveData.brakeMoved then
    self.discLiveData.mode = 'brake'
    self.isDiscLiveAvailable = true
  elseif self.discLiveData.timer > 2.5 then
    self.discLiveData.mode = 'none'
    self.isDiscLiveAvailable = false
  end
end

function carData:getDiscTemp(tyre, tyreID)
  if self.discLiveData.mode == 'disc' then
    return self:safeDiscTemperature(tyre)
  elseif self.discLiveData.mode == 'brake' then
    return self:safeBrakeTemperature(tyre)
  elseif tyreID ~= nil and self.discLiveData.lastDisc[tyreID] ~= nil then
    return self.discLiveData.lastDisc[tyreID]
  else
    return self:safeDiscTemperature(tyre)
  end
end

function carData:update(dt)
  local carstate = ac.getCar(self.carID)
  if carstate ~= nil then
    self.carState = carstate
    if self.currentCompoundIndex ~= self.carState.compoundIndex then
      loadTyreInfo(self)
      self.currentCompoundIndex = self.carState.compoundIndex
    end
    if self.isDiscLoaded == false and self.isDiscAvailable then
      loadDiscInfo(self)
    end
    if self.isDiscLoaded then
      self:updateDiscLiveData(dt)
    end
  end
end

local isAppVisible     = true
local isShowGripInfo   = false

local settings         = ac.storage {
  Scale = 1,
  showOptimal = true,
  showTyreName = true,
  showGrain = true,
  showBlister = true,
  showFlatSpot = true,
  showDisc = true,
  showCamberRotation = true,
  showWearGrip = true,
}

local gripInfos        = {
  frontLoaded = false,
  frontHigh = 0,
  frontMedium = 0,
  frontLow = 0,
  rearLoaded = false,
  rearHigh = 0,
  rearMedium = 0,
  rearLow = 0,
}

local images           = {
  brakeDiscLeft = "/images/BrakeDiscleft.png",
  brakeDiscRight = "/images/BrakeDiscright.png",
  slip = "/images/slip.png"
}

local gripCache        = {
  valid = false,
  compoundIndex = -1,
  frontWearCurve = nil,
  rearWearCurve = nil,
  tyreConsumptionRate = -1,
  trackLengthKm = -1,
}

local tyrewheelLocks   = {
  [0] = { wheelLock = false, flatSpotValue = 0 },
  [1] = { wheelLock = false, flatSpotValue = 0 },
  [2] = { wheelLock = false, flatSpotValue = 0 },
  [3] = { wheelLock = false, flatSpotValue = 0 },
}
local FLATSPOT_EPSILON = 1e-5
local PANEL_BACKGROUND = rgbm(0.12, 0.12, 0.12, 0.9)
local TEXT_COLOR       = rgbm.colors.white

local function drawVerticalProgressBar(progress, size, color)
  local clampedProgress = math.min(math.max(progress, 0), 1)

  local pos             = ui.getCursor()
  local fillTop         = pos.y + size.y * (1 - clampedProgress)
  if clampedProgress > 0 then
    ui.drawRectFilled(vec2(pos.x, fillTop), pos + size, color, 3)
  end
  ui.drawRect(pos, pos + size, rgbm.colors.gray, 3)
  ui.dummy(size)
end

local function drawTrackedVerticalBar(progress, barSize, fillColor, bgColor, label)
  ui.beginGroup()
  local pos = ui.getCursor()
  local labelHeight = math.min(10 * settings.Scale, barSize.y * 0.22)
  ui.drawRectFilled(pos, pos + barSize, bgColor, 3)
  local clampedProgress = math.min(math.max(progress or 0, 0), 1)
  if clampedProgress > 0 then
    local fillTop = pos.y + barSize.y * (1 - clampedProgress)
    ui.drawRectFilled(vec2(pos.x, fillTop), pos + barSize, fillColor, 3)
  end
  ui.drawRect(pos, pos + barSize, rgbm.colors.gray, 3)
  ui.dummy(barSize)

  local labelPos = ui.getCursor()
  local labelSize = vec2(barSize.x, labelHeight)
  ui.drawRectFilled(labelPos, labelPos + labelSize, bgColor, 3)
  ui.dwriteDrawTextClipped(label or "", 7 * settings.Scale, labelPos, labelPos + labelSize,
    ui.Alignment.Center, ui.Alignment.Center, false, TEXT_COLOR)
  ui.dummy(labelSize)
  ui.endGroup()
end

local function drawTyreTooltip(text)
  if ui.itemHovered() then
    ui.tooltip(function()
      ui.pushFont(ui.Font.Monospace)
      ui.text(text)
      ui.popFont()
    end)
  end
end

local function wearColorFor(virtualKM, isFront)
  local lut = isFront and carData.frontWearCurve or carData.rearWearCurve
  if not lut then return rgbm.colors.green end
  local g = lut:get(virtualKM)
  if g >= 98 then
    return rgbm.colors.green
  elseif g > 96 then
    return rgbm.colors.yellow
  else
    return rgbm.colors.red
  end
end


local function computeGripRanges(lut, tyreConsumptionRate)
  local high, medium, low = 0, 0, 0
  if lut == nil then
    return high, medium, low
  end
  for i = 0, #lut - 1 do
    local grip = lut:getPointOutput(i)
    local km = 10 * lut:getPointInput(i) / tyreConsumptionRate
    if grip > 98 then
      high = km
    elseif grip > 96 then
      medium = km
    else
      low = km
    end
  end
  return high, medium, low
end

local function clamp(v, a, b)
  if v < a then return a end
  if v > b then return b end
  return v
end

local function getSafeCamber(tyre)
  local ok, camber = pcall(function()
    return tyre.camber
  end)
  if not ok or type(camber) ~= 'number' then
    return 0
  end
  return clamp(camber, -4, 4)
end

local function curveToFactor(v)
  if v == nil then return 1 end
  if v > 1.5 then return clamp(v / 100, 0, 1) end
  return clamp(v, 0, 1)
end

local function computeTyreGripPercent(tyre, isFront)
  local wearCurve = isFront and carData.frontWearCurve or carData.rearWearCurve
  local thermalCurve = isFront and carData.frontThermalCurve or carData.rearThermalCurve
  local wearF = wearCurve and curveToFactor(wearCurve:get(tyre.tyreVirtualKM or 0))
      or clamp(1 - (tyre.tyreWear or 0), 0, 1)
  local thermalF = thermalCurve and curveToFactor(thermalCurve:get(tyre.tyreCoreTemperature or 0)) or 1
  return clamp(wearF * thermalF * 100, 0, 120)
end

local function getTyreColor(tyreTemp)
  local minValue = carData.minThermal
  local maxValue = carData.maxThermal
  local redComponent = 0
  local greenComponent = 0
  local blueComponent = 0

  local mappedProgress
  if tyreTemp < minValue then
    mappedProgress = (minValue - tyreTemp) / 20
  elseif tyreTemp > maxValue then
    mappedProgress = (tyreTemp - maxValue) / 20
  else
    mappedProgress = 1
  end
  mappedProgress = math.min(math.max(mappedProgress, 0), 1)
  if tyreTemp < minValue then
    greenComponent = 1 - mappedProgress
    blueComponent = mappedProgress
  elseif tyreTemp > maxValue then
    greenComponent = 1 - mappedProgress
    redComponent = mappedProgress
  else
    greenComponent = mappedProgress
  end
  return rgbm(redComponent, greenComponent, blueComponent, 0.7)
end

local function getDiscColor(DiscTemp, front)
  if not carData.isDiscLiveAvailable then
    return rgbm(0.65, 0.65, 0.65, 1)
  end
  local redComponent   = 0
  local greenComponent = 0
  local blueComponent  = 0
  local idealMinValue  = 0
  local idealMaxValue  = 0
  local minValue       = 0
  local maxValue       = 0
  if front then
    idealMinValue = carData.discData.idealMinFrontTemp
    minValue = carData.discData.minFrontTemp
    idealMaxValue = carData.discData.idealMaxFrontTemp
    maxValue = carData.discData.maxFrontTemp
  else
    idealMinValue = carData.discData.idealMinRearTemp
    minValue = carData.discData.minRearTemp
    idealMaxValue = carData.discData.idealMaxRearTemp
    maxValue = carData.discData.maxRearTemp
  end

  local mappedProgress
  if DiscTemp < idealMinValue then
    local denom = math.max(idealMinValue - minValue, 1e-6)
    mappedProgress = (idealMinValue - DiscTemp) / denom
  elseif DiscTemp > idealMaxValue then
    local denom = math.max(maxValue - idealMaxValue, 1e-6)
    mappedProgress = (DiscTemp - idealMaxValue) / denom
  else
    mappedProgress = 1
  end
  mappedProgress = math.min(math.max(mappedProgress, 0), 1)
  if DiscTemp < idealMinValue then
    greenComponent = 1 - mappedProgress
    blueComponent = mappedProgress
  elseif DiscTemp > idealMaxValue then
    greenComponent = 1 - mappedProgress
    redComponent = mappedProgress
  else
    greenComponent = mappedProgress
  end
  return rgbm(redComponent, greenComponent, blueComponent, 1)
end

local function drawWearProgress(tyre, rectSize, isFront)
  drawVerticalProgressBar(tyre.isBlown == false and 1 - tyre.tyreWear or 0, vec2(12 * settings.Scale, rectSize.y),
    wearColorFor(tyre.tyreVirtualKM, isFront))
  drawTyreTooltip("Tyre Wear")
end

local function surfaceColor(rawValue)
  local value = clamp(rawValue or 0, 0, 1)
  if value < 0.20 then
    return rgbm(0.20, 0.85, 0.20, 1)
  elseif value < 0.45 then
    return rgbm(0.95, 0.85, 0.20, 1)
  elseif value < 0.70 then
    return rgbm(1.00, 0.55, 0.10, 1)
  else
    return rgbm(0.95, 0.20, 0.20, 1)
  end
end

local function drawBox(pos, size, color, rounding)
  ui.drawRectFilled(pos, pos + size, color, rounding or 4)
end

local function drawCenteredTextBox(text, pos, size, fontSize, bgColor, textColor)
  drawBox(pos, size, bgColor or PANEL_BACKGROUND, 4)
  ui.dwriteDrawTextClipped(text, fontSize, pos, pos + size, ui.Alignment.Center, ui.Alignment.Center, false,
    textColor or TEXT_COLOR)
end

local function drawDisc(tyre, rectSize, isFront, isLeft)
  local discWidth = math.max(16 * settings.Scale, rectSize.x)
  local discSize = vec2(discWidth, rectSize.y)
  local pos = ui.getCursor()
  local image = isLeft and images.brakeDiscLeft or images.brakeDiscRight
  local tyreID = (isFront and 0 or 2) + (isLeft and 0 or 1)
  local discColor = getDiscColor(carData:getDiscTemp(tyre, tyreID), isFront)
  local p1 = pos + vec2(2, 2)
  local p2 = pos + discSize - vec2(2, 2)
  ui.drawImage(image, p1, p2, discColor)
  ui.dummy(discSize)
end

local function isWheelSlipping(wheel)
  if not wheel or wheel.isBlown then
    return false
  end

  local slip = math.abs(wheel.ndSlip or 0)
  local slipRatio = math.abs(wheel.slipRatio or 0)
  local slipAngle = math.abs(wheel.slipAngle or 0)
  return slipRatio > 0.10 or slipAngle > 5 or slip > 1
end

local function drawInfoBarsCompact(tyre, rectSize, reverseOrder, isFront)
  local barWidth = 10 * settings.Scale
  local labelHeight = math.min(10 * settings.Scale, rectSize.y * 0.22)
  local trackedBarHeight = math.max(18 * settings.Scale, rectSize.y - labelHeight)
  local surfaceAvailable = isFront and carData.surfaceData.front.available or carData.surfaceData.rear.available
  local barConfigs = {
    { settings.showFlatSpot,                     tyre.tyreFlatSpot,                  rgbm.colors.silver,             rgbm(0.32, 0.32, 0.36, 0.55), "F", "FlatSpot" },
    { settings.showBlister and surfaceAvailable, clamp(tyre.tyreBlister or 0, 0, 1), surfaceColor(tyre.tyreBlister), rgbm(0.33, 0.24, 0.12, 0.55), "B", "Blister" },
    { settings.showGrain and surfaceAvailable,   clamp(tyre.tyreGrain or 0, 0, 1),   surfaceColor(tyre.tyreGrain),   rgbm(0.22, 0.12, 0.12, 0.55), "G", "Grain" },
  }

  local order = reverseOrder and { 3, 2, 1 } or { 1, 2, 3 }
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(2 * settings.Scale, 0))
  local drawn = false
  for _, i in ipairs(order) do
    local barConfig = barConfigs[i]
    if barConfig[1] then
      if drawn then ui.sameLine() end
      drawTrackedVerticalBar(barConfig[2], vec2(barWidth, trackedBarHeight), barConfig[3], barConfig[4], barConfig[5])
      drawTyreTooltip("Tyre " .. barConfig[6])
      drawn = true
    end
  end
  ui.popStyleVar()
end

local function drawTyreCard(tyre, rectSize, isFront, isLeft)
  ui.beginGroup()
  local pos = ui.getCursor()
  local sectionSpacing = 2 * settings.Scale
  local bandWidth = rectSize.x * 3 + sectionSpacing * 2
  local tempBandHeight = 12 * settings.Scale
  local coreHeight = 44 * settings.Scale
  local valueRowHeight = 11 * settings.Scale
  local gripRowHeight = settings.showWearGrip and (15 * settings.Scale) or 0
  local innerWidth = (bandWidth - sectionSpacing * 2) / 3
  local coreInset = math.max(1, 6 * settings.Scale - 5)
  local tyreBodyHeight = tempBandHeight * 2 + coreHeight + sectionSpacing * 2

  local displayTemps = isLeft and {
    tyre.tyreOutsideTemperature,
    tyre.tyreMiddleTemperature,
    tyre.tyreInsideTemperature,
  } or {
    tyre.tyreInsideTemperature,
    tyre.tyreMiddleTemperature,
    tyre.tyreOutsideTemperature,
  }

  local tyreID = (isFront and 0 or 2) + (isLeft and 0 or 1)
  local isBlown = tyre.isBlown
  if math.abs(tyrewheelLocks[tyreID].flatSpotValue - tyre.tyreFlatSpot) > FLATSPOT_EPSILON then
    tyrewheelLocks[tyreID].flatSpotValue = tyre.tyreFlatSpot
    tyrewheelLocks[tyreID].wheelLock = true
  else
    tyrewheelLocks[tyreID].wheelLock = false
  end

  local coreWidth = math.min(bandWidth, bandWidth - coreInset * 2 + 10 * settings.Scale)
  local corePos = pos + vec2((bandWidth - coreWidth) * 0.5, tempBandHeight + sectionSpacing)
  local coreSize = vec2(coreWidth, coreHeight)

  for k = 0, 2 do
    local p1 = vec2(pos.x + k * (innerWidth + sectionSpacing), pos.y)
    local p2 = p1 + vec2(innerWidth, tyreBodyHeight)
    local temp = displayTemps[k + 1]
    ui.drawRectFilled(p1, p2, isBlown and rgbm(0, 0, 0, 1) or getTyreColor(temp), (k == 0 or k == 2) and 4 or 3)
  end

  if tyre.tyreDirty > 0 and not isBlown then
    local dirtAmount = math.max(0, math.min(tyre.tyreDirty, 1))
    local dirtColor = rgbm(0.34, 0.27, 0.08, 1)
    local dirtHeight = tyreBodyHeight * dirtAmount
    for k = 0, 2 do
      local p1 = vec2(pos.x + k * (innerWidth + sectionSpacing), pos.y)
      local p2 = p1 + vec2(innerWidth, tyreBodyHeight)
      ui.drawRectFilled(vec2(p1.x, p2.y - dirtHeight), p2, dirtColor, (k == 0 or k == 2) and 4 or 3)
    end
  end

  local coreColor = (tyrewheelLocks[tyreID].wheelLock or isBlown)
      and rgbm(1, 1, 1, 0.7)
      or getTyreColor(tyre.tyreCoreTemperature)
  ui.drawRectFilled(corePos, corePos + coreSize, coreColor, 5)

  if isWheelSlipping(tyre) then
    ui.drawImage(images.slip, pos, pos + vec2(bandWidth, tyreBodyHeight), rgbm.colors.orange)
  end

  local idealPressure = isFront and carData.idealFrontPressure or carData.idealRearPressure
  local deltaText = "N/A"
  if idealPressure ~= nil and idealPressure > 0 then
    deltaText = string.format("%+.1f", tyre.tyrePressure - idealPressure)
  end
  local infoText = isBlown and "Blown" or
      string.format("Core %d C\n%.1f PSI\n%s", tyre.tyreCoreTemperature, tyre.tyrePressure, deltaText)
  ui.dwriteDrawTextClipped(infoText, 11 * settings.Scale, corePos, corePos + coreSize, ui.Alignment.Center,
    ui.Alignment.Center, false, rgbm.colors.black)
  ui.dummy(vec2(bandWidth, tyreBodyHeight + sectionSpacing))

  local temperature = {
    isBlown and "--" or string.format("%d", displayTemps[1]),
    isBlown and "--" or string.format("%d", displayTemps[2]),
    isBlown and "--" or string.format("%d", displayTemps[3]),
  }
  pos = ui.getCursor()
  for k = 0, 2 do
    local p1 = vec2(pos.x + k * (innerWidth + sectionSpacing), pos.y)
    drawCenteredTextBox(temperature[k + 1], p1, vec2(innerWidth, valueRowHeight), 8 * settings.Scale,
      PANEL_BACKGROUND, TEXT_COLOR)
  end
  ui.dummy(vec2(bandWidth, valueRowHeight))

  if settings.showWearGrip then
    pos = ui.getCursor()
    drawCenteredTextBox(string.format("Grip %0.2f%%", computeTyreGripPercent(tyre, isFront)),
      pos, vec2(bandWidth, gripRowHeight), 8 * settings.Scale, PANEL_BACKGROUND, TEXT_COLOR)
    ui.dummy(vec2(bandWidth, gripRowHeight))
  end
  ui.endGroup()
end

local function drawTyreLayoutLeft(tyre, rectSize, isFront)
  ui.beginGroup()
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(4 * settings.Scale, 0))
  drawInfoBarsCompact(tyre, rectSize, true, isFront)
  ui.sameLine()

  ui.beginRotation()
  drawTyreCard(tyre, rectSize, isFront, true)
  ui.popStyleVar()
  if settings.showDisc and carData.isDiscAvailable then
    ui.pushStyleVar(ui.StyleVar.ItemSpacing, 0)
    ui.sameLine()
    drawDisc(tyre, rectSize, isFront, true)
    ui.popStyleVar()
  end
  ui.endRotation(90 + (settings.showCamberRotation and getSafeCamber(tyre) or 0))
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(4 * settings.Scale, 0))
  ui.sameLine()
  drawWearProgress(tyre, rectSize, isFront)
  ui.popStyleVar()
  ui.endGroup()
end

local function drawTyreLayoutRight(tyre, rectSize, isFront)
  ui.beginGroup()
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(4 * settings.Scale, 0))
  drawWearProgress(tyre, rectSize, isFront)
  ui.sameLine()
  ui.popStyleVar()
  ui.beginRotation()
  if settings.showDisc and carData.isDiscAvailable then
    ui.pushStyleVar(ui.StyleVar.ItemSpacing, 0)
    drawDisc(tyre, rectSize, isFront, false)
    ui.sameLine()
    ui.popStyleVar()
  end
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(4 * settings.Scale, 0))
  drawTyreCard(tyre, rectSize, isFront, false)
  ui.endRotation(90 - (settings.showCamberRotation and getSafeCamber(tyre) or 0))
  ui.sameLine()
  drawInfoBarsCompact(tyre, rectSize, false, isFront)
  ui.popStyleVar()
  ui.endGroup()
end

local function showGripInfo(pos, size)
  ui.beginTransparentWindow("showInfo", pos, size, true, ui.WindowFlags.AlwaysAutoResize)
  local contentSize = ui.windowSize()
  ui.drawRectFilled(ui.getCursor(), ui.getCursor() + contentSize, rgbm(0.2, 0.2, 0.2, 1), 15,
    ui.CornerFlags.TopRight + ui.CornerFlags.BottomRight)
  ui.pushDWriteFont('montserrat:/fonts')
  local simState = ac.getSim()
  local trackLengthKm = math.max(simState.trackLengthM / 1000, 1e-6)
  local tyreConsumptionRate = math.max(simState.tyreConsumptionRate, 1e-6)
  local frontWearCurve = carData.frontWearCurve
  local rearWearCurve = carData.rearWearCurve
  local compoundIndex = carData.carState and carData.carState.compoundIndex or -1

  local isGripCacheInvalid = not gripCache.valid
      or gripCache.compoundIndex ~= compoundIndex
      or gripCache.frontWearCurve ~= frontWearCurve
      or gripCache.rearWearCurve ~= rearWearCurve
      or math.abs(gripCache.tyreConsumptionRate - tyreConsumptionRate) > 1e-6
      or math.abs(gripCache.trackLengthKm - trackLengthKm) > 1e-6

  if isGripCacheInvalid then
    gripInfos.frontLoaded = frontWearCurve ~= nil
    gripInfos.frontHigh, gripInfos.frontMedium, gripInfos.frontLow = computeGripRanges(frontWearCurve,
      tyreConsumptionRate)
    gripInfos.rearLoaded = rearWearCurve ~= nil
    gripInfos.rearHigh, gripInfos.rearMedium, gripInfos.rearLow = computeGripRanges(rearWearCurve, tyreConsumptionRate)

    gripCache.valid = true
    gripCache.compoundIndex = compoundIndex
    gripCache.frontWearCurve = frontWearCurve
    gripCache.rearWearCurve = rearWearCurve
    gripCache.tyreConsumptionRate = tyreConsumptionRate
    gripCache.trackLengthKm = trackLengthKm
  end

  if gripInfos.frontLoaded then
    ui.dwriteText("Front grip:", 12 * settings.Scale, rgbm(0.7, 1, 0.5, 1))
    ui.dwriteText(
      string.format("High +/- %.1f Km (%0.1f lap)", gripInfos.frontHigh, gripInfos.frontHigh / trackLengthKm),
      10 * settings.Scale, rgbm.colors.white)
    ui.dwriteText(
      string.format("Medium +/- %.1f Km (%0.1f lap)", gripInfos.frontMedium, gripInfos.frontMedium / trackLengthKm),
      10 * settings.Scale, rgbm.colors.white)
    ui.dwriteText(
      string.format("Low +/- %.1f Km (%0.1f lap)", gripInfos.frontLow, gripInfos.frontLow / trackLengthKm),
      10 * settings.Scale, rgbm.colors.white)
  else
    ui.dwriteText("No front LUT info!", 10 * settings.Scale, rgbm.colors.white)
  end

  if gripInfos.rearLoaded then
    ui.newLine()
    ui.dwriteText("Rear grip:", 12 * settings.Scale, rgbm(0.7, 1, 0.5, 1))
    ui.dwriteText(
      string.format("High +/- %.1f Km (%0.1f lap)", gripInfos.rearHigh, gripInfos.rearHigh / trackLengthKm),
      10 * settings.Scale, rgbm.colors.white)
    ui.dwriteText(
      string.format("Medium +/- %.1f Km (%0.1f lap)", gripInfos.rearMedium, gripInfos.rearMedium / trackLengthKm),
      10 * settings.Scale, rgbm.colors.white)
    ui.dwriteText(
      string.format("Low +/- %.1f Km (%0.1f lap)", gripInfos.rearLow, gripInfos.rearLow / trackLengthKm),
      10 * settings.Scale, rgbm.colors.white)
  else
    ui.dwriteText("No rear LUT info!", 10 * settings.Scale, rgbm.colors.white)
  end
  ui.popDWriteFont()
  ui.endTransparentWindow()
end
local function mouseInWindow()
  return ui.mousePos() > ui.windowPos() and ui.mousePos() < ui.windowPos() + ui.windowSize()
end

function script.windowMain(dt)
  ac.setWindowTitle('windowMain', string.format('SRA Tyres v%2.2f', VERSION))
  ui.pushDWriteFont('montserrat:/fonts;Weight=Bold')

  if carData.carState == nil then
    ui.dwriteText("Waiting for car data...", 10 * settings.Scale, rgbm.colors.white)
    ui.popDWriteFont()
    return
  end

  local drawOffset = ui.getCursor()
  local contentSize = ui.windowSize():sub(drawOffset)
  display.rect({ pos = drawOffset, size = contentSize, color = rgbm(0.1, 0.1, 0.1, 0.3) })

  local tyreSize = vec2(18 * settings.Scale, 70 * settings.Scale)
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(10 * settings.Scale, 8 * settings.Scale))

  if settings.showTyreName then
    ui.dwriteText(string.format("Tyre : %s", ac.getTyresLongName(0, carData.carState.compoundIndex)), 10 * settings
      .Scale,
      rgbm.colors.white)
  end
  if settings.showOptimal then
    ui.dwriteText(string.format("Optimum Temp : %3.0f°C - %3.0f°C", carData.minThermal, carData.maxThermal),
      10 * settings.Scale, rgbm.colors.white)
  end

  ui.separator()

  drawTyreLayoutLeft(carData:getTyreFL(), tyreSize, true)
  ui.sameLine()
  drawTyreLayoutRight(carData:getTyreFR(), tyreSize, true)
  if ui.mouseClicked(ui.MouseButton.Middle) and mouseInWindow() then
    isShowGripInfo = not isShowGripInfo
  end
  drawTyreLayoutLeft(carData:getTyreRL(), tyreSize, false)
  ui.sameLine()
  drawTyreLayoutRight(carData:getTyreRR(), tyreSize, false)
  ui.popStyleVar()
  ui.popDWriteFont()
  if isShowGripInfo then
    showGripInfo(ui.windowPos() + vec2(ui.windowSize().x, 22), vec2(170 * settings.Scale, ui.windowSize().y - 22))
  end
end

function script.update(dt)
  if not isAppVisible then return end
  carData:setCarID(0)
  carData:update(dt)
end

local function drawTitleSetting(title)
  local titleColor = rgbm(0.9, 0.5, 0.3, 1)
  local titleSize = 16
  ui.dwriteText(title, titleSize, titleColor)
end

function script.windowSetting(dt)
  drawTitleSetting("Scale")
  local newScale = ui.slider('##scaleSlider', settings.Scale, 0.5, 3.0, 'Scale: %.2f')
  if ui.itemEdited() then
    settings.Scale = newScale
  end
  ui.newLine()
  ui.separator()

  ui.beginGroup()
  drawTitleSetting("Display")
  if ui.checkbox("Show Optimal", settings.showOptimal) then
    settings.showOptimal = not settings.showOptimal
  end
  if ui.checkbox("Show Tyres Name", settings.showTyreName) then
    settings.showTyreName = not settings.showTyreName
  end
  if ui.checkbox("Show Wear Grip", settings.showWearGrip) then
    settings.showWearGrip = not settings.showWearGrip
  end
  if ui.checkbox("Show Disc", settings.showDisc) then
    settings.showDisc = not settings.showDisc
  end
  if ui.checkbox("Show Camber Rotation", settings.showCamberRotation) then
    settings.showCamberRotation = not settings.showCamberRotation
  end
  ui.endGroup()

  ui.sameLine(0, 40)

  ui.beginGroup()
  drawTitleSetting("Surface")
  if ui.checkbox("Show Grain", settings.showGrain) then
    settings.showGrain = not settings.showGrain
  end
  if ui.checkbox("Show Blister", settings.showBlister) then
    settings.showBlister = not settings.showBlister
  end
  if ui.checkbox("Show FlatSpot", settings.showFlatSpot) then
    settings.showFlatSpot = not settings.showFlatSpot
  end
  ui.endGroup()
end

function script.onShowWindowMain() isAppVisible = true end

function script.onHideWindowMain() isAppVisible = false end
