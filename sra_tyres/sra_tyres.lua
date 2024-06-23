--
-- Created by Wile64 on october 2023
--
-- https://github.com/ac-custom-shaders-patch/acc-lua-sdk/blob/main/.definitions/ac_common.txt

require('classes/settings')
require('classes/carsra')
VERSION = 1.300
DEBUG = true

local carInfo = CarSRA()
local config = Settings()

local isShowGripInfo = false

local gripInfos = {
  frontLoaded = false,
  frontHigh = 0,
  frontMedium = 0,
  frontLow = 0,
  rearLoaded = false,
  RearHigh = 0,
  RearMedium = 0,
  RearLow = 0,
}

local images = {
  brakeDiscLeft = "/images/BrakeDiscleft.png",
  brakeDiscRight = "/images/BrakeDiscright.png",
  slip = "/images/slip.png",
  core = "/images/core.png"
}

local tyrewheelLocks = {}
table.insert(tyrewheelLocks, 0, { wheelLock = false, flatSpotValue = 0 })
table.insert(tyrewheelLocks, 1, { wheelLock = false, flatSpotValue = 0 })
table.insert(tyrewheelLocks, 2, { wheelLock = false, flatSpotValue = 0 })
table.insert(tyrewheelLocks, 3, { wheelLock = false, flatSpotValue = 0 })

local function progressBarV(progress, rectSize, color)
  progress = math.min(math.max(progress, 0), 1) -- Assurez-vous que la valeur est dans la plage 0-1

  local startPosition = ui.getCursor()
  local progressBarFilledSize = vec2(rectSize.x, rectSize.y * progress)

  ui.drawRect(startPosition, startPosition + rectSize, rgbm.colors.gray)
  startPosition.y = startPosition.y + (rectSize.y - progressBarFilledSize.y)
  ui.drawRectFilled(startPosition, startPosition + progressBarFilledSize, color)
  ui.dummy(rectSize + 1 * config.Scale)
end

local function WearProgress(progress, tyreVirtualKM, rectSize, color, front)
  progress = math.min(math.max(progress, 0), 1) -- Assurez-vous que la valeur est dans la plage 0-1

  local startPosition = ui.getCursor()
  local progressBarFilledSize = vec2(rectSize.x, rectSize.y * progress)

  if front then
    if carInfo.frontWearCurve ~= nil then
      if carInfo.frontWearCurve:get(tyreVirtualKM) > 99.5 then
        color = rgbm.colors.green
      elseif carInfo.frontWearCurve:get(tyreVirtualKM) > 98 then
        color = rgbm.colors.yellow
      else
        color = rgbm.colors.red
      end
    end
  else
    if carInfo.rearWearCurve ~= nil then
      if carInfo.rearWearCurve:get(tyreVirtualKM) > 99.5 then
        color = rgbm.colors.green
      elseif carInfo.rearWearCurve:get(tyreVirtualKM) > 98 then
        color = rgbm.colors.yellow
      else
        color = rgbm.colors.red
      end
    end
  end
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

