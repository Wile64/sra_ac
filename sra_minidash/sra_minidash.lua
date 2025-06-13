--
-- Created by Wile64 on october 2023
--

VERSION = 1.3


local AppConfig       = ac.storage {
  scale         = 1,
  showEstimated = false,
  showPedals    = true,

  bgColor       = rgbm(0.127, 0.127, 0.127, 1),
  startRPMColor = rgbm(0.044, 0.279, 0.031, 1),
  endRPMColor   = rgbm(0.500, 0.000, 0.000, 1),
  legend        = rgbm(0.233, 0.330, 0.224, 1),
  fuelProgress  = rgbm(0.746, 0.466, 0.125, 1),
  turboProgress = rgbm(0.746, 0.466, 0.125, 1),

  separator     = rgbm(0.264, 0.264, 0.264, 1),
  bestLap       = rgbm(0.264, 0.264, 0.264, 1),

  colorGroups   = rgbm(0.787, 0.257, 0.080, 1),
  colorText     = rgbm(1, 1, 1, 1),
  colorDisabled = rgbm(0.25, 0.25, 0.25, 1),
}

local fontSize        = 20
local fontFuelGroup   = 17.5
local legendSize      = fontSize * 0.6
local iconSize        = 17

local carStates       = {}
local appVisible      = true
local focusedCar      = -1

local timerP2P        = 0
local prevStatus      = 0
local maxBoost        = 0
local P2PcoolDownTime = 0
local P2PactiveTime   = 0

local palette         = {
  red    = rgbm.from0255(219, 60, 48),
  green  = rgbm.from0255(63, 201, 121),
  purple = rgbm.from0255(155, 93, 229),
  blue   = rgbm.from0255(93, 156, 236),
  yellow = rgbm.from0255(249, 243, 114),
}

local sessionTypeStr  = {
  "Undefined",
  "Practice",
  "Qualify",
  "Race",
  "Hotlap",
  "TimeAttack",
  "Drift",
  "Drag" }

---comment
---@param icon ui.Icons
---@param size number
---@param color rgbm?
local function addIcon(icon, size, color)
  local pos = ui.getCursor()
  ui.drawIcon(icon, pos, pos + size, color)
  ui.dummy(size)
end

---@param text string
local function writeLegend(text)
  local pos = ui.getCursor() + vec2(4, 2)
  ui.dwriteDrawText(text, legendSize * AppConfig.scale, pos, AppConfig.legend)
end

---comment
---@param title string
---@param rectSize vec2
---@param bgColor rgbm
---@param textColor rgbm
---@param horizontalAligment ui.Alignment?
---@param legend string?
local function drawItem(title, rectSize, bgColor, textColor, horizontalAligment, legend)
  local pos = ui.getCursor()

  if not horizontalAligment then
    horizontalAligment = ui.Alignment.End
  end
  ui.drawRectFilled(pos, pos + rectSize, bgColor, 5, ui.CornerFlags.All)
  ui.drawRect(pos, pos + rectSize, textColor, 5, ui.CornerFlags.All)
  if legend then
    writeLegend(legend)
  end
  ui.dummy(rectSize)
  rectSize = rectSize - vec2(2, 0)
  ui.dwriteDrawTextClipped(title, rectSize.y, pos, pos + rectSize, horizontalAligment,
    ui.Alignment.Center, false, textColor)
end

---@param text string
---@param size vec2
---@param color rgbm
---@param horizontalAligment ui.Alignment?
local function writeTextInGroup(text, size, color, legend, horizontalAligment)
  if legend then
    writeLegend(legend)
  end
  if not horizontalAligment then
    horizontalAligment = ui.Alignment.End
  end
  ui.offsetCursorX(3)
  size = size - vec2(6, 0)
  ui.dwriteTextAligned(text, size.y, horizontalAligment, ui.Alignment.Center, size, false, color)
end

local function getScale(x, y)
  return vec2(x, y) * AppConfig.scale
end

