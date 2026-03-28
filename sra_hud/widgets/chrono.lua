local ChronoWidget = {}
ChronoWidget.__index = ChronoWidget

local InfoCards = require('core.info_cards')

local function lapTimeToString(value)
  return ac.lapTimeToString(value > 0 and value or 0)
end

local function deltaToString(value)
  if math.abs(value) < 0.0005 then
    return '0.000'
  end

  return string.format('%+.3f', value)
end

function ChronoWidget:new()
  return setmetatable({
    id = 'chrono',
    title = 'Chrono',
    windowId = 'windowChrono',
    currentLap = '00:00.000',
    lastLap = '00:00.000',
    bestLap = '00:00.000',
    delta = '0.000',
    deltaValue = 0,
  }, self)
end

function ChronoWidget:update(dt, context)
  local car = context.car
  if not car then
    return
  end

  self.currentLap = lapTimeToString(car.lapTimeMs)
  self.lastLap = lapTimeToString(car.previousLapTimeMs)
  self.bestLap = lapTimeToString(car.bestLapTimeMs)
  self.deltaValue = car.performanceMeter
  self.delta = deltaToString(car.performanceMeter)
end

function ChronoWidget:draw(dt, drawContext)
  local scale = (drawContext.scale or 1) * (drawContext.chronoScale or 1)
  local colors = drawContext.colors
  local font = drawContext.font
  local showCurrent = drawContext.chronoShowCurrent ~= false
  local showPrevious = drawContext.chronoShowPrevious ~= false
  local showBest = drawContext.chronoShowBest ~= false
  local showDelta = drawContext.chronoShowDelta ~= false

  local accentBest = colors.valueBestTime
  local accentCurrent = colors.valueNeutral
  local accentLast = colors.valueNeutral
  local accentDelta = self.deltaValue <= 0 and drawContext.style.delta.green or drawContext.style.delta.red

  local width = 130 * scale
  local cardSize = vec2(width, 34 * scale)

  ui.pushDWriteFont(font.police)
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(4 * scale, 2 * scale))

  if showCurrent then
    InfoCards.drawLabelValueCard('Current', self.currentLap, cardSize, font, colors, accentCurrent, scale)
  end

  if showPrevious then
    InfoCards.drawLabelValueCard('Last', self.lastLap, cardSize, font, colors, accentLast, scale)
  end

  if showBest then
    InfoCards.drawLabelValueCard('Best', self.bestLap, cardSize, font, colors, accentBest, scale)
  end

  if showDelta then
    InfoCards.drawValueCard(self.delta, cardSize, font, colors, accentDelta, scale * 1.30)
  end

  ui.popStyleVar()
  ui.popDWriteFont()
end

return ChronoWidget