local function getTyreColor(tyreTemp)
  local minValue = carInfo.minThermal
  local maxValue = carInfo.maxThermal
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
    idealminValue = carInfo.discData.idealMinFrontTemp
    minValue = carInfo.discData.minFrontTemp
    idealmaxValue = carInfo.discData.idealMaxFrontTemp
    maxValue = carInfo.discData.maxFrontTemp
  else
    idealminValue = carInfo.discData.idealMinRearTemp
    minValue = carInfo.discData.minRearTemp
    idealmaxValue = carInfo.discData.idealMaxRearTemp
    maxValue = carInfo.discData.maxRearTemp
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
  local startCore = vec2(startPosition.x + 1, startPosition.y + 12)
  local startSlip = vec2(startPosition.x + 1, startPosition.y)
  if config.showDisc and carInfo.isDiscAvailable then
    local discPosition = vec2(startPosition.x + rectSize.x * 2, startPosition.y) +
        vec2(19 * config.Scale, 10 * config.Scale)
    ui.drawImage(images.brakeDiscLeft, discPosition,
      discPosition + (rectSize - vec2(10 * config.Scale, 18 * config.Scale)),
      getDiscColor(tyre.discTemperature, front))
  end
  ui.drawRectFilled(startPosition, startPosition + rectSize,
    tyre.isBlown == false and getTyreColor(tyre.tyreInsideTemperature) or
    rgbm(0, 0, 0, 1), 4)
  startPosition.x = startPosition.x + rectSize.x + 1
  ui.drawRectFilled(startPosition, startPosition + rectSize,
    tyre.isBlown == false and getTyreColor(tyre.tyreMiddleTemperature) or
    rgbm(0, 0, 0, 1), 3)
  startPosition.x = startPosition.x + rectSize.x + 1
  ui.drawRectFilled(startPosition, startPosition + rectSize,
    tyre.isBlown == false and getTyreColor(tyre.tyreOutsideTemperature) or
    rgbm(0, 0, 0, 1), 4)
  local tyreLeft = 2
  if front then
    tyreLeft = 0
  end
  if tyrewheelLocks[tyreLeft].flatSpotValue ~= tyre.tyreFlatSpot then
    tyrewheelLocks[tyreLeft].flatSpotValue = tyre.tyreFlatSpot
    tyrewheelLocks[tyreLeft].wheelLock = true
  else
    tyrewheelLocks[tyreLeft].wheelLock = false
  end

  local size = vec2(rectSize.x * 3, rectSize.y - 24)
  if tyrewheelLocks[tyreLeft].wheelLock or tyre.isBlown then
    ui.drawImage(images.core, startCore, startCore + size, rgbm.colors.white)
  else
    ui.drawImage(images.core, startCore, startCore + size,
      getTyreColor(tyre.tyreCoreTemperature))
  end

  if tyre.tyreDirty > 0 and not tyre.isBlown then
    local durtySize = vec2(rectSize.x, rectSize.y * (tyre.tyreDirty / 5.0))
    local startDurty = ui.getCursor()
    startDurty.y = startPosition.y + (rectSize.y - durtySize.y)
    ui.drawRectFilled(startDurty, startDurty + durtySize, rgbm.colors.olive, 4)
    startDurty.x = startDurty.x + rectSize.x + 1
    ui.drawRectFilled(startDurty, startDurty + durtySize, rgbm.colors.olive, 3)
    startDurty.x = startDurty.x + rectSize.x + 1
    ui.drawRectFilled(startDurty, startDurty + durtySize, rgbm.colors.olive, 4)
  end

  if tyre.ndSlip > 1 and not tyre.isBlown then
    local sizeSlip = vec2(rectSize.x * 3, rectSize.y)
    ui.drawImage(images.slip, startSlip, startSlip + sizeSlip, rgbm.colors.orange)
  end

  local avg = 0
  if front then
    avg = tyre.tyrePressure - carInfo.idealFrontPressure
  else
    avg = tyre.tyrePressure - carInfo.idealRearPressure
  end
  local infos = string.format("Core %d°\n%.1f PSI\n%0.1f", tyre.tyreCoreTemperature, tyre.tyrePressure, avg)
  if avg >= 0 then
    infos = string.format("Core %d°\n%.1f PSI\n+%0.1f", tyre.tyreCoreTemperature, tyre.tyrePressure, avg)
  end
  if tyre.isBlown then
    infos = "Blown"
  end
  ui.dwriteDrawTextClipped(infos, 11 * config.Scale, ui.getCursor(), ui.getCursor() + vec2(rectSize.x * 3, rectSize.y),
    ui.Alignment.Center, ui.Alignment.Center, false, rgbm.colors.black)
  local camber = math.min(math.max(tyre.camber, -4), 4)
  ui.endRotation(90 + camber)

  ui.dummy(vec2(rectSize.x * 3.3, rectSize.y))

  if tyre.isBlown then
    ui.dwriteTextAligned(
      string.format(" %4s%4s%4s", "-", "-", "-"),
      8 * config.Scale, ui.Alignment.Center, ui.Alignment.Center, vec2(rectSize.x * 3, 9 * config.Scale), false,
      rgbm.colors.white)
  else
    ui.dwriteTextAligned(
      string.format(" %4d%4d%4d", tyre.tyreInsideTemperature, tyre.tyreMiddleTemperature, tyre.tyreOutsideTemperature),
      8 * config.Scale, ui.Alignment.Center, ui.Alignment.Center, vec2(rectSize.x * 3, 9 * config.Scale), false,
      rgbm.colors.white)
  end
  if config.showWearGrip then
    if front and carInfo.frontWearCurve ~= nil then
      ui.dwriteTextAligned(string.format(" %0.2f%%", carInfo.frontWearCurve:get(tyre.tyreVirtualKM)), 8 * config.Scale,
        ui.Alignment.Center, ui.Alignment.Center, vec2(rectSize.x * 3, 9 * config.Scale), false, rgbm.colors.white)
    elseif carInfo.rearWearCurve ~= nil then
      ui.dwriteTextAligned(string.format(" %0.2f%%", carInfo.rearWearCurve:get(tyre.tyreVirtualKM)), 8 * config.Scale,
        ui.Alignment.Center, ui.Alignment.Center, vec2(rectSize.x * 3, 9 * config.Scale), false, rgbm.colors.white)
    end
  end
  ui.endGroup()
  ui.sameLine()
  WearProgress(tyre.isBlown == false and 1 - tyre.tyreWear or 0, tyre.tyreVirtualKM, vec2(10 * config.Scale, rectSize.y),
    rgbm.colors.green, front)
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
  WearProgress(tyre.isBlown == false and 1 - tyre.tyreWear or 0, tyre.tyreVirtualKM, vec2(10 * config.Scale, rectSize.y),
    rgbm.colors.green, front)
  if ui.itemHovered() then
    ui.tooltip(function()
      ui.pushFont(ui.Font.Monospace)
      ui.text("Tyre Wear")
      ui.popFont()
    end)
  end
  ui.sameLine()
  ui.setCursorX(ui.getCursorX() + 1)
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
  local startCore = vec2(startPosition.x + 1, startPosition.y + 12)
  local startSlip = vec2(startPosition.x + 1, startPosition.y)

  ui.beginRotation()

  local discPosition = startPosition + vec2(-7 * config.Scale, 10 * config.Scale)
  if config.showDisc and carInfo.isDiscAvailable then
    ui.drawImage(images.brakeDiscRight, discPosition,
      discPosition + (rectSize - vec2(10 * config.Scale, 18 * config.Scale)),
      getDiscColor(tyre.discTemperature, front))
  end
  ui.drawRectFilled(startPosition, startPosition + rectSize,
    tyre.isBlown == false and getTyreColor(tyre.tyreInsideTemperature) or
    rgbm(0, 0, 0, 1), 4)
  startPosition.x = startPosition.x + rectSize.x + 1
  ui.drawRectFilled(startPosition, startPosition + rectSize,
    tyre.isBlown == false and getTyreColor(tyre.tyreMiddleTemperature) or
    rgbm(0, 0, 0, 1), 3)
  startPosition.x = startPosition.x + rectSize.x + 1
  ui.drawRectFilled(startPosition, startPosition + rectSize,
    tyre.isBlown == false and getTyreColor(tyre.tyreOutsideTemperature) or
    rgbm(0, 0, 0, 1), 4)

  local tyreRight = 3
  if front then
    tyreRight = 1
  end
  if tyrewheelLocks[tyreRight].flatSpotValue ~= tyre.tyreFlatSpot then
    tyrewheelLocks[tyreRight].flatSpotValue = tyre.tyreFlatSpot
    tyrewheelLocks[tyreRight].wheelLock = true
  else
    tyrewheelLocks[tyreRight].wheelLock = false
  end
  local sizeCore = vec2(rectSize.x * 3, rectSize.y - 24)
  if tyrewheelLocks[tyreRight].wheelLock or tyre.isBlown then
    ui.drawImage(images.core, startCore, startCore + sizeCore, rgbm.colors.white)
  else
    ui.drawImage(images.core, startCore, startCore + sizeCore,
      getTyreColor(tyre.tyreCoreTemperature))
  end

  if tyre.tyreDirty > 0 and not tyre.isBlown then
    local durtySize = vec2(rectSize.x, rectSize.y * (tyre.tyreDirty / 5.0))
    local startDurty = ui.getCursor()
    startDurty.y = startPosition.y + (rectSize.y - durtySize.y)
    ui.drawRectFilled(startDurty, startDurty + durtySize, rgbm.colors.olive, 4)
    startDurty.x = startDurty.x + rectSize.x + 1
    ui.drawRectFilled(startDurty, startDurty + durtySize, rgbm.colors.olive, 3)
    startDurty.x = startDurty.x + rectSize.x + 1
    ui.drawRectFilled(startDurty, startDurty + durtySize, rgbm.colors.olive, 4)
  end
  if tyre.ndSlip > 1 and not tyre.isBlown then
    local sizeSlip = vec2(rectSize.x * 3, rectSize.y)
    ui.drawImage(images.slip, startSlip, startSlip + sizeSlip, rgbm.colors.orange)
  end
  local avg = 0
  if front then
    avg = tyre.tyrePressure - carInfo.idealFrontPressure
  else
    avg = tyre.tyrePressure - carInfo.idealRearPressure
  end
  local infos = string.format("Core %d°\n%.1f PSI\n%0.1f", tyre.tyreCoreTemperature, tyre.tyrePressure, avg)
  if avg >= 0 then
    infos = string.format("Core %d°\n%.1f PSI\n+%0.1f", tyre.tyreCoreTemperature, tyre.tyrePressure, avg)
  end
  if tyre.isBlown then
    infos = "Blown"
  end
  ui.dwriteDrawTextClipped(infos, 11 * config.Scale, ui.getCursor(), ui.getCursor() + vec2(rectSize.x * 3, rectSize.y),
    ui.Alignment.Center, ui.Alignment.Center, false, rgbm.colors.black)
  local camber = math.min(math.max(tyre.camber, -4), 4)

  ui.endRotation(90 - camber)

  ui.dummy(vec2(rectSize.x * 3.3, rectSize.y))
  if tyre.isBlown then
    ui.dwriteTextAligned(
      string.format(" %4s%4s%4s", "-", "-", "-"),
      8 * config.Scale, ui.Alignment.Center, ui.Alignment.Center, vec2(rectSize.x * 3, 9 * config.Scale), false,
      rgbm.colors.white)
  else
    ui.dwriteTextAligned(
      string.format(" %4d%4d%4d", tyre.tyreInsideTemperature, tyre.tyreMiddleTemperature, tyre.tyreOutsideTemperature),
      8 * config.Scale, ui.Alignment.Center, ui.Alignment.Center, vec2(rectSize.x * 3, 9 * config.Scale), false,
      rgbm.colors.white)
  end
  if config.showWearGrip then
    if front and carInfo.frontWearCurve ~= nil then
      ui.dwriteTextAligned(string.format(" %0.2f%%", carInfo.frontWearCurve:get(tyre.tyreVirtualKM)), 8 * config.Scale,
        ui.Alignment.Center, ui.Alignment.Center, vec2(rectSize.x * 3, 9 * config.Scale), false, rgbm.colors.white)
    elseif carInfo.rearWearCurve ~= nil then
      ui.dwriteTextAligned(string.format(" %0.2f%%", carInfo.rearWearCurve:get(tyre.tyreVirtualKM)), 8 * config.Scale,
        ui.Alignment.Center, ui.Alignment.Center, vec2(rectSize.x * 3, 9 * config.Scale), false, rgbm.colors.white)
    end
  end
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