---comment
---@param width number
local function separator(width)
  local pos = ui.getCursor()
  ui.drawLine(pos + vec2(5, 0), pos + vec2(width - 5, 0), AppConfig.separator, 1)
  ui.dummy(1)
end

--t dans [0,1] retourne la couleur interpolée
---@param c1 rgbm
---@param c2 rgbm
---@param t number
---@return rgbm
local function lerpColor(c1, c2, t)
  return rgbm(
    c1.r + (c2.r - c1.r) * t,
    c1.g + (c2.g - c1.g) * t,
    c1.b + (c2.b - c1.b) * t,
    1
  )
end

local function DrawBarRPM(progress, height, startColor, endColor)
  local totalWidth    = ui.windowContentSize().x
  local spacing       = 5
  local numRectangles = 17
  local available     = totalWidth - spacing * (numRectangles - 1)
  local rectWidth     = math.floor(available / numRectangles)
  local filledCount   = math.floor(progress * numRectangles)
  local pos           = ui.getCursor()
  local size          = vec2(rectWidth, height)

  for i = 1, numRectangles do
    if i <= filledCount then
      local c = startColor
      if i > 9 then
        local t = (i - 8) / (8)
        c = lerpColor(startColor, endColor, t)
      end
      ui.drawRectFilled(pos, pos + size, c, 15, ui.CornerFlags.All)
    else
      ui.drawRect(pos, pos + size, AppConfig.separator, 15, ui.CornerFlags.All)
    end
    pos = pos + vec2(rectWidth + spacing, 0)
  end
  ui.dummy(height + 2)
end

local function progressBarV(progress, rectSize, b_color, l_color)
  progress = math.min(math.max(progress, 0), 1)
  local startPosition = ui.getCursor()
  local progressBarFilledSize = vec2(rectSize.x, rectSize.y * progress)
  local startfilled = startPosition + vec2(0, rectSize.y - progressBarFilledSize.y)
  ui.drawRectFilled(startfilled, startfilled + progressBarFilledSize, b_color, 3)
  ui.drawRect(startPosition, startPosition + rectSize, l_color, 3, ui.CornerFlags.All, 2)
  ui.dummy(rectSize)
end

local function deltaBar(progress, rectSize)
  progress = math.max(-4, math.min(4, progress)) -- clamp
  local startPosition = ui.getCursor()

  local barCenter = startPosition + vec2(rectSize.x * 0.5, 0) -- position centrale
  local barSize = vec2(rectSize.x * 0.5, rectSize.y)          -- largeur totale = 200px
  local halfWidth = barSize.x

  -- Fond gris neutre
  ui.drawRectFilled(startPosition, startPosition + rectSize, rgbm(0.2, 0.2, 0.2, 1))
  progress = progress * 0.25
  -- Progression positive (droite, vert)
  if progress > 0 then
    local right = barCenter + vec2(halfWidth * progress, 0)
    ui.drawRectFilled(barCenter, vec2(right.x, barCenter.y + barSize.y), palette.green, 5, ui.CornerFlags.Right)
  elseif progress < 0 then
    -- Progression négative (rouge, gauche)
    local left = barCenter + vec2(halfWidth * progress, 0)
    ui.drawRectFilled(left, vec2(barCenter.x, barCenter.y + barSize.y), palette.red, 5, ui.CornerFlags.Left)
  end
  ui.dummy(rectSize)
end


local function progressBarH(progress, rectSize, b_color, t_color, text, legend, horizontalAligment)
  progress = math.min(math.max(progress, 0), 1)
  local startPosition = ui.getCursor()
  if not horizontalAligment then
    horizontalAligment = ui.Alignment.End
  end
  local progressBarFilledSize = vec2(rectSize.x * progress, rectSize.y)
  if progress > 0 then
    ui.drawRectFilled(startPosition, startPosition + progressBarFilledSize, b_color, 5, ui.CornerFlags.All)
  end
  ui.drawRect(startPosition, startPosition + rectSize, AppConfig.separator, 5, ui.CornerFlags.All, 1)
  if legend then
    writeLegend(legend)
  end
  if text then
    ui.dwriteDrawTextClipped(text, rectSize.y, startPosition, startPosition + rectSize - vec2(4, 0),
      horizontalAligment, ui.Alignment.Center, false, t_color)
  end
  ui.dummy(rectSize)
