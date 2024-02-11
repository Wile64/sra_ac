--
-- Created by Wile64 on october 2023
--
-- https://github.com/ac-custom-shaders-patch/acc-lua-sdk/blob/main/.definitions/ac_common.txt

require('classes/settings')
require('classes/carsra')
local carState = CarSRA()
local config = Settings()

local showDiscTemp = false
local discInfos = {
  ["Front"] = 0,
  ["minFrontTemp"] = 0,
  ["maxFrontTemp"] = 0,
  ["idealMinFrontTemp"] = 0,
  ["idealMaxFrontTemp"] = 999999,
  ["Rear"] = 0,
  ["minRearTemp"] = 0,
  ["maxRearTemp"] = 0,
  ["idealMinRearTemp"] = 0,
  ["idealMaxRearTemp"] = 999999
}

local loadedDiscInfo = false

local function progressBarV(progress, rectSize, color)
  progress = math.min(math.max(progress, 0), 1) -- Assurez-vous que la valeur est dans la plage 0-1

  local startPosition = ui.getCursor()
  local progressBarFilledSize = vec2(rectSize.x, rectSize.y * progress)

  ui.drawRect(startPosition, startPosition + rectSize, rgbm.colors.gray)
  startPosition.y = startPosition.y + (rectSize.y - progressBarFilledSize.y)
  ui.drawRectFilled(startPosition, startPosition + progressBarFilledSize, color)
  ui.dummy(rectSize + 1 * config.Scale)
end

local function toeIn(value, rectSize, color)
  local middleRect = vec2(rectSize.x / 2, 0)
  local minValue = -20
  local maxValue = 20

  -- Assurez-vous que la valeur est dans la plage autorisée
  value = math.min(maxValue, math.max(minValue, value))

  -- Calculez la position de la barre en fonction de la valeur
  --  local normalizedValue = (value - minValue) / (maxValue - minValue)
  local normalizedValue = value / maxValue
  local barPosition = ui.getCursor()

  -- Dessinez la barre de progression
  ui.drawRect(barPosition, barPosition + rectSize, rgbm.colors.gray)
  if value > 0 then
    ui.drawRectFilled(barPosition + middleRect, barPosition + middleRect +
      vec2(middleRect.x * normalizedValue, rectSize.y), color) -- Barre verte
  else
    ui.drawRectFilled(barPosition + (middleRect + vec2(middleRect.x * normalizedValue, 0)),
      barPosition + vec2(middleRect.x, rectSize.y),
      color) -- Barre verte
  end
  ui.dwriteTextAligned(string.format("%.2f", value), 8 * config.Scale, ui.Alignment.Start,
    ui.Alignment.Center, rectSize, false, rgbm.colors.white)
end

local function getTyreColor(tyreTemp, tyreOptimum)
  local minValue = 80
  local redComponent = 0
  local greenComponent = 0
  local blueComponent = 0

  local mappedProgress
  if tyreTemp < minValue then
    mappedProgress = (minValue - tyreTemp) / 20
  elseif tyreTemp > tyreOptimum then
    mappedProgress = (tyreTemp - tyreOptimum) / 20
  else
    mappedProgress = 1
  end
  mappedProgress = math.min(math.max(mappedProgress, 0), 1)
  if tyreTemp < minValue then
    greenComponent = 1 - mappedProgress
    blueComponent = mappedProgress
  elseif tyreTemp > tyreOptimum then
    greenComponent = 1 - mappedProgress
    redComponent = mappedProgress
  else
    greenComponent = mappedProgress
  end
  return rgbm(redComponent, greenComponent, blueComponent, 1)
end


