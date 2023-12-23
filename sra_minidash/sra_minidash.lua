--
-- Created by Wile64 on october 2023
--

-- https://github.com/ac-custom-shaders-patch/acc-lua-sdk/blob/main/.definitions/ac_common.txt

require('classes/carsra')
local car = CarSRA()
require('classes/settings')
local config = Settings()

require('classes/gui')
local labelTC = Label(vec2(40, 40), "TC", "0", config.Scale, config.LineColor)
local labelABS = Label(vec2(40, 40), "ABS", "0", config.Scale, config.LineColor)
local labelPosition = Label(vec2(40, 40), "POS.", "0", config.Scale, config.LineColor)
local labelTurbo = Label(vec2(40, 40), "TURBO", "0", config.Scale, config.LineColor)

local labelSpeed = Label(vec2(110, 45), "SPEED", "0", config.Scale, config.LineColor)
local labelFuel = Label(vec2(110, 35), "FUEL", "0", config.Scale, config.LineColor)
local labelCons = Label(vec2(62, 40), "CONS.", "0", config.Scale, config.LineColor)
local labelRemain = Label(vec2(40, 40), "REMAIN.", "0", config.Scale, config.LineColor)
local labelLaps = Label(vec2(40, 40), "LAP(S)", "0", config.Scale, config.LineColor)
local labelBias = Label(vec2(62, 40), "BIAS", "0", config.Scale, config.LineColor)

local labelP2P = Label(vec2(45, 40), "", "0", config.Scale, config.LineColor)
local labelDRS = Label(vec2(45, 40), "", "0", config.Scale, config.LineColor)
local labelGear = Label(vec2(44, 100), "", "0", config.Scale, config.LineColor)

local labelDelta = Label(vec2(120, 40), "DELTA", "0", config.Scale, config.LineColor)
local labelEstimated = Label(vec2(120, 40), "ESTIMATED LAP", "0", config.Scale, config.LineColor)
local labelLastTime = Label(vec2(120, 40), "LAST LAP", "0", config.Scale, config.LineColor)
local labelBestTime = Label(vec2(120, 40), "BEST LAP", "0", config.Scale, config.LineColor)


local isInitialized = false
local currentSessionIndex = 0
local isSessionStarted = false
local driverBefore = "Initialize"
local driverAfter = "Initialize"

local function nickName(name)
  local prev_token = ""
  local last = ""
  local result = ""
  for token in string.gmatch(name, "[^%s._-[(())[{}|]+") do
    if prev_token ~= "" then
      if string.match(prev_token, ".*]") then
        --print(prev_token)
        result = result
      else
        --print(prev_token)
        result = result .. string.sub(prev_token, 1, 1) .. "."
      end
    end
    prev_token = token
    last = token
  end
  return result .. last
end

---gap in second
---@param gap number
---@return string
local function gapToString(gap)
  local minutes = math.floor(gap / 60)
  local seconds = gap - (minutes * 60)
  local centiseconds = math.floor((seconds - math.floor(seconds)) * 100)
  if minutes > 0 then
    return string.format("%d:%02d.%02d", minutes, math.floor(seconds), centiseconds)
  else
    return string.format("%d.%02d", seconds, centiseconds)
  end
end

---@return string
local function getDeltaStr(car1, car2)
  if ac.getSim().isSessionStarted then
    if car1.lapCount ~= car2.lapCount then
      return string.format("%d Lap(s)", car1.lapCount - car2.lapCount)
    else
      if car2.speedKmh < 1 then
        return '-.---'
      end
      local car1Pos = car1.splinePosition
      local car2Pos = car2.splinePosition
      return gapToString(((car1Pos - car2Pos) / (car2.speedKmh / 3.6) * ac.getSim().trackLengthM))
    end
  else
    return ''
  end
end