end

local function drawFuel()
  local width = fontSize * 5
  local groupWidth = width * AppConfig.scale
  ui.beginGroup(groupWidth)
  local absColor = (carStates.ABS > 0) and (carStates.absInAction and palette.red or AppConfig.bgColor) or
      AppConfig.bgColor
  local tcColor = (carStates.TC > 0) and (carStates.tcInAction and palette.red or AppConfig.bgColor) or
      AppConfig.bgColor
  drawItem(string.format("%02d", carStates.TC), getScale(width * 0.5, fontFuelGroup), tcColor,
    (carStates.TC == 0 and AppConfig.colorDisabled) or AppConfig.colorText, ui.Alignment.End, "TC")
  ui.sameLine()
  drawItem(string.format("%02d", carStates.ABS), getScale(width * 0.5, fontFuelGroup), absColor,
    (carStates.ABS == 0 and AppConfig.colorDisabled) or AppConfig.colorText, ui.Alignment.End, "ABS")
  if carStates.turboCount > 0 then
    local nBoost = carStates.turboBoost / carStates.maxBoost
    local turboText = ''
    if carStates.adjustableTurbo then
      turboText = string.format("%3.0f", carStates.turboWastegates[0] * 100)
    end
    progressBarH(nBoost, getScale(width, fontFuelGroup), AppConfig.turboProgress, AppConfig.colorText,
      turboText, "Turbo")
  end
  writeTextInGroup(carStates.racePosition, getScale(width, fontFuelGroup), AppConfig.colorText, "Pos")
  separator(groupWidth)
  writeTextInGroup(carStates.lapCountStr, getScale(width, fontFuelGroup), AppConfig.colorText, "Lap")

  progressBarH(carStates.nFuel, getScale(width, fontFuelGroup), AppConfig.fuelProgress, AppConfig.colorText,
    carStates.fuelStr, "Fuel")
  writeTextInGroup(carStates.fuelPerLapStr, getScale(width, fontFuelGroup), AppConfig.colorText, "Fuel/Lap")
  separator(groupWidth)
  writeTextInGroup(carStates.remainingLapStr, getScale(width, fontFuelGroup), AppConfig.colorText, "Remain.L")
  separator(groupWidth)
  writeTextInGroup(carStates.remainTimeStr, getScale(width, fontFuelGroup), AppConfig.colorText, "Remain.T")

  ui.dummy(2)
  ui.endGroup()
  local r = ui.itemRectMin()
  local s = ui.itemRectMax()
  ui.drawRect(r, s, AppConfig.colorGroups, 5, ui.CornerFlags.All, 2)
end