local function getDiscColor(DiscTemp, front)
  local redComponent   = 0
  local greenComponent = 0
  local blueComponent  = 0
  local idealminValue  = 0
  local idealmaxValue  = 0
  local minValue       = 0
  local maxValue       = 0
  if front then
    idealminValue = discInfos["idealMinFrontTemp"]
    minValue = discInfos["minFrontTemp"]
  else
    idealminValue = discInfos["idealMinRearTemp"]
    minValue = discInfos["minRearTemp"]
  end
  if front then
    idealmaxValue = discInfos["idealMaxFrontTemp"]
    maxValue = discInfos["maxFrontTemp"]
  else
    idealmaxValue = discInfos["idealMaxRearTemp"]
    maxValue = discInfos["maxRearTemp"]
  end

  local mappedProgress
  if DiscTemp < idealminValue then
    mappedProgress = (idealminValue - DiscTemp) / (idealminValue - minValue)
  elseif DiscTemp > idealmaxValue then
    mappedProgress = (DiscTemp - idealmaxValue) / (maxValue - idealmaxValue)
  else
    mappedProgress = 1
  end
  mappedProgress = math.min(math.max(mappedProgress, 0), 1)
  if DiscTemp < idealminValue then
    greenComponent = 1 - mappedProgress
    blueComponent = mappedProgress
  elseif DiscTemp > idealmaxValue then
    greenComponent = 1 - mappedProgress
    redComponent = mappedProgress
  else
    greenComponent = mappedProgress
  end
  return rgbm(redComponent, greenComponent, blueComponent, 1)
end

