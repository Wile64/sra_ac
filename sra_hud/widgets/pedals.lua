local PedalsWidget = {}
PedalsWidget.__index = PedalsWidget

local function clamp01(value)
  if value < 0 then return 0 end
  if value > 1 then return 1 end
  return value
end

local function drawPedalBar(label, value, pos, size, fillColor, font, colors, scale)
  local bg = colors.backgroundAlt or colors.background
  local innerTop = pos.y + 6 * scale
  local innerBottom = pos.y + size.y - 8 * scale
  local fillLeft = pos.x + 6 * scale
  local fillRight = pos.x + size.x - 6 * scale
  local fillHeight = (innerBottom - innerTop) * clamp01(value)
  local fillTop = innerBottom - fillHeight
  local fillBottom = innerBottom

  ui.drawRectFilled(pos, pos + size, colors.background, 7 * scale)
  ui.drawRect(pos, pos + size, colors.border, 7 * scale)
  ui.drawRectFilled(vec2(fillLeft, innerTop), vec2(fillRight, innerBottom), bg, 4 * scale)
  if fillHeight > 0 then
    ui.drawRectFilled(vec2(fillLeft, fillTop), vec2(fillRight, fillBottom), fillColor, 4 * scale)
  end

  ui.dwriteDrawTextClipped(label, font.size * 0.74 * scale,
    pos + vec2(0, size.y - 18 * scale), pos + vec2(size.x, size.y),
    ui.Alignment.Center, ui.Alignment.Center, false, colors.label)
end

function PedalsWidget:new()
  return setmetatable({
    id = 'pedals',
    title = 'Pedals',
    windowId = 'windowPedals',
    clutch = 0,
    brake = 0,
    gas = 0,
  }, self)
end

function PedalsWidget:update(dt, context)
  local car = context.car
  self.clutch = car and (1 - (car.clutch or 0)) or 0
  self.brake = car and (car.brake or 0) or 0
  self.gas = car and (car.gas or 0) or 0
end

function PedalsWidget:draw(dt, drawContext)
  local scale = (drawContext.scale or 1) * (drawContext.pedalsScale or 1)
  local colors = drawContext.colors
  local pedals = drawContext.style.pedals
  local font = drawContext.font
  local panelSize = vec2(102, 120) * scale
  local barGap = 5 * scale
  local barWidth = (panelSize.x - barGap * 2) / 3
  local barSize = vec2(barWidth, panelSize.y)
  local start = ui.getCursor()

  ui.pushDWriteFont(font.police)
  if drawContext.pedalsShowClutch ~= false then
    drawPedalBar('CL', self.clutch, start, barSize, pedals.clutch, font, colors, scale)
  end
  if drawContext.pedalsShowBrake ~= false then
    drawPedalBar('BR', self.brake, start + vec2(barWidth + barGap, 0), barSize, pedals.brake, font, colors,
      scale)
  end
  if drawContext.pedalsShowThrottle ~= false then
    drawPedalBar('TH', self.gas, start + vec2((barWidth + barGap) * 2, 0), barSize, pedals.throttle, font,
      colors, scale)
  end
  ui.popDWriteFont()

  ui.dummy(panelSize)
end

return PedalsWidget
