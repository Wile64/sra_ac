local SpeedWidget = {}
SpeedWidget.__index = SpeedWidget

local ShiftLogic = require('core.shift_logic')

local function clamp01(x)
  if x < 0 then return 0 end
  if x > 1 then return 1 end
  return x
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function mixColor(a, b, t)
  return rgbm(
    lerp(a.r, b.r, t),
    lerp(a.g, b.g, t),
    lerp(a.b, b.b, t),
    lerp(a.mult, b.mult, t)
  )
end

local function darkenColor(c, factor, multFactor)
  return rgbm(c.r * factor, c.g * factor, c.b * factor, c.mult * multFactor)
end

local function rpmColor(style, t)
  if t < 0.5 then
    return mixColor(style.rpm.low, style.rpm.mid, t / 0.5)
  end
  return mixColor(style.rpm.mid, style.rpm.high, (t - 0.5) / 0.5)
end

local function drawSegmentedRpmBar(startPos, size, rpmNorm, shiftNorm, scale, borderColor, panelColor, colors, style)
  local segments = 20
  local gap = 2 * scale
  local innerPad = 4 * scale
  local segW = (size.x - innerPad * 2 - gap * (segments - 1)) / segments
  local segH = size.y - innerPad * 2
  local lit = math.floor(rpmNorm * segments + 0.0001)

  local bg = darkenColor(panelColor, 0.18, 0.60)
  ui.drawRectFilled(startPos, startPos + size, bg, 8 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)
  ui.drawRect(startPos, startPos + size, borderColor, 5 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)

  for i = 1, segments do
    local t = (i - 1) / (segments - 1)
    local p = startPos + vec2(innerPad + (i - 1) * (segW + gap), innerPad)
    local c = rpmColor(style, t)
    if i <= lit then
      ui.drawRectFilled(p - vec2(2, 2) * scale, p + vec2(segW, segH) + vec2(2, 2) * scale, rgbm(c.r, c.g, c.b, 0.14),
        4 * scale)
      ui.drawRectFilled(p, p + vec2(segW, segH), c, 1 * scale)
      ui.drawRect(p - 1, p + vec2(segW, segH) + 1, rgbm(c.r, c.g, c.b, 0.95), 4 * scale)
    else
      ui.drawRectFilled(p, p + vec2(segW, segH), colors.backgroundAlt, 4 * scale)
    end
  end

  if shiftNorm and shiftNorm > 0 and shiftNorm < 1 then
    local markerX = startPos.x + innerPad + (size.x - innerPad * 2) * shiftNorm
    ui.drawLine(vec2(markerX, startPos.y + 3 * scale), vec2(markerX, startPos.y + size.y - 3 * scale), colors.border, 2)
  end
end

local function gearToString(gear)
  return gear < 0 and 'R' or gear == 0 and 'N' or tostring(gear)
end

function SpeedWidget:new()
  return setmetatable({
    id = 'speed',
    title = 'Speed',
    windowId = 'windowSpeed',
    speedKmh = 0,
    gear = 'N',
    rpm = 0,
    rpmLimiter = 1,
    tcMode = 0,
    absMode = 0,
    brakeBias = 0,
    gearIndex = 0,
    gearCount = 0,
    focusedCarIndex = -1,
    shiftLogic = ShiftLogic:new(),
    recommendedShiftRpm = nil,
  }, self)
end

function SpeedWidget:update(dt, context)
  local car = context.car
  if not car then
    return
  end

  if self.focusedCarIndex ~= car.index then
    self.focusedCarIndex = car.index
    self.shiftLogic:load(car.index)
  end

  self.speedKmh = math.floor(car.speedKmh + 0.5)
  self.gear = gearToString(car.gear)
  self.gearIndex = math.max(0, car.gear or 0)
  self.gearCount = car.gearCount or 0
  self.rpm = math.floor(car.rpm + 0.5)
  self.rpmLimiter = math.max(1, car.rpmLimiter)
  self.tcMode = car.tractionControlMode or 0
  self.absMode = car.absMode or 0
  self.brakeBias = car.brakeBias or 0
  self.recommendedShiftRpm = self.shiftLogic:getShiftRpm(self.gearIndex)
end