local function updateGap(dt)
  local maxCar = ac.getSim().carsCount
  local myPos = ac.getCar(0).racePosition
  local nombre = math.max(myPos - 1, 0)
  local before = math.max(math.min(nombre, maxCar + 1), 0)
  local after = nombre + 2
  local carBeforeID = -1
  local carAfterID = -1

  for i = 0, maxCar - 1 do
    if ac.getCar(i).racePosition == before then
      carBeforeID = i
    end
    if ac.getCar(i).racePosition == after then
      carAfterID = i
    end
  end
  if (before == 0) then
    driverBefore = "your first :)"
  else
    local driverName = nickName(ac.getDriverName(carBeforeID))
    if ac.getCar(carBeforeID).isActive then
      if ac.getCar(carBeforeID).isInPit or ac.getCar(carBeforeID).isInPitlane then
        driverBefore = string.format("%d %s %s", before, driverName, "In Pit")
      elseif ac.getCar(carBeforeID).lapCount > ac.getCar(0).lapCount then
        driverBefore = string.format("%d %s %d laps", before, driverName,
          ac.getCar(carBeforeID).lapCount - ac.getCar(0).lapCount)
      else
        driverBefore = string.format("%d %s %s", before, driverName, getDeltaStr(ac.getCar(carBeforeID), ac.getCar(0)))
      end
    else
      driverBefore = string.format("%d %s %s", before, driverName, "Disconnected")
    end
  end
  if (after > maxCar) then
    driverAfter = "your last :'("
  else
    local driverName = nickName(ac.getDriverName(carAfterID))
    if ac.getCar(carAfterID).isActive then
      if ac.getCar(carAfterID).isInPit or ac.getCar(carAfterID).isInPitlane then
        driverAfter = string.format("%d %s %s", after, driverName, "In Pit")
      elseif ac.getCar(0).lapCount > ac.getCar(carAfterID).lapCount then
        driverBefore = string.format("%d %s %d laps", before, driverName,
          ac.getCar(0).lapCount - ac.getCar(carAfterID).lapCount)
      else
        driverAfter = string.format("%d %s %s", after, driverName, getDeltaStr(ac.getCar(0), ac.getCar(carAfterID)))
      end
    else
      driverAfter = string.format("%d %s %s", after, driverName, "Disconnected")
    end
  end
end

local function initialize()
  isInitialized = true
  currentSessionIndex = ac.getSim().currentSessionIndex
  isSessionStarted = false
end

if ac.onSessionStart then
  ac.onSessionStart(function()
    initialize()
  end)
end

local function DrawBarRPM(progress, numRectangles, height, color)
  local totalWidth = ui.windowSize().x - 1
  local spacing = 2
  local rectWidth = (totalWidth - (numRectangles - 1) * spacing) / numRectangles
  local startPosition = ui.getCursor()

  for i = 0, numRectangles do
    if (i < progress * numRectangles - 1) then
      ui.drawRectFilled(startPosition, startPosition + vec2(rectWidth, height), color)
    else
      ui.drawRect(startPosition, startPosition + vec2(rectWidth, height), rgbm.colors.gray)
    end
    startPosition = startPosition + vec2(rectWidth + spacing, 0)
  end

  ui.setCursorY(ui.getCursorY() + height + 3)
end

local function showIcon(iconID, pos, size, color)
  ui.drawIcon(iconID, pos, vec2(pos.x + size, pos.y + size), color)
end

local function progressBarH(progress, rectSize, color)
  local startPosition = ui.getCursor()
  local rectprogress = vec2((rectSize.x * progress), rectSize.y)
  ui.drawRectFilled(startPosition + 1, startPosition + 1 + rectprogress, color, 3)
  ui.dummy(rectSize)
end