local function showGripInfo(pos)
  ui.sameLine()
  ui.beginChild("showInfo", vec2(250, 160), true, ui.WindowFlags.AlwaysAutoResize)
  local frontWear = carInfo.frontWearCurve
  local rearWear = carInfo.rearWearCurve
  local tyreConsumptionRate = ac.getSim().tyreConsumptionRate
  if frontWear ~= nil then
    gripInfos.frontLoaded = true
    ui.header("Front:")
    for i = 0, #frontWear - 1 do
      local grip = frontWear:getPointOutput(i)
      if grip > 99.5 then
        gripInfos.frontHigh = 10 * frontWear:getPointInput(i) / tyreConsumptionRate
      end
      if (grip < 99.5) and (grip > 96) then
        gripInfos.frontMedium = 10 * frontWear:getPointInput(i) / tyreConsumptionRate
      end
      if grip < 96 then
        gripInfos.frontLow = 10 * frontWear:getPointInput(i) / tyreConsumptionRate
      end
    end
    local tracklenght = ac.getSim().trackLengthM / 1000
    ui.text(string.format("High grip %.1f Km (%0.1f lap)", gripInfos.frontHigh, gripInfos.frontHigh / tracklenght))
    ui.text(string.format("Medium grip %.1f Km (%0.1f lap)", gripInfos.frontMedium, gripInfos.frontMedium / tracklenght))
    ui.text(string.format("Low grip %.1f Km (%0.1f lap)", gripInfos.frontLow, gripInfos.frontLow / tracklenght))
  else
    ui.text("No front lut info !")
  end
  if rearWear ~= nil then
    gripInfos.rearLoaded = true
    ui.header("Rear:")
    for i = 0, #rearWear - 1 do
      local grip = rearWear:getPointOutput(i)
      if grip > 99.5 then
        gripInfos.RearHigh = 100 * rearWear:getPointInput(i) / tyreConsumptionRate
      end
      if (grip < 99.5) and (grip > 96) then
        gripInfos.RearMedium = 100 * rearWear:getPointInput(i) / tyreConsumptionRate
      end
      if grip < 96 then
        gripInfos.RearLow = 100 * rearWear:getPointInput(i) / tyreConsumptionRate
      end
    end
    local tracklenght = ac.getSim().trackLengthM / 1000
    ui.text(string.format("High grip %.1f Km (%0.1f lap)", gripInfos.RearHigh, gripInfos.RearHigh / tracklenght))
    ui.text(string.format("Medium grip %.1f Km (%0.1f lap)", gripInfos.RearMedium, gripInfos.RearMedium / tracklenght))
    ui.text(string.format("Low grip %.1f Km (%0.1f lap)", gripInfos.RearLow, gripInfos.RearLow / tracklenght))
  else
    ui.text("No rear lut info !")
  end
  ui.endChild()