local function drawOdometer()
  local width = fontSize * 5
  local groupWidth = width * AppConfig.scale
  ui.beginGroup(groupWidth)
  local pos = ui.getCursor()
  local validSize = getScale(width, fontSize * 0.3)
  ui.drawRectFilled(pos, pos + validSize, (carStates.isLapValid and palette.green) or palette.red, 5, ui.CornerFlags.Top)
  ui.dummy(validSize)

  if carStates.p2pStatus > 0 then
    local colorP2P = palette.red
    if carStates.p2pStatus == 1 then
      colorP2P = palette.red -- in cooldown
      progressBarH(1 - (timerP2P / carStates.P2PcoolDownTime), getScale(width, fontSize), colorP2P,
        rgbm.colors.yellow, string.format("P2P %.0fs", timerP2P), '', ui.Alignment.Center)
    elseif carStates.p2pStatus == 2 then
      colorP2P = palette.green -- ready
      drawItem(string.format("P2P %02d", carStates.p2pActivations), getScale(width, fontSize), colorP2P,
        rgbm.colors.black, ui.Alignment.Center)
    elseif carStates.p2pStatus == 3 then
      colorP2P = palette.purple -- in use
      progressBarH(timerP2P / carStates.P2PactiveTime, getScale(width, fontSize), colorP2P,
        rgbm.colors.yellow, string.format("P2P %.0fs", timerP2P), '', ui.Alignment.Center)
    end
    --elseif carStates.drsPresent then
  else
    local colorDRS = palette.red
    if not carStates.drsPresent then
      colorDRS = AppConfig.colorDisabled
    elseif carStates.drsActive then
      colorDRS = palette.purple
    elseif carStates.drsAvailable then
      colorDRS = palette.green
    else
      colorDRS = palette.red
    end
    drawItem("DRS", getScale(width, fontSize), colorDRS, rgbm.colors.black, ui.Alignment.Center)
  end
  local colorRPM = (carStates.rpmNormalized > 0.963) and palette.red or AppConfig.colorText
  writeTextInGroup(string.format("%.f", carStates.rpm), getScale(width, fontSize), colorRPM, "RPM", ui.Alignment.Center)
  separator(groupWidth)
  ui.sameLine()
  if carStates.speedLimiterInAction or carStates.manualPitsSpeedLimiterEnabled then
    local pos = ui.getCursor()
    pos = pos + getScale(width * 0.75, 0)
    ui.drawIcon(".//img//limiter.png", pos, pos + 15 * AppConfig.scale, rgbm.colors.red)
  end

  writeTextInGroup(carStates.speedKmh, getScale(width, fontSize * 1.5), colorRPM, "Km/h", ui.Alignment.Center)
  separator(groupWidth)
  writeTextInGroup(carStates.gear, getScale(width, fontSize * 4), colorRPM, "Gear", ui.Alignment.Center)

  ui.endGroup()
  local r = ui.itemRectMin()
  local s = ui.itemRectMax()
  ui.drawRect(r, s, AppConfig.colorGroups, 5, ui.CornerFlags.All, 2)
end

local function drawLapTime()
  local width = fontSize * 6
  local groupWidth = width * AppConfig.scale
  ui.beginGroup(groupWidth)
  local deltaColor = palette.red
  deltaBar(carStates.performanceMeterSpeedDifferenceMs, getScale(width, fontSize * 0.5))
  if carStates.performanceMeter > 0 then
    writeTextInGroup(string.format("+%.3f", carStates.performanceMeter), getScale(width, fontSize),
      deltaColor, "Delta")
  else
    deltaColor = palette.green
    writeTextInGroup(string.format("%.3f", carStates.performanceMeter), getScale(width, fontSize),
      deltaColor, "Delta")
  end
  if AppConfig.showEstimated then
    separator(width * AppConfig.scale)
    writeTextInGroup(carStates.estimatedLapTimeMs, getScale(width, fontSize), deltaColor, "Next")
  end
  separator(groupWidth)
  writeTextInGroup(carStates.previousLapTimeMs, getScale(width, fontSize),
    (carStates.isLastLapValid and AppConfig.colorText) or palette.red, "Last")
  separator(groupWidth)
  writeTextInGroup(carStates.bestLapTimeMs, getScale(width, fontSize), AppConfig.bestLap, "Best")
  separator(groupWidth)
  writeTextInGroup(carStates.sessionTimeLeft, getScale(width, fontSize), AppConfig.colorText,
    sessionTypeStr[ac.getSim().raceSessionType + 1])
  separator(groupWidth)
  writeTextInGroup(carStates.brakeBias, getScale(width, fontFuelGroup), palette.red, "Bias")
  ui.dummy(2)
  ui.endGroup()
  local r = ui.itemRectMin()
  local s = ui.itemRectMax()
  ui.drawRect(r, s, AppConfig.colorGroups, 5, ui.CornerFlags.All, 2)