---comment
---@param tyre ac.StateWheel
---@param rectSize vec2
---@param front boolean
local function drawTyreLeft(tyre, rectSize, front)
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, 1)
  if config.showGrain then
    progressBarV(tyre.tyreGrain, vec2(8 * config.Scale, rectSize.y), rgbm.colors.maroon)
    if ui.itemHovered() then
      ui.tooltip(function()
        ui.pushFont(ui.Font.Monospace)
        ui.text(
          "Tyre Grain\nThis doesn't seem to be well managed,\nif you drive with cold tires,\nit only increases more")
        ui.popFont()
      end)
    end
    ui.sameLine()
  end
  if config.showBlister then
    progressBarV(tyre.tyreBlister, vec2(8 * config.Scale, rectSize.y), rgbm.colors.olive)
    if ui.itemHovered() then
      ui.tooltip(function()
        ui.pushFont(ui.Font.Monospace)
        ui.text("Tyre Blister")
        ui.popFont()
      end)
    end
    ui.sameLine()
  end
  if config.showFlatSpot then
    progressBarV(tyre.tyreFlatSpot, vec2(8 * config.Scale, rectSize.y), rgbm.colors.silver)
    if ui.itemHovered() then
      ui.tooltip(function()
        ui.pushFont(ui.Font.Monospace)
        ui.text("Tyre FlatSpot")
        ui.popFont()
      end)
    end
    ui.sameLine()
  end
  if config.showLoad then
    progressBarV(tyre.load / 10000, vec2(8 * config.Scale, rectSize.y), rgbm.colors.orange)
    if ui.itemHovered() then
      ui.tooltip(function()
        ui.pushFont(ui.Font.Monospace)
        ui.text("Tyre Load")
        ui.popFont()
      end)
    end
  end
  ui.sameLine()
  ui.popStyleVar()
  ui.beginGroup()
  if config.showToeIn then
    toeIn(tyre.toeIn, vec2(rectSize.x * 3, 10 * config.Scale), rgbm.colors.cyan)
    if ui.itemHovered() then
      ui.tooltip(function()
        ui.pushFont(ui.Font.Monospace)
        ui.text("ToeIn")
        ui.popFont()
      end)
    end
  end
  ui.setCursorX(ui.getCursorX() + 3 * config.Scale)
  ui.beginRotation()
  local startPosition = ui.getCursor()
  local startCore = vec2(startPosition.x + 1, startPosition.y + 3)

  ui.drawRectFilled(startPosition, startPosition + rectSize,
    getTyreColor(tyre.tyreInsideTemperature, tyre.tyreOptimumTemperature), 4)
  if tyre.ndSlip > 1 then
    ui.drawRect(startPosition, startPosition + rectSize, rgbm.colors.orange, 4)
  end
  startPosition.x = startPosition.x + rectSize.x + 1
  ui.drawRectFilled(startPosition, startPosition + rectSize,
    getTyreColor(tyre.tyreMiddleTemperature, tyre.tyreOptimumTemperature), 3)
  if tyre.ndSlip > 1 then
    ui.drawRect(startPosition, startPosition + rectSize, rgbm.colors.orange, 4)
  end
  startPosition.x = startPosition.x + rectSize.x + 1
  ui.drawRectFilled(startPosition, startPosition + rectSize,
    getTyreColor(tyre.tyreOutsideTemperature, tyre.tyreOptimumTemperature), 4)

  local tyreImage = ".//images//core.png"
  local size = vec2(rectSize.x * 3, rectSize.y - 10)
  ui.drawImage(tyreImage, startCore, startCore + size,
    getTyreColor(tyre.tyreCoreTemperature, tyre.tyreOptimumTemperature))

  if showDiscTemp and config.showDisc then
    local discPosition = startPosition + vec2(18 * config.Scale, 15 * config.Scale)
    if front then
      ui.drawRectFilled(discPosition, discPosition + (rectSize - vec2(12 * config.Scale, 28 * config.Scale)),
        getDiscColor(tyre.discTemperature, true), 4, true)
    else
      ui.drawRectFilled(discPosition, discPosition + (rectSize - vec2(12 * config.Scale, 28 * config.Scale)),
        getDiscColor(tyre.discTemperature, false), 4, false)
    end
  end
  if tyre.ndSlip > 1 then
    ui.drawRect(startPosition, startPosition + rectSize, rgbm.colors.orange, 4)
  end
  if tyre.tyreDirty > 0 then
    local durtySize = vec2(rectSize.x, rectSize.y * (tyre.tyreDirty / 5.0))
    local startDurty = ui.getCursor()
    startDurty.y = startPosition.y + (rectSize.y - durtySize.y)
    ui.drawRectFilled(startDurty, startDurty + durtySize, rgbm.colors.olive, 4)
    startDurty.x = startDurty.x + rectSize.x + 1
    ui.drawRectFilled(startDurty, startDurty + durtySize, rgbm.colors.olive, 3)
    startDurty.x = startDurty.x + rectSize.x + 1
    ui.drawRectFilled(startDurty, startDurty + durtySize, rgbm.colors.olive, 4)
  end
  local avg = 0
  if front then
    avg = tyre.tyrePressure - carState.idealFrontPressure
  else
    avg = tyre.tyrePressure - carState.idealRearPressure
  end
  local infos = string.format("Core %d°\n%.1f PSI\n%0.1f", tyre.tyreCoreTemperature, tyre.tyrePressure, avg)
  if avg >= 0 then
    infos = string.format("Core %d°\n%.1f PSI\n+%0.1f", tyre.tyreCoreTemperature, tyre.tyrePressure, avg)
  end
  ui.dwriteDrawTextClipped(infos, 11 * config.Scale, ui.getCursor(), ui.getCursor() + vec2(rectSize.x * 3, rectSize.y),
    ui.Alignment.Center, ui.Alignment.Center, false, rgbm.colors.black)
  local camber = math.min(math.max(tyre.camber, -4), 4)
  ui.endRotation(90 + camber)
  ui.dummy(vec2(rectSize.x * 3.3, rectSize.y))
  ui.dwriteTextAligned(
    string.format("%4d%4d%4d", tyre.tyreInsideTemperature, tyre.tyreMiddleTemperature, tyre.tyreOutsideTemperature),
    8 * config.Scale, ui.Alignment.Center, ui.Alignment.Center, vec2(rectSize.x * 3, 9 * config.Scale), false,
    rgbm.colors.white)
  ui.endGroup()
  ui.sameLine()
  progressBarV(1 - tyre.tyreWear, vec2(10 * config.Scale, rectSize.y), rgbm.colors.green)
  if ui.itemHovered() then
    ui.tooltip(function()
      ui.pushFont(ui.Font.Monospace)
      ui.text("Tyre Wear")
      ui.popFont()
    end)
  end
end