function SpeedWidget:draw(dt, drawContext)
  local scale = (drawContext.scale or 1) * (drawContext.speedScale or 1)
  local useMph = drawContext.speedUseMph or false
  local colors = drawContext.colors
  local style = drawContext.style
  local font = drawContext.font

  local accent = colors.valueNeutral
  local line = colors.border
  local displaySpeed = self.speedKmh
  local speedUnit = 'km/h'

  if useMph then
    displaySpeed = self.speedKmh * 0.621371
    speedUnit = 'mph'
  end

  local panelPos = ui.getCursor()
  local panelSize = vec2(300, 112) * scale
  local knownGearCount = math.max(self.gearCount or 0, self.shiftLogic.gearCount or 0)
  local hasNextGear = self.gearIndex > 0 and (knownGearCount == 0 or self.gearIndex < knownGearCount)
  local fallbackShiftRpm = hasNextGear and math.max(1, self.rpmLimiter - 100) or nil
  local activeShiftRpm = self.recommendedShiftRpm
  if activeShiftRpm and activeShiftRpm >= self.rpmLimiter - 25 then
    activeShiftRpm = fallbackShiftRpm
  end
  activeShiftRpm = activeShiftRpm or fallbackShiftRpm
  local rpmNorm = clamp01(self.rpm / self.rpmLimiter)
  local shiftNorm = activeShiftRpm and clamp01(activeShiftRpm / self.rpmLimiter) or nil
  local showShift = hasNextGear and self.rpm >= (activeShiftRpm or math.huge)
  local panelBg = showShift and drawContext.style.speed.shiftAlert or colors.background
  local panelBgDark = darkenColor(colors.background, 0.22, 0.70)
  local gearAccent = showShift and colors.valueNegative or accent

  ui.pushDWriteFont(font.police)
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(0, 0))

  ui.drawRectFilled(panelPos, panelPos + panelSize, panelBg, 10 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)
  ui.drawRect(panelPos, panelPos + panelSize, line, 10 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)

  local rpmBarPos = panelPos + vec2(12, 8) * scale
  local rpmBarSize = vec2(panelSize.x - 24 * scale, 22 * scale)
  drawSegmentedRpmBar(rpmBarPos, rpmBarSize, rpmNorm, shiftNorm, scale, line, panelBg, colors, style)

  if activeShiftRpm then
    local shiftColor = showShift and colors.valueNegative or colors.valueNeutral
    local shiftText = showShift and 'SHIFT' or tostring(activeShiftRpm)
    ui.dwriteDrawTextClipped(shiftText, 13 * scale,
      rpmBarPos + vec2(8 * scale, 0), rpmBarPos + rpmBarSize - vec2(8 * scale, 0),
      ui.Alignment.End, ui.Alignment.Center, false, shiftColor)
  end

  local contentPos = panelPos + vec2(16, 36) * scale
  local contentSize = vec2(panelSize.x - 32 * scale, 44 * scale)
  local gap = 6 * scale
  local speedBoxSize = vec2(contentSize.x * 0.72 - gap * 0.5, contentSize.y)
  local gearBoxPos = vec2(contentPos.x + speedBoxSize.x + gap, contentPos.y)
  local gearBoxSize = vec2(contentSize.x - speedBoxSize.x - gap, contentSize.y)

  ui.drawRectFilled(contentPos, contentPos + speedBoxSize, panelBgDark, 7 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)
  ui.drawRect(contentPos, contentPos + speedBoxSize, line, 7 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)
  ui.drawRectFilled(gearBoxPos, gearBoxPos + gearBoxSize, panelBgDark, 7 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)
  ui.drawRect(gearBoxPos, gearBoxPos + gearBoxSize, line, 7 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)

  local speedRectA = contentPos + vec2(6 * scale, 0)
  local speedRectB = vec2(contentPos.x + speedBoxSize.x * 0.66, contentPos.y + speedBoxSize.y)
  ui.dwriteDrawTextClipped(string.format('%03.0f', displaySpeed), 40 * scale, speedRectA, speedRectB,
    ui.Alignment.Right, ui.Alignment.Center, false, accent)

  local unitRectA = vec2(speedRectB.x + 4 * scale, contentPos.y)
  local unitRectB = contentPos + speedBoxSize - vec2(8 * scale, 0)
  ui.dwriteDrawTextClipped(speedUnit, 18 * scale, unitRectA, unitRectB,
    ui.Alignment.Right, ui.Alignment.Center, false, colors.label)

  ui.dwriteDrawTextClipped(self.gear, 42 * scale, gearBoxPos, gearBoxPos + gearBoxSize,
    ui.Alignment.Center, ui.Alignment.Center, false, gearAccent)

  local statsPos = panelPos + vec2(16, 84) * scale
  local statsSize = vec2(panelSize.x - 32 * scale, 20 * scale)
  local statAccent = colors.valueEdit
  local statBg = panelBgDark

  ui.drawRectFilled(statsPos, statsPos + statsSize, statBg, 6 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)
  ui.drawRect(statsPos, statsPos + statsSize, line, 6 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)

  local segmentWidth = statsSize.x / 3
  for i = 1, 2 do
    local dividerX = statsPos.x + segmentWidth * i
    ui.drawLine(vec2(dividerX, statsPos.y + 3 * scale), vec2(dividerX, statsPos.y + statsSize.y - 3 * scale), line, 1)
  end

  local stats = {
    { 'TC', self.tcMode > 0 and tostring(self.tcMode) or 'Off' },
    { 'ABS', self.absMode > 0 and tostring(self.absMode) or 'Off' },
    { 'BB', string.format('%.2f%%', self.brakeBias) },
  }

  for i = 1, 3 do
    local sectionA = statsPos + vec2(segmentWidth * (i - 1), 0)
    local sectionB = sectionA + vec2(segmentWidth, statsSize.y)
    local midX = sectionA.x + segmentWidth * 0.5

    ui.dwriteDrawTextClipped(stats[i][1], 11 * scale,
      sectionA + vec2(6 * scale, 0), vec2(midX - 3 * scale, sectionB.y),
      ui.Alignment.Start, ui.Alignment.Center, false, colors.label)

    ui.dwriteDrawTextClipped(stats[i][2], 12 * scale,
      vec2(midX, sectionA.y), sectionB - vec2(6 * scale, 0),
      ui.Alignment.End, ui.Alignment.Center, false, statAccent)
  end

  ui.dummy(panelSize)
  ui.popStyleVar()
  ui.popDWriteFont()
end

return SpeedWidget