end

local function drawKERSBar()
  if carStates.kersPresent then
    -- 1 = normal, 2 = charging, 3 = active
    local kersColors = { [1] = palette.blue, [2] = palette.yellow, [3] = palette.green }
    ui.sameLine()
    progressBarV(carStates.kersCharge, getScale(fontSize * 0.5, fontSize * 8),
      kersColors[carStates.kersStatus], AppConfig.colorGroups)
    if ui.itemHovered() then
      ui.tooltip(function()
        ui.pushFont(ui.Font.Monospace)
        ui.text("KERS")
        ui.popFont()
      end)
    end
  end
end

local function drawERSBar()
  if carStates.kersPresent then
    if carStates.kersMaxKJ > 0 then
      local ersNormalized = 1 - (carStates.kersCurrentKJ / (carStates.kersMaxKJ))
      progressBarV(ersNormalized, getScale(fontSize * 0.5, fontSize * 8), palette.blue, AppConfig.colorGroups)
      if ui.itemHovered() then
        ui.tooltip(function()
          ui.pushFont(ui.Font.Monospace)
          ui.text("ERS")
          ui.popFont()
        end)
      end
      ui.sameLine()
    end
  end
end

local function drawWeather()
  addIcon(ui.Icons.Thermometer, legendSize * AppConfig.scale, AppConfig.colorText)
  ui.sameLine()
  ui.dwriteText(carStates.airTemperature, legendSize * AppConfig.scale, AppConfig.colorText)
  ui.sameLine()
  addIcon(ui.Icons.Road, legendSize * AppConfig.scale, AppConfig.colorText)
  ui.sameLine()
  ui.dwriteText(carStates.roadTemperature, legendSize * AppConfig.scale, AppConfig.colorText)
end

local iconFlash = false
setInterval(function() iconFlash = not iconFlash end, 0.4)

local function drawIndicators()
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(3, 0))
  if carStates.turningLeftOnly and iconFlash then
    addIcon(ui.Icons.TurnSignalLeft, iconSize * AppConfig.scale, AppConfig.colorText)
  else
    addIcon(ui.Icons.TurnSignalLeft, iconSize * AppConfig.scale, AppConfig.colorDisabled)
  end
  ui.sameLine()
  if carStates.hazardLights and iconFlash then
    addIcon(ui.Icons.Hazard, iconSize * AppConfig.scale, rgbm.colors.red)
  else
    addIcon(".//img//hazard.png", iconSize * AppConfig.scale, AppConfig.colorDisabled)
  end
  ui.sameLine()
  if carStates.turningRightOnly and iconFlash then
    addIcon(ui.Icons.TurnSignalRight, iconSize * AppConfig.scale, AppConfig.colorText)
  else
    addIcon(ui.Icons.TurnSignalRight, iconSize * AppConfig.scale, AppConfig.colorDisabled)
  end
  ui.sameLine()
  if carStates.beamsStatus > 0 then
    if carStates.beamsStatus > 1 then
      addIcon(".//img//high-beams.png", iconSize * AppConfig.scale, palette.blue)
    else
      addIcon(".//img//low-beams.png", iconSize * AppConfig.scale, AppConfig.colorText)
    end
  else
    addIcon(".//img//low-beams.png", iconSize * AppConfig.scale, AppConfig.colorDisabled)
  end

  ui.sameLine()
  if carStates.wiperSelectedMode > 0 then
    local pos = ui.getCursor() + vec2(0, 2)
    addIcon(".//img//wiper.png", iconSize * AppConfig.scale, AppConfig.colorText)
    ui.dwriteDrawText(string.format("%d", carStates.wiperSelectedMode), (iconSize * 0.5) * AppConfig.scale,
      pos + getScale(legendSize - 4, 0), AppConfig.colorText)
  else
    addIcon(".//img//wiper.png", iconSize * AppConfig.scale, AppConfig.colorDisabled)
  end
  ui.popStyleVar()