---comment
---@param tyre ac.StateWheel
---@param rectSize vec2
---@param front boolean
local function drawTyreRight(tyre, rectSize, front)
  progressBarV(1 - tyre.tyreWear, vec2(10 * config.Scale, rectSize.y), rgbm.colors.green)
  if ui.itemHovered() then
    ui.tooltip(function()
      ui.pushFont(ui.Font.Monospace)
      ui.text("Tyre Wear")
      ui.popFont()
    end)
  end
  ui.sameLine()
  ui.setCursorX(ui.getCursorX()+1)
  ui.beginGroup()
  if config.showToeIn then
    toeIn(tyre.toeIn, vec2(rectSize.x * 3, 10 * config.Scale), rgbm.colors.cyan)
    if ui.itemHovered() then
      ui.tooltip(function()
        ui.pushFont(ui.Font.Monospace)
        ui.text("ToeIn")
        ui.popFont()
      end)
    end
  end
  ui.setCursorX(ui.getCursorX() + 3 * config.Scale)

  local startPosition = ui.getCursor()
  local startCore = vec2(startPosition.x + 1, startPosition.y + 3)

  ui.beginRotation()

  local discPosition = startPosition + vec2(-6 * config.Scale, 15 * config.Scale)

  ui.drawRectFilled(startPosition, startPosition + rectSize,
    getTyreColor(tyre.tyreInsideTemperature, tyre.tyreOptimumTemperature), 4)
  if tyre.ndSlip > 1 then
    ui.drawRect(startPosition, startPosition + rectSize, rgbm.colors.orange, 4)
  end
  startPosition.x = startPosition.x + rectSize.x + 1
  ui.drawRectFilled(startPosition, startPosition + rectSize,
    getTyreColor(tyre.tyreMiddleTemperature, tyre.tyreOptimumTemperature), 3)
  if tyre.ndSlip > 1 then
    ui.drawRect(startPosition, startPosition + rectSize, rgbm.colors.orange, 4)
  end
  startPosition.x = startPosition.x + rectSize.x + 1
  ui.drawRectFilled(startPosition, startPosition + rectSize,
    getTyreColor(tyre.tyreOutsideTemperature, tyre.tyreOptimumTemperature), 4)
  if tyre.ndSlip > 1 then
    ui.drawRect(startPosition, startPosition + rectSize, rgbm.colors.orange, 4)
  end
  local tyreImage = ".//images//core.png"
  local size = vec2(rectSize.x * 3, rectSize.y - 10)
  ui.drawImage(tyreImage, startCore, startCore + size,
    getTyreColor(tyre.tyreCoreTemperature, tyre.tyreOptimumTemperature))

  if tyre.tyreDirty > 0 then
    local durtySize = vec2(rectSize.x, rectSize.y * (tyre.tyreDirty / 5.0))
    local startDurty = ui.getCursor()
    startDurty.y = startPosition.y + (rectSize.y - durtySize.y)
    ui.drawRectFilled(startDurty, startDurty + durtySize, rgbm.colors.olive, 4)
    startDurty.x = startDurty.x + rectSize.x + 1
    ui.drawRectFilled(startDurty, startDurty + durtySize, rgbm.colors.olive, 3)
    startDurty.x = startDurty.x + rectSize.x + 1
    ui.drawRectFilled(startDurty, startDurty + durtySize, rgbm.colors.olive, 4)
  end
  if showDiscTemp and config.showDisc then
    if front then
      ui.drawRectFilled(discPosition, discPosition + (rectSize - vec2(12 * config.Scale, 28 * config.Scale)),
        getDiscColor(tyre.discTemperature, true), 4, true)
    else
      ui.drawRectFilled(discPosition, discPosition + (rectSize - vec2(12 * config.Scale, 28 * config.Scale)),
        getDiscColor(tyre.discTemperature, false), 4, false)
    end
  end

  local avg = 0
  if front then
    avg = tyre.tyrePressure - carState.idealFrontPressure
  else
    avg = tyre.tyrePressure - carState.idealRearPressure
  end
  local infos = string.format("Core %d°\n%.1f PSI\n%0.1f", tyre.tyreCoreTemperature, tyre.tyrePressure, avg)
  if avg >= 0 then
    infos = string.format("Core %d°\n%.1f PSI\n+%0.1f", tyre.tyreCoreTemperature, tyre.tyrePressure, avg)
  end
  ui.dwriteDrawTextClipped(infos, 11 * config.Scale, ui.getCursor(), ui.getCursor() + vec2(rectSize.x * 3, rectSize.y),
    ui.Alignment.Center, ui.Alignment.Center, false, rgbm.colors.black)
  local camber = math.min(math.max(tyre.camber, -4), 4)

  ui.endRotation(90 - camber)
  ui.dummy(vec2(rectSize.x * 3.3, rectSize.y))
  ui.dwriteTextAligned(
    string.format(" %4d%4d%4d", tyre.tyreInsideTemperature, tyre.tyreMiddleTemperature, tyre.tyreOutsideTemperature),
    8 * config.Scale, ui.Alignment.Center, ui.Alignment.Center, vec2(rectSize.x * 3, 9 * config.Scale), false,
    rgbm.colors.white)
  ui.endGroup()
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, 1)
  if config.showLoad then
    ui.sameLine()
    progressBarV(tyre.load / 10000, vec2(8 * config.Scale, rectSize.y), rgbm.colors.orange)
    if ui.itemHovered() then
      ui.tooltip(function()
        ui.pushFont(ui.Font.Monospace)
        ui.text("Tyre Load")
        ui.popFont()
      end)
    end
  end
  if config.showFlatSpot then
    ui.sameLine()
    progressBarV(tyre.tyreFlatSpot, vec2(8 * config.Scale, rectSize.y), rgbm.colors.silver)
    if ui.itemHovered() then
      ui.tooltip(function()
        ui.pushFont(ui.Font.Monospace)
        ui.text("Tyre FlatSpot")
        ui.popFont()
      end)
    end
  end
  if config.showBlister then
    ui.sameLine()
    progressBarV(tyre.tyreBlister, vec2(8 * config.Scale, rectSize.y), rgbm.colors.olive)
    if ui.itemHovered() then
      ui.tooltip(function()
        ui.pushFont(ui.Font.Monospace)
        ui.text("Tyre Blister")
        ui.popFont()
      end)
    end
  end
  if config.showGrain then
    ui.sameLine()
    progressBarV(tyre.tyreGrain, vec2(8 * config.Scale, rectSize.y), rgbm.colors.maroon)
    if ui.itemHovered() then
      ui.tooltip(function()
        ui.pushFont(ui.Font.Monospace)
        ui.text("Tyre Grain\nThis doesn't seem to be well managed,\nif you drive with cold tires,\nit only increases")
        ui.popFont()
      end)
    end
  end
  ui.popStyleVar()