function script.windowMain(dt)
  local drawOffset = ui.getCursor()
  local contentSize = ui.windowSize():sub(drawOffset)
  display.rect({ pos = drawOffset, size = contentSize, color = config.BackgroundColor })

  ui.pushDWriteFont('OneSlot:\\fonts\\.')

  local rpmNormalized = car.carState.rpm / car.carState.rpmLimiter
  local color = config.RPMColor
  if rpmNormalized >= 0.94 then
    color = rgbm.colors.red
  elseif rpmNormalized >= 0.88 then
    color = rgbm.colors.orange
  end
  DrawBarRPM(rpmNormalized, 30, 20 * config.Scale, color)
  if car.carState.kersPresent then
    if car.carState.kersMaxKJ > 0 then
      local ersNormalized = 1 - (car.carState.kersCurrentKJ / (car.carState.kersMaxKJ))
      progressBarH(ersNormalized, vec2(160 * config.Scale, 5 * config.Scale), rgbm.colors.blue)
    end
    local kersStatus = 0
    if car.carState.kersCurrentKJ >= car.carState.kersMaxKJ then
      kersStatus = 2
    elseif car.carState.kersButtonPressed then
      kersStatus = 3
    else
      kersStatus = 1
    end
    local kersColors = { [1] = rgbm.colors.blue, [2] = rgbm.colors.red, [3] = rgbm.colors.green }
    ui.sameLine()
    progressBarH(car.carState.kersCharge, vec2(160 * config.Scale, 5 * config.Scale), kersColors[kersStatus])
  end

  -- if ac.getSim().raceSessionType == ac.SessionType.Race then
  --   ui.dwriteText(driverBefore, 11 * config.Scale, rgbm.colors.white)
  --   ui.sameLine(10, 170 * config.Scale)
  --   ui.dwriteText(driverAfter, 11 * config.Scale, rgbm.colors.white)
  -- end

  ui.beginGroup()
  if car.carState.tractionControlMode > 0 then
    labelTC:enable()
    if car.carState.tractionControlInAction then
      labelTC:setBgColor(rgbm.colors.blue)
    else
      labelTC:setBgColor(rgbm.colors.green)
    end
  else
    labelTC:disable()
  end
  labelTC:draw(string.format("%02d", car.carState.tractionControlMode))

  if car.carState.absMode > 0 then
    labelABS:enable()
    if car.carState.absInAction then
      labelABS:setBgColor(rgbm.colors.blue)
    else
      labelABS:setBgColor(rgbm.colors.green)
    end
  else
    labelABS:disable()
  end
  labelABS:draw(string.format("%02d", car.carState.absMode))
  labelPosition:draw(string.format("%d", car.carState.racePosition))

  if car.carState.turboCount > 0 then
    labelTurbo:setProgress(car.carState.turboBoost, rgbm.colors.orange)
    labelTurbo:draw(string.format("%3.0f", car.carState.turboWastegates[0] * 100))
  end

  ui.endGroup()

  ui.sameLine()
  ui.beginGroup()

  labelSpeed:draw(string.format("%d", car.carState.speedKmh))

  local normalizedFuel = car.carState.fuel / car.carState.maxFuel
  labelFuel:setProgress(normalizedFuel, config.FuelColor)
  labelFuel:draw(string.format("%d L", car.carState.fuel))
  labelCons:draw(string.format("%2.1f", car.carState.fuelPerLap))
  ui.sameLine()
  labelRemain:draw((string.format("%1.0f", car:getRemainFuelLap())))

  labelLaps:draw(string.format("%d", car.carState.lapCount))
  ui.sameLine()
  labelBias:draw(string.format("%2.1f", car.carState.brakeBias * 100))
  ui.endGroup()

  ui.sameLine()
  ui.beginGroup()
  if car.carState.p2pStatus > 0 then
    if car.carState.p2pStatus == 1 then
      labelDRS:setBgColor(rgbm.colors.red)
    elseif car.carState.p2pStatus == 2 then
      labelDRS:setBgColor(rgbm.colors.green)
    elseif car.carState.p2pStatus == 3 then
      labelDRS:setBgColor(rgbm.colors.purple)
    end
    labelP2P:draw(string.format("%d", car.carState.p2pActivations))
  elseif car.carState.drsPresent then
    if car.carState.drsActive then
      labelDRS:setBgColor(rgbm.colors.purple)
    elseif car.carState.drsAvailable then
      labelDRS:setBgColor(rgbm.colors.green)
    else
      labelDRS:setBgColor(rgbm.colors.red)
    end
    labelDRS:draw("DRS")
  else
    labelDRS:disable()
    labelDRS:draw("DRS")
  end

  local validPos = ui.getCursor()
  ui.offsetCursorY(5)

  labelGear:draw(car:getGearToString())

  if ui.itemHovered() then
    ui.tooltip(function()
      ui.pushFont(ui.Font.Monospace)
      ui.text("- Indique si le tour est valide\n- Indique la vitesse engagée")
      ui.popFont()
    end)
  end
  if car.carState.isLapValid then
    showIcon(ui.Icons.Verified, vec2(validPos.x + 10 * config.Scale, validPos.y - 4 * config.Scale),
      30 * config.Scale, rgbm.colors.green)
  else
    showIcon(ui.Icons.Attention, vec2(validPos.x + 10 * config.Scale, validPos.y - 4 * config.Scale),
      30 * config.Scale, rgbm.colors.red)
  end
  local sessionStr = {
    "Undefined",
    "Practice",
    "Qualify",
    "Race",
    "Hotlap",
    "TimeAttack",
    "Drift",
    "Drag" }
  ui.dwriteText(string.format("%s", sessionStr[ac.getSim().raceSessionType + 1]), 12 * config.Scale, rgbm.colors.white)

  ui.endGroup()

  ui.sameLine()
  ui.beginGroup()
  if car.carState.performanceMeter > 0 then
    labelDelta:setColor(rgbm.colors.red)
    labelEstimated:setColor(rgbm.colors.red)
  else
    labelDelta:setColor(rgbm.colors.green)
    labelEstimated:setColor(rgbm.colors.green)
  end
  labelDelta:draw(string.format("%2.3f", car.carState.performanceMeter))
  labelEstimated:draw(ac.lapTimeToString(car.carState.estimatedLapTimeMs))
  labelLastTime:draw(ac.lapTimeToString(car.carState.previousLapTimeMs))
  labelBestTime:draw(ac.lapTimeToString(car.carState.bestLapTimeMs))
  ui.endGroup()
  ui.popDWriteFont()