end

function script.windowMain(dt)
  local drawOffset = ui.getCursor()
  local contentSize = ui.windowSize():sub(drawOffset)
  display.rect({ pos = drawOffset, size = contentSize, color = AppConfig.bgColor })

  ui.pushDWriteFont('OneSlot:/fonts;Weight=Bold;Stretch=Condensed')
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, 0)
  DrawBarRPM(carStates.rpmNormalized, legendSize * AppConfig.scale, AppConfig.startRPMColor, AppConfig.endRPMColor)
  drawERSBar()

  ui.beginGroup()
  drawIndicators()
  ui.offsetCursorY(3)
  drawLapTime()
  ui.endGroup()

  ui.sameLine(0, 5)
  ui.beginGroup()
  if AppConfig.showPedals then
    progressBarV(carStates.brake, getScale(legendSize, fontSize * 8), palette.red, palette.red)
    ui.sameLine()
  end
  drawOdometer()
  if AppConfig.showPedals then
    ui.sameLine()
    progressBarV(carStates.gas, getScale(legendSize, fontSize * 8), palette.green, palette.green)
  end
  ui.endGroup()
  ui.sameLine(0, 5)

  ui.beginGroup()
  ui.dwriteText(string.format("%s", os.date("%X")), (legendSize * 0.8) * AppConfig.scale, AppConfig.colorText)
  ui.sameLine(0, 5)
  drawWeather()
  drawFuel()
  ui.endGroup()

  drawKERSBar()
  ui.popStyleVar()
  ui.popDWriteFont()
end

---@param label string
---@param color rgbm
---@return boolean
local function colorButtonEx(label, color)
  local originalColor = color:clone()
  ui.colorButton(label, color, ui.ColorPickerFlags.PickerHueBar + ui.ColorPickerFlags.Float)
  ui.sameLine()
  ui.text(label)
  return originalColor:vec4():distance(color:vec4()) > 0
end

function script.windowSetting(dt)
  ui.textColored("Scale:", rgbm.colors.aqua)
  AppConfig.scale = ui.slider('##SizeSlider', AppConfig.scale, 1.0, 2.0, 'Scale: %.2f%')
  ui.separator()

  ui.textColored("Options:", rgbm.colors.aqua)
  if ui.checkbox("Show Estimated Lap", AppConfig.showEstimated) then
    AppConfig.showEstimated = not AppConfig.showEstimated
  end
  if ui.checkbox("Show pedals", AppConfig.showPedals) then
    AppConfig.showPedals = not AppConfig.showPedals
  end
  ui.separator()

  ui.textColored("Colors:", rgbm.colors.aqua)

  local columnSize = 200
  if colorButtonEx("Groups color", AppConfig.colorGroups) then
    AppConfig.colorGroups = AppConfig.colorGroups
  end
  ui.sameLine(columnSize)
  if colorButtonEx("Text color", AppConfig.colorText) then
    AppConfig.colorText = AppConfig.colorText
  end
  if colorButtonEx("RPM start color", AppConfig.startRPMColor) then
    AppConfig.startRPMColor = AppConfig.startRPMColor
  end
  ui.sameLine(columnSize)
  if colorButtonEx("RPM end color", AppConfig.endRPMColor) then
    AppConfig.endRPMColor = AppConfig.endRPMColor
  end
  if colorButtonEx("Fuel progress color", AppConfig.fuelProgress) then
    AppConfig.fuelProgress = AppConfig.fuelProgress
  end
  ui.sameLine(columnSize)
  if colorButtonEx("Turbo progress color", AppConfig.turboProgress) then
    AppConfig.turboProgress = AppConfig.turboProgress
  end
  if colorButtonEx("Best lap color", AppConfig.bestLap) then
    AppConfig.bestLap = AppConfig.bestLap
  end
  ui.sameLine(columnSize)
  if colorButtonEx("Legends color", AppConfig.legend) then
    AppConfig.legend = AppConfig.legend
  end
  if colorButtonEx("Separator color", AppConfig.separator) then
    AppConfig.separator = AppConfig.separator
  end
  ui.sameLine(columnSize)
  if colorButtonEx("Background color", AppConfig.bgColor) then
    AppConfig.bgColor = AppConfig.bgColor
  end