end

local function ShowDebug()
  ui.toolWindow("#Debug", vec2(100, 100), vec2(100, 100), function()

  end)
end

function script.windowMain(dt)
  ac.setWindowTitle('windowMain', string.format('SRA Tyres v%2.3f', VERSION))
  ui.pushDWriteFont('montserrat:/fonts')
  local drawOffset = ui.getCursor()
  local contentSize = ui.windowSize():sub(drawOffset)
  display.rect({ pos = drawOffset, size = contentSize, color = rgbm(0.1, 0.1, 0.1, 0.3) })

  local tyreSize = vec2(18 * config.Scale, 70 * config.Scale)

  if config.showTyreName then
    ui.dwriteText(string.format("Tyre : %s", ac.getTyresLongName(0, carInfo.carState.compoundIndex)), 10 * config.Scale,
      rgbm.colors.white)
  end
  if config.showOptimal then
    ui.dwriteText(string.format("Optimum Temperature : %3.0f° - %3.0f°", carInfo.minThermal, carInfo.maxThermal), 10 * config
      .Scale, rgbm.colors.white)
  end

  ui.separator()

  drawTyreLeft(carInfo:getTyreFL(), tyreSize, true)
  ui.sameLine()
  drawTyreRight(carInfo:getTyreFR(), tyreSize, true)
  if ui.mouseClicked(ui.MouseButton.Middle) then
    isShowGripInfo = not isShowGripInfo
  end

  if isShowGripInfo then
    showGripInfo(ui.getCursor())
  end

  ui.separator()

  drawTyreLeft(carInfo:getTyreRL(), tyreSize, false)
  ui.sameLine()
  drawTyreRight(carInfo:getTyreRR(), tyreSize, false)
  ui.popDWriteFont()
  if DEBUG then
    ShowDebug()
  end