end

function script.windowSetting(dt)
  local newScale = ui.slider('##scaleSlider', config.Scale, 1.0, 2.0, 'Scale: %1.1f%')
  if ui.itemEdited() then
    config.Scale = newScale
    labelTC:setScale(config.Scale)
    labelABS:setScale(config.Scale)
    labelPosition:setScale(config.Scale)
    labelTurbo:setScale(config.Scale)

    labelSpeed:setScale(config.Scale)
    labelFuel:setScale(config.Scale)
    labelCons:setScale(config.Scale)
    labelRemain:setScale(config.Scale)
    labelLaps:setScale(config.Scale)
    labelBias:setScale(config.Scale)

    labelP2P:setScale(config.Scale)
    labelDRS:setScale(config.Scale)
    labelGear:setScale(config.Scale)

    labelDelta:setScale(config.Scale)
    labelEstimated:setScale(config.Scale)
    labelLastTime:setScale(config.Scale)
    labelBestTime:setScale(config.Scale)
  end
  if ui.colorButton(
        'lineColor##',
        config.LineColor,
        ui.ColorPickerFlags.NoAlpha + ui.ColorPickerFlags.PickerHueBar) then
    config.LineColor = config.LineColor
  end
  ui.sameLine()
  ui.text('Line Color')

  if ui.colorButton(
        'rpmColor##',
        config.RPMColor,
        ui.ColorPickerFlags.NoAlpha + ui.ColorPickerFlags.PickerHueBar) then
    config.RPMColor = config.RPMColor
  end
  ui.sameLine()
  ui.text('RPM Color')

  if ui.colorButton(
        'fuelColor##',
        config.FuelColor,
        ui.ColorPickerFlags.NoAlpha + ui.ColorPickerFlags.PickerHueBar) then
    config.FuelColor = config.FuelColor
  end
  ui.sameLine()
  ui.text('Fuel Color')

  if ui.colorButton(
        'backgroundColor##',
        config.BackgroundColor,
        ui.ColorPickerFlags.NoAlpha + ui.ColorPickerFlags.PickerHueBar) then
    config.BackgroundColor = config.BackgroundColor
  end
  ui.sameLine()
  ui.text('Backgorund  Color')
  ui.separator()
  ui.setCursorX(210)
  if ui.iconButton(ui.Icons.Save, vec2(50, 0), 0, true, ui.ButtonFlags.Activable) then
    config:save()
  end
end

function script.update(dt)
  car:setFocusedCar()
  car:update(dt)
  local sim = ac.getSim()
  if sim == nil then return end

  if sim.currentSessionIndex ~= currentSessionIndex or sim.isSessionStarted ~= isSessionStarted then
    isInitialized = false
  end

  if not isInitialized then
    initialize()
  end

  if sim.isSessionStarted then
    isSessionStarted = true
  end
  if sim.raceSessionType == ac.SessionType.Race then
    updateGap(dt)
  end
end