end

local function formatTimeLeft(ms)
  return (ms <= 0 and "Overtime") or os.date("!%X", ms / 1000)
end

local function loadTurboInfo(focused, count)
  local engineIni = ac.INIConfig.carData(focused, 'engine.ini')
  local totalBoost = 0
  for i = 0, count - 1 do
    totalBoost = totalBoost + engineIni:get(("TURBO_%d"):format(i), "MAX_BOOST", 0)
  end
  return totalBoost
end

local function loadP2PInfo(focused)
  local engineIni = ac.INIConfig.carData(focused, 'engine.ini')
  local activeTime = engineIni:get("PUSH_TO_PASS", "TIME_SECONDS", 0)
  local coolDownTime = engineIni:get("PUSH_TO_PASS", "COOLDOWN_SECONDS", 0)
  return coolDownTime, activeTime
end

function script.update(dt)
  if not appVisible then return end
  local sim = ac.getSim()
  local car = ac.getCar(sim.focusedCar)
  if timerP2P > 0 then
    timerP2P = math.max(0, timerP2P - dt)
    ac.debug("timer", timerP2P)
  end
  if car then
    if focusedCar ~= sim.focusedCar then
      focusedCar = sim.focusedCar
      if car.turboCount > 0 then
        maxBoost = loadTurboInfo(focusedCar, car.turboCount)
      end
      if car.p2pStatus > 0 then
        P2PcoolDownTime, P2PactiveTime = loadP2PInfo(focusedCar)
      end
    end

    local timeStr       = "-:--:--"
    -- Online conditions
    local isRaceTimed   = sim.raceSessionType == ac.SessionType.Race and sim.isTimedRace
    local isRace        = sim.raceSessionType == ac.SessionType.Race
    local isOnlineTimed = sim.raceSessionType ~= ac.SessionType.Race and sim.isOnlineRace
    -- Offline conditions
    local isHotlap      = sim.raceSessionType == ac.SessionType.Hotlap
    if isRaceTimed or isOnlineTimed or isHotlap then
      timeStr = tostring(formatTimeLeft(sim.sessionTimeLeft))
    end
    local lapStr = "--"
    if not isRaceTimed and isRace then
      local totalLaps = ac.getSession(sim.currentSessionIndex).laps
      lapStr = string.format("%.2d/%.2d", car.lapCount, totalLaps)
    else
      lapStr = string.format("%.2d", car.lapCount)
    end

    -- 1) Détection d’une entrée en cooldown (status passe à 1)
    if car.p2pStatus == 1 and prevStatus ~= 1 then
      -- on initialise le timer à la durée fixe fournie par l’API (en secondes)
      timerP2P = P2PcoolDownTime or 0
      prevStatus = 1
    end
    -- 2) Détection d’une entrée en mode actif (status passe à 3)
    if car.p2pStatus == 3 and prevStatus ~= 3 then
      timerP2P = P2PactiveTime
      prevStatus = 3
    end
    -- 2) Détection d’une entrée en mode pret (status passe à 3)
    if car.p2pStatus == 2 and prevStatus ~= 2 then
      timerP2P = 0
      prevStatus = 2
    end
    local remainTimeStr = "-:--"
    if car.previousLapTimeMs > 0 and car.fuelPerLap > 0 then
      -- moyenne des deux derniers tours
      local timeLap = (car.bestLapTimeMs + car.previousLapTimeMs) / 2
      -- temps restant (ms)
      local remainTime = (car.fuel / car.fuelPerLap) * timeLap
      local totalSec = remainTime / 1000
      local minutes = math.floor(totalSec / 60)
      local seconds = math.floor(totalSec % 60)
      remainTimeStr = string.format("%d:%02d", minutes, seconds)
    end
    local remainingLap = car.fuelPerLap > 0 and car.fuel / car.fuelPerLap or 0
    local gearStr = (car.gear < 0 and "R") or (car.gear == 0 and "N") or tostring(car.gear)

    carStates = {
      gear                              = gearStr,
      speedKmh                          = string.format("%d", car.speedKmh),
      rpm                               = car.rpm,
      rpmLimiter                        = car.rpmLimiter,
      rpmNormalized                     = car.rpm / car.rpmLimiter,
      lapTimeMs                         = car.lapTimeMs,
      bestLapTimeMs                     = ac.lapTimeToString(car.bestLapTimeMs),
      previousLapTimeMs                 = ac.lapTimeToString(car.previousLapTimeMs),
      performanceMeter                  = car.performanceMeter,
      estimatedLapTimeMs                = ac.lapTimeToString(car.estimatedLapTimeMs),
      fuelStr                           = string.format("%0.2f", car.fuel),
      nFuel                             = car.fuel / car.maxFuel,
      fuelPerLapStr                     = string.format("%.2f", car.fuelPerLap),
      racePosition                      = string.format("%02d/%02d", car.racePosition, sim.carsCount),
      carsCount                         = sim.carsCount or 0,
      remainingLapStr                   = string.format("%.2f", remainingLap),
      remainTimeStr                     = remainTimeStr,
      brake                             = car.brake,
      gas                               = car.gas,
      lapCountStr                       = lapStr,
      sessionTimeLeft                   = timeStr,
      sessionType                       = sim.raceSessionType,
      airTemperature                    = string.format("%.0f°", sim.ambientTemperature),
      roadTemperature                   = string.format("%.0f°", sim.roadTemperature),
      brakeBias                         = string.format("%.1f/%.1f", car.brakeBias * 100, (1 - car.brakeBias) * 100),
      TC                                = car.tractionControlMode,
      tcInAction                        = car.tractionControlInAction,
      TC2                               = car.tractionControl2Modes,
      ABS                               = car.absMode,
      absInAction                       = car.absInAction,
      p2pStatus                         = car.p2pStatus,
      p2pActivations                    = string.format("%02d", car.p2pActivations),
      P2PcoolDownTime                   = P2PcoolDownTime,
      P2PactiveTime                     = P2PactiveTime,
      drsPresent                        = car.drsPresent,
      drsActive                         = car.drsActive,
      drsAvailable                      = car.drsAvailable,
      kersPresent                       = car.kersPresent,
      kersStatus                        = (car.kersCharging and 2)
          or (car.kersButtonPressed and 3)
          or 1,
      kersCharge                        = car.kersCharge,
      kersMaxKJ                         = car.kersMaxKJ,
      kersCurrentKJ                     = car.kersCurrentKJ,
      adjustableTurbo                   = car.adjustableTurbo,
      turboWastegates                   = car.turboWastegates,
      turboCount                        = car.turboCount,
      turboBoosts                       = car.turboBoosts,
      turboBoost                        = car.turboBoost,
      maxBoost                          = maxBoost,
      hazardLights                      = car.hazardLights,
      turningLeftOnly                   = car.turningLeftOnly,
      turningRightOnly                  = car.turningRightOnly,
      speedLimiterInAction              = car.speedLimiterInAction,
      manualPitsSpeedLimiterEnabled     = car.manualPitsSpeedLimiterEnabled,
      wiperSelectedMode                 = car.wiperSelectedMode,
      beamsStatus                       = not car.headlightsActive and 0 or car.lowBeams and 1 or 2,
      isLapValid                        = car.isLapValid,
      isLastLapValid                    = car.isLastLapValid,
      performanceMeterSpeedDifferenceMs = car.performanceMeterSpeedDifferenceMs,
    }
  end
end

function script.onShowWindowMain() appVisible = true end

function script.onHideWindowMain() appVisible = false end
