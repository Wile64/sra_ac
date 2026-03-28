local GForceWidget = {}
GForceWidget.__index = GForceWidget

local function clamp(x, mn, mx)
  if x < mn then return mn end
  if x > mx then return mx end
  return x
end

local function readGForces(car)
  local acc = car and car.acceleration
  if acc then
    local lat = (acc.x or 0) / 9.81
    local lon = -((acc.z or acc.y) or 0) / 9.81
    return lat, lon
  end
  return 0, 0
end

function GForceWidget:new()
  return setmetatable({
    id = 'gforce',
    title = 'GForce',
    windowId = 'windowGForce',
    latG = 0,
    lonG = 0,
  }, self)
end

function GForceWidget:update(dt, context)
  local car = context.car
  local latG, lonG = readGForces(car)
  self.latG = clamp(latG * 3.5, -2.5, 2.5)
  self.lonG = clamp(lonG * 3.5, -2.5, 2.5)
end

function GForceWidget:draw(dt, drawContext)
  local scale = (drawContext.scale or 1) * (drawContext.gforceScale or 1)
  local colors = drawContext.colors
  local gforceColors = drawContext.style.gforce

  local panelPos = ui.getCursor()
  local panelSize = vec2(180, 180) * scale
  local center = panelPos + panelSize * 0.5
  local radius = math.min(panelSize.x, panelSize.y) * 0.38
  local maxG = 1.5

  ui.drawCircleFilled(center, radius, colors.background, 36 * scale)
  ui.drawCircle(center, radius, colors.border, 36, 1 * scale)
  ui.drawCircle(center, radius * 0.66, rgbm(colors.border.r, colors.border.g, colors.border.b, 0.6), 36, 1 * scale)
  ui.drawCircle(center, radius * 0.33, rgbm(colors.border.r, colors.border.g, colors.border.b, 0.45), 36, 1 * scale)
  ui.drawLine(vec2(center.x - radius, center.y), vec2(center.x + radius, center.y), colors.border, 1 * scale)
  ui.drawLine(vec2(center.x, center.y - radius), vec2(center.x, center.y + radius), colors.border, 1 * scale)

  local nx = self.latG / maxG
  local ny = self.lonG / maxG
  local nlen = math.sqrt(nx * nx + ny * ny)
  if nlen > 1 then
    nx = nx / nlen
    ny = ny / nlen
  end

  local out = math.min(1, math.sqrt(nlen))
  if nlen > 1e-4 then
    nx = nx * out
    ny = ny * out
  end

  local dot = vec2(center.x + nx * radius, center.y - ny * radius)
  ui.drawCircleFilled(dot, 5 * scale, gforceColors.dot, 20)
  ui.drawCircle(dot, 6 * scale, colors.border, 20, 1 * scale)

  ui.dummy(panelSize)
end

return GForceWidget