end

function script.update(dt)
  carInfo:setCarID(0)
  carInfo:update(dt)
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
    avg = tyre.tyrePressure - carInfo.idealFrontPressure
  else
    avg = tyre.tyrePressure - carInfo.idealRearPressure
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
  showTyreInfo(carInfo:getTyreFL())
  ui.nextColumn()
  ui.dwriteText("Front right", 15, rgbm.colors.orange)
  showTyreInfo(carInfo:getTyreFR())
  ui.nextColumn()
  ui.newLine()
  ui.dwriteText("Rear left", 15, rgbm.colors.orange)
  showTyreInfo(carInfo:getTyreRL())
  ui.nextColumn()
  ui.newLine()
  ui.dwriteText("Rear right", 15, rgbm.colors.orange)
  showTyreInfo(carInfo:getTyreRR())
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
  drawTyre(carInfo:getTyreFL().camber, true, false)
  ui.nextColumn()
  drawTyre(carInfo:getTyreFR().camber, false, false)
  ui.nextColumn()
  ui.nextColumn()
  ui.nextColumn()
  drawTyre(carInfo:getTyreRL().camber, true, false)
  ui.nextColumn()
  drawTyre(carInfo:getTyreRR().camber, false, false)
  ui.nextColumn()
  ui.nextColumn()
  ui.dwriteText("ToeIn", 15, rgbm.colors.orange)
  ui.separator()
  ui.nextColumn()
  drawTyre(carInfo:getTyreFL().toeIn, true, true)
  ui.nextColumn()
  drawTyre(carInfo:getTyreFR().toeIn, false, true)
  ui.nextColumn()
  ui.nextColumn()
  ui.nextColumn()
  drawTyre(carInfo:getTyreRL().toeIn, true, true)
  ui.nextColumn()
  drawTyre(carInfo:getTyreRR().toeIn, false, true)
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
  if ui.checkbox("Show Wear Grip", config.showWearGrip) then
    config.showWearGrip = not config.showWearGrip
  end
  ui.separator()
  ui.sameLine(200)
  if ui.iconButton(ui.Icons.Save, vec2(50, 0), 0, true, ui.ButtonFlags.Activable) then
    config:save()
  end
end