end

local function loadDiscInfo()
  local brakeini = ac.INIConfig.carData(0, 'brakes.ini')

  local frontLut = brakeini:tryGetLut("TEMPS_FRONT", "PERF_CURVE")
  local rearLut = brakeini:tryGetLut("TEMPS_REAR", "PERF_CURVE")
  if frontLut ~= nil then
    for i = 0, #frontLut - 1 do
      if frontLut:getPointOutput(i) == 1 then
        local input = frontLut:getPointInput(i)
        if discInfos["idealMinFrontTemp"] < input then
          discInfos["idealMinFrontTemp"] = input
        end
        if discInfos["idealMaxFrontTemp"] > input then
          discInfos["idealMaxFrontTemp"] = input
        end
      end
    end
    local min, max = frontLut:bounds()
    discInfos["minFrontTemp"] = min.x
    discInfos["maxFrontTemp"] = max.x
    discInfos["Front"] = frontLut
    showDiscTemp = true
  end
  if rearLut ~= nil then
    for i = 0, #rearLut - 1 do
      if rearLut:getPointOutput(i) == 1 then
        local input = rearLut:getPointInput(i)
        if discInfos["idealMinRearTemp"] < input then
          discInfos["idealMinRearTemp"] = input
        end
        if discInfos["idealMaxRearTemp"] > input then
          discInfos["idealMaxRearTemp"] = input
        end
      end
    end
    local min, max = rearLut:bounds()
    discInfos["minRearTemp"] = min.x
    discInfos["maxRearTemp"] = max.x
    discInfos["Rear"] = rearLut
    showDiscTemp = true
  end
  loadedDiscInfo = true
