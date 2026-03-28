local SectorWidget = {}
SectorWidget.__index = SectorWidget

local function sectorTimeToString(value)
  return ac.lapTimeToString(value and value > 0 and value or 0)
end

local function drawValueRow(label, value, from, to, font, labelColor, accent, scale)
  local padding = 6 * scale
  local labelWidth = 12 * scale

  ui.dwriteDrawTextClipped(label, font.size * 0.68 * scale, from + vec2(padding, 0),
    from + vec2(padding + labelWidth, to.y - from.y), ui.Alignment.Start, ui.Alignment.Center, false, labelColor)
  ui.dwriteDrawTextClipped(value, font.size * 0.92 * scale, from + vec2(padding + labelWidth, 0),
    to - vec2(padding, 0), ui.Alignment.End, ui.Alignment.Center, false, accent)
end

local function rowAccent(kind, value, bestValue, isCurrentSector, colors)
  if kind == 'current' then
    return colors.valueNeutral
  end

  if value <= 0 then
    return colors.valueNeutral
  end

  if kind == 'best' then
    return colors.valueBestTime
  end

  if bestValue > 0 then
    local delta = value - bestValue
    if math.abs(delta) <= 1 then
      return colors.valueBestTime
    end

    return colors.valueNeutral
  end

  return colors.valueNeutral
end

local function drawSectorCard(index, currentValue, lastValue, bestValue, size, font, colors, scale, options)
  local pos = ui.getCursor()
  local radius = 10 * scale
  local accent = colors.border
  if options.isCurrentSector then
    accent = colors.valueEdit
  elseif lastValue > 0 and bestValue > 0 then
    accent = rowAccent('last', lastValue, bestValue, false, colors)
  end

  ui.drawRectFilled(pos, pos + size, colors.background, radius, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)
  ui.drawRect(pos, pos + size, accent, radius, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft, 1)

  local headerHeight = 18 * scale
  local rowHeight = 18 * scale
  local rowGap = 2 * scale
  local y = headerHeight + 4 * scale

  ui.dwriteDrawTextClipped('S' .. tostring(index + 1), font.size * 0.75 * scale, pos + vec2(6 * scale, 0),
    pos + vec2(size.x - 6 * scale, headerHeight), ui.Alignment.Center, ui.Alignment.Center, false, colors.label)

  if options.showCurrent then
    drawValueRow('C', sectorTimeToString(currentValue), pos + vec2(0, y), pos + vec2(size.x, y + rowHeight), font,
      colors.label, rowAccent('current', currentValue, bestValue, options.isCurrentSector, colors), scale)
    y = y + rowHeight + rowGap
  end

  if options.showLast then
    drawValueRow('L', sectorTimeToString(lastValue), pos + vec2(0, y), pos + vec2(size.x, y + rowHeight), font,
      colors.label, rowAccent('last', lastValue, bestValue, false, colors), scale)
    y = y + rowHeight + rowGap
  end

  if options.showBest then
    drawValueRow('B', sectorTimeToString(bestValue), pos + vec2(0, y), pos + vec2(size.x, y + rowHeight), font,
      colors.label, bestValue > 0 and colors.valueBestTime or colors.valueNeutral, scale)
  end

  ui.dummy(size)
end

function SectorWidget:new()
  return setmetatable({
    id = 'sector',
    title = 'Sector',
    windowId = 'windowSector',
    sectorCount = 0,
    currentSector = -1,
    lapTimeMs = 0,
    currentSplits = {},
    lastSplits = {},
    bestSplits = {},
  }, self)
end

function SectorWidget:update(dt, context)
  local car = context.car
  local sim = context.sim
  if not car or not sim then
    return
  end

  self.sectorCount = #(sim.lapSplits or {})
  self.currentSector = car.currentSector or -1
  self.lapTimeMs = car.lapTimeMs or 0
  self.currentSplits = car.currentSplits or {}
  self.lastSplits = car.lastSplits or {}
  self.bestSplits = car.bestSplits or {}
end

function SectorWidget:draw(dt, drawContext)
  local scale = (drawContext.scale or 1) * (drawContext.sectorScale or 1)
  local colors = drawContext.colors
  local font = drawContext.font
  local sectorColors = {
    background = colors.background,
    text = colors.label,
    border = colors.border,
    valueEdit = drawContext.colors.valueEdit,
    valueBestTime = drawContext.colors.valueBestTime,
  }
  local showCurrent = drawContext.sectorShowCurrent ~= false
  local showLast = drawContext.sectorShowLast ~= false
  local showBest = drawContext.sectorShowBest ~= false

  local rows = 0
  if showCurrent then rows = rows + 1 end
  if showLast then rows = rows + 1 end
  if showBest then rows = rows + 1 end
  if rows == 0 then
    return
  end

  local count = math.max(1, self.sectorCount)
  local gap = 4 * scale
  local totalWidth = 220 * scale
  local width = math.max(48 * scale, math.min(76 * scale, (totalWidth - gap * (count - 1)) / count))
  local cardHeight = (24 + rows * 20) * scale

  ui.pushDWriteFont(font.police)
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(gap, gap))

  local elapsedBefore = 0
  for i = 0, count - 1 do
    if i > 0 then ui.sameLine() end

    local currentValue = self.currentSplits[i] or 0
    if self.currentSector == i then
      currentValue = math.max(0, self.lapTimeMs - elapsedBefore)
    end

    drawSectorCard(i, currentValue, self.lastSplits[i] or 0, self.bestSplits[i] or 0, vec2(width, cardHeight), font,
      sectorColors, scale, {
        showCurrent = showCurrent,
        showLast = showLast,
        showBest = showBest,
        isCurrentSector = i == self.currentSector,
      })

    elapsedBefore = elapsedBefore + (self.currentSplits[i] or 0)
  end

  ui.popStyleVar()
  ui.popDWriteFont()
end

return SectorWidget
