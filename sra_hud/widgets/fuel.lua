local FuelWidget = {}
FuelWidget.__index = FuelWidget

local InfoCards = require('core.info_cards')

local LITER_TO_GALLON = 0.2641720524

local function clamp01(value)
  return math.max(0, math.min(1, value))
end

local function lerpColor(a, b, t)
  return rgbm(
    a.r + (b.r - a.r) * t,
    a.g + (b.g - a.g) * t,
    a.b + (b.b - a.b) * t,
    a.mult + (b.mult - a.mult) * t
  )
end

function FuelWidget:new()
  return setmetatable({
    id = 'fuel',
    title = 'Fuel',
    windowId = 'windowFuel',
    fuel = 0,
    maxFuel = 1,
    fuelPerLap = 0,
    estimatedLaps = 0,
    estimatedTimeMs = 0,
    referenceLapTimeMs = 0,
    lapsText = '--',
    timeText = '--',
    percent = 0,
    available = true,
  }, self)
end

local function convertFuelUnit(value, useGallons)
  if useGallons then
    return value * LITER_TO_GALLON, 'gal'
  end

  return value, 'L'
end

local function formatRemainingTime(ms)
  if not ms or ms <= 0 then
    return '--'
  end

  local totalSeconds = math.floor(ms / 1000 + 0.5)
  local hours = math.floor(totalSeconds / 3600)
  local minutes = math.floor((totalSeconds % 3600) / 60)
  local seconds = totalSeconds % 60

  if hours > 0 then
    return string.format('%d:%02d:%02d', hours, minutes, seconds)
  end

  return string.format('%02d:%02d', minutes, seconds)
end

function FuelWidget:update(dt, context)
  local car = context.car
  if not car then
    return
  end

  self.available = car.isUserControlled or car.index == 0
  if not self.available then
    self.fuel = 0
    self.maxFuel = 1
    self.fuelPerLap = 0
    self.percent = 0
    self.estimatedLaps = 0
    self.estimatedTimeMs = 0
    self.referenceLapTimeMs = 0
    self.lapsText = 'N/A'
    self.timeText = 'N/A'
    return
  end

  self.fuel = car.fuel
  self.maxFuel = math.max(car.maxFuel, 1)
  self.fuelPerLap = car.fuelPerLap
  self.percent = clamp01(self.fuel / self.maxFuel)
  self.estimatedLaps = car.fuelPerLap > 0 and (car.fuel / car.fuelPerLap) or 0
  self.referenceLapTimeMs = math.max(car.previousLapTimeMs or 0, car.bestLapTimeMs or 0, car.lapTimeMs or 0)
  self.estimatedTimeMs = (self.estimatedLaps > 0 and self.referenceLapTimeMs > 0)
      and (self.estimatedLaps * self.referenceLapTimeMs) or 0
  self.lapsText = car.fuelPerLap > 0 and string.format('%.1f', self.estimatedLaps) or '--'
  self.timeText = formatRemainingTime(self.estimatedTimeMs)
end

function FuelWidget:draw(dt, drawContext)
  local scale = (drawContext.scale or 1) * (drawContext.fuelScale or 1)
  local useGallons = drawContext.fuelUseGallons or false
  local colors = drawContext.colors
  local fuelColors = drawContext.style.fuel
  local font = drawContext.font
  local showBar = drawContext.fuelShowBar ~= false
  local showPerLap = drawContext.fuelShowPerLap ~= false
  local showLaps = drawContext.fuelShowLaps ~= false
  local showTimeLeft = drawContext.fuelShowTimeLeft ~= false

  local fuelSafe = rgbm(fuelColors.safe.r, fuelColors.safe.g, fuelColors.safe.b, 0.80)
  local fuelWarning = rgbm(fuelColors.warning.r, fuelColors.warning.g, fuelColors.warning.b, 0.80)
  local fuelCritical = rgbm(fuelColors.critical.r, fuelColors.critical.g, fuelColors.critical.b, 0.85)
  local accentFuel = fuelSafe
  local width = 130 * scale
  local barSize = vec2(width, 30 * scale)
  local cardSize = vec2(width, 30 * scale)
  local currentFuelValue, fuelUnit = convertFuelUnit(self.fuel, useGallons)
  local fuelPerLapValue = self.fuelPerLap

  if useGallons then
    fuelPerLapValue = fuelPerLapValue * LITER_TO_GALLON
  end

  if self.fuelPerLap > 0 then
    if self.estimatedLaps <= 3 then
      accentFuel = fuelCritical
    elseif self.estimatedLaps < 5 then
      accentFuel = lerpColor(fuelCritical, fuelWarning, (self.estimatedLaps - 3) / 2)
    elseif self.estimatedLaps < 8 then
      accentFuel = lerpColor(fuelWarning, fuelSafe, (self.estimatedLaps - 5) / 3)
    end
  end

  ui.pushDWriteFont(font.police)
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(4 * scale, 2 * scale))

  if not self.available then
    if showBar then
      InfoCards.drawValueCard('N/A', barSize, font, colors, colors.valueNeutral, scale)
    end
    if showPerLap then
      InfoCards.drawLabelValueCard('Per lap', 'N/A', cardSize, font, colors, colors.valueNeutral, scale)
    end
    if showLaps then
      InfoCards.drawLabelValueCard('Laps left', 'N/A', cardSize, font, colors, colors.valueNeutral, scale)
    end
    if showTimeLeft then
      InfoCards.drawLabelValueCard('Time left', 'N/A', cardSize, font, colors, colors.valueNeutral, scale)
    end
    ui.popStyleVar()
    ui.popDWriteFont()
    return
  end

  if showBar then
    local pos = ui.getCursor()
    ui.drawRectFilled(pos, pos + barSize, colors.background, 4 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)
    if self.percent > 0 then
      ui.drawRectFilled(pos, pos + vec2(barSize.x * self.percent, barSize.y), accentFuel, 4 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)
    end
    ui.drawRect(pos, pos + barSize, colors.border, 4 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft, 1)
    ui.dwriteDrawTextClipped(string.format('%.1f %s', currentFuelValue, fuelUnit), font.size * scale,
      pos + vec2(10 * scale, 0), pos + vec2(barSize.x - 10 * scale, barSize.y),
      ui.Alignment.Center, ui.Alignment.Center, false, colors.valueNeutral)
    ui.dummy(barSize)
  end

  if showPerLap then
    InfoCards.drawLabelValueCard('Per lap', string.format('%.2f %s', fuelPerLapValue, fuelUnit), cardSize, font, colors, colors.valueNeutral, scale)
  end
  if showLaps then
    InfoCards.drawLabelValueCard('Laps left', self.lapsText, cardSize, font, colors, colors.valueNeutral, scale)
  end
  if showTimeLeft then
    InfoCards.drawLabelValueCard('Time left', self.timeText, cardSize, font, colors, colors.valueNeutral, scale)
  end

  ui.popStyleVar()
  ui.popDWriteFont()
end

return FuelWidget