end

function script.windowMain(dt)
  if not loadedDiscInfo then
    loadDiscInfo()
  end
  ui.pushDWriteFont('montserrat:\\fonts\\.')
  local drawOffset = ui.getCursor()
  local contentSize = ui.windowSize():sub(drawOffset)
  display.rect({ pos = drawOffset, size = contentSize, color = rgbm(0.1, 0.1, 0.1, 0.3) })

  local tyreSize = vec2(18 * config.Scale, 70 * config.Scale)

  if config.showTyreName then
    ui.dwriteText(string.format("Tyre : %s", ac.getTyresLongName(0, carState.carState.compoundIndex)), 10 * config.Scale,
      rgbm.colors.white)
  end
  if config.showOptimal then
    ui.dwriteText(string.format("Optimum Temperature : %3.0f°", carState:getTyreFL().tyreOptimumTemperature), 10 * config
      .Scale, rgbm.colors.white)
  end
  ui.separator()

  drawTyreLeft(carState:getTyreFL(), tyreSize, true)
  ui.sameLine()
  drawTyreRight(carState:getTyreFR(), tyreSize, true)
  ui.separator()

  drawTyreLeft(carState:getTyreRL(), tyreSize, false)
  ui.sameLine()
  drawTyreRight(carState:getTyreRR(), tyreSize, false)
  ui.popDWriteFont()
end

function script.update(dt)
  carState:setCarID(0)
  carState:update(dt)
  if ac.getSim().isInMainMenu then
    ac.setWindowOpen("windowSetup", true)
  end
end

---@param title string
---@param value string
local function inline(title, value)
  ui.dwriteText(title, 15, rgbm.colors.white)
  --ui.bulletText(title)
  ui.sameLine(175)
  ui.dwriteText(value, 15, rgbm.colors.lime)
  --  ui.textColored(value, rgbm.colors.cyan)
end

---@param tyre ac.StateWheel
local function showTyreInfo(tyre, front)
  inline("- Static Pressure:", string.format("%2.2f PSI", tyre.tyreStaticPressure))
  inline("- Pressure:", string.format("%2.2f PSI", tyre.tyrePressure))
  local avg = 0
  if front then
    avg = tyre.tyrePressure - carState.idealFrontPressure
  else
    avg = tyre.tyrePressure - carState.idealRearPressure
  end
  local infos = string.format("%0.1f", avg)
  if avg >= 0 then
    infos = string.format("+%0.1f", avg)
  end
  inline("- Optimum:", infos)
  inline("- Pressure:", string.format("%2.2f BAR", tyre.tyrePressure * 0.0689476))
  inline("- Camber:", string.format("%2.2f° ", tyre.camber))
  inline("- toeIn:", string.format("%2.2f° ", tyre.toeIn))
  inline("- tyreWidth:", string.format("%2.f", tyre.tyreWidth * 1000))
  inline("- fx:", string.format("%2.f", tyre.dx))
  inline("- fy:", string.format("%2.f", tyre.dy))
end

local function tabTyres()
  ui.dwriteText("Tyres Setup Assist", 15, rgbm.colors.red)

  ui.columns(2, false, "##TyreTable")
  ui.dwriteText("Front left", 15, rgbm.colors.orange)
  showTyreInfo(carState:getTyreFL())
  ui.nextColumn()
  ui.dwriteText("Front right", 15, rgbm.colors.orange)
  showTyreInfo(carState:getTyreFR())
  ui.nextColumn()
  ui.newLine()
  ui.dwriteText("Rear left", 15, rgbm.colors.orange)
  showTyreInfo(carState:getTyreRL())
  ui.nextColumn()
  ui.newLine()
  ui.dwriteText("Rear right", 15, rgbm.colors.orange)
  showTyreInfo(carState:getTyreRR())
  ui.nextColumn()
  ui.newLine()
end

local function drawTyre(degree, left, toe)
  local size = vec2(40, 70)
  local c = ui.getCursor()
  c.x = c.x + 10
  ui.beginRotation()
  ui.drawRectFilled(c, c + size, rgbm.colors.red, 4)
  if left then
    ui.endRotation(90 + degree)
  else
    ui.endRotation(90 - degree)
  end
  ui.drawLine(vec2(c.x + size.x / 2, c.y - 2), vec2(c.x + size.x / 2, c.y + size.y + 2), rgbm.colors.yellow)
  if not toe then
    ui.drawLine(vec2(c.x - 10, c.y + size.y + 1), vec2(c.x + size.x + 10, c.y + size.y + 1), rgbm.colors.gray)
  end
  ui.dummy(vec2(size.x + 20, size.y))
  ui.dwriteText(string.format("%2.2f°", degree), 15, rgbm.colors.white)
end

local function tabAlignment()
  ui.dwriteText("Alignment Setup Assist", 15, rgbm.colors.red)
  ui.columns(4, false, "##TyreTable")
  ui.dwriteText("Camber", 15, rgbm.colors.orange)
  ui.separator()
  ui.nextColumn()
  drawTyre(carState:getTyreFL().camber, true, false)
  ui.nextColumn()
  drawTyre(carState:getTyreFR().camber, false, false)
  ui.nextColumn()
  ui.nextColumn()
  ui.nextColumn()
  drawTyre(carState:getTyreRL().camber, true, false)
  ui.nextColumn()
  drawTyre(carState:getTyreRR().camber, false, false)
  ui.nextColumn()
  ui.nextColumn()
  ui.dwriteText("ToeIn", 15, rgbm.colors.orange)
  ui.separator()
  ui.nextColumn()
  drawTyre(carState:getTyreFL().toeIn, true, true)
  ui.nextColumn()
  drawTyre(carState:getTyreFR().toeIn, false, true)
  ui.nextColumn()
  ui.nextColumn()
  ui.nextColumn()
  drawTyre(carState:getTyreRL().toeIn, true, true)
  ui.nextColumn()
  drawTyre(carState:getTyreRR().toeIn, false, true)
  ui.newLine()
end

function script.windowSetup(dt)
  ui.pushFont(ui.Font.Title)

  ui.tabBar('TabBar##', function()
    ui.tabItem('Tyres', tabTyres)
    ui.tabItem('Alignment', tabAlignment)
  end)

  ui.popFont()
end

function script.windowSetting(dt)
  local newScale = ui.slider('##scaleSlider', config.Scale, 0.5, 2.0, 'Scale: %1.1f%')
  if ui.itemEdited() then
    config.Scale = newScale
  end
  if ui.checkbox("Show Optimal", config.showOptimal) then
    config.showOptimal = not config.showOptimal
  end
  if ui.checkbox("Show Tyres Name", config.showTyreName) then
    config.showTyreName = not config.showTyreName
  end
  if ui.checkbox("Show ToeIn", config.showToeIn) then
    config.showToeIn = not config.showToeIn
  end
  if ui.checkbox("Show Grain", config.showGrain) then
    config.showGrain = not config.showGrain
  end
  if ui.checkbox("Show Blister", config.showBlister) then
    config.showBlister = not config.showBlister
  end
  if ui.checkbox("Show FlatSpot", config.showFlatSpot) then
    config.showFlatSpot = not config.showFlatSpot
  end
  if ui.checkbox("Show Load", config.showLoad) then
    config.showLoad = not config.showLoad
  end
  if ui.checkbox("Show Disc", config.showDisc) then
    config.showDisc = not config.showDisc
  end
  ui.separator()
  ui.setCursorX(210)
  if ui.iconButton(ui.Icons.Save, vec2(50, 0), 0, true, ui.ButtonFlags.Activable) then
    config:save()
  end
end
