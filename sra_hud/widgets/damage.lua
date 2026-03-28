local DamageWidget = {}
DamageWidget.__index = DamageWidget

local BASE_DAMAGE_HUD_SCALE = 0.60
local DAMAGE_IMAGE_PATH = 'img\\'
local DAMAGE_FONT = 'OneSlot:/fonts;Weight=Bold'

local function getColor(value, style)
  value = math.clamp(value or 0, 0, 1)
  local cold = style.damage.ok
  local hot = style.damage.bad
  local t = math.max(0, math.min(1, value))
  return rgbm(
    cold.r + (hot.r - cold.r) * t,
    cold.g + (hot.g - cold.g) * t,
    cold.b + (hot.b - cold.b) * t,
    0.55
  )
end

local function calculateBodyRepairTime(car, baseTime)
  local totalTime = 0
  local lightDamageCount = 0

  for i = 0, 3 do
    local damage = car.damage[i] or 0
    if damage > 0 then
      if damage <= 3 then
        lightDamageCount = lightDamageCount + 1
      else
        totalTime = totalTime + math.max((damage / 100) * baseTime, 3.0) + 1.0
      end
    end
  end

  if lightDamageCount > 0 then
    totalTime = totalTime + (lightDamageCount == 4 and 11 or 3 * lightDamageCount)
  end

  return totalTime
end

local function calculateSuspensionRepairTime(car, baseTime)
  local totalDamage = 0
  for i = 0, 3 do
    local wheel = car.wheels[i]
    totalDamage = totalDamage + ((wheel and wheel.suspensionDamage) or 0)
  end
  return totalDamage * baseTime
end

local function calculateEngineRepairTime(car, baseTime)
  local engineLife = math.min(car.engineLifeLeft or 1000, 1000)
  local damageRatio = 1 - (engineLife / 1000)
  return damageRatio * 100 * baseTime
end

local function drawTextLabel(text, size, pos, align, color, scale, colors)
  local textSize = ui.measureDWriteText(text, size)
  local offsetX = (align == ui.Alignment.Center and textSize.x * 0.5)
      or (align == ui.Alignment.End and textSize.x)
      or 0
  local a = pos - vec2(offsetX, 0)
  local b = a + textSize + vec2(6, 2) * scale
  ui.drawRectFilled(a - vec2(3, 1) * scale, b, colors.backgroundAlt, 3 * scale)
  ui.dwriteDrawText(text, size, a, color)
end

local function scaledVec(scale, x, y)
  return vec2(x, y) * scale
end

function DamageWidget:new()
  return setmetatable({
    id = 'damage',
    title = 'Damage',
    windowId = 'windowDamage',
    focusedCarID = -1,
    car = nil,
    pitRepairTimes = {
      tyre = 0,
      body = 0,
      engine = 0,
      suspension = 0,
    },
  }, self)
end

function DamageWidget:loadPitRepairTimes()
  local carINI = ac.INIConfig.carData(self.focusedCarID, 'car.ini')
  if not carINI then
    self.pitRepairTimes = { tyre = 0, body = 0, engine = 0, suspension = 0 }
    return
  end

  self.pitRepairTimes = {
    tyre = carINI:get('PIT_STOP', 'TYRE_CHANGE_TIME_SEC', 0),
    body = carINI:get('PIT_STOP', 'BODY_REPAIR_TIME_SEC', 0),
    engine = carINI:get('PIT_STOP', 'ENGINE_REPAIR_TIME_SEC', 0),
    suspension = carINI:get('PIT_STOP', 'SUSP_REPAIR_TIME_SEC', 0),
  }
end

function DamageWidget:update(dt, context)
  local sim = context.sim
  if not sim then
    self.car = nil
    return
  end

  local focusedCarID = sim.focusedCar or 0
  if self.focusedCarID ~= focusedCarID then
    self.focusedCarID = focusedCarID
    self:loadPitRepairTimes()
  end

  self.car = ac.getCar(self.focusedCarID)
end

function DamageWidget:draw(dt, drawContext)
  local car = self.car
  if not car then
    return
  end

  local scale = (drawContext.scale or 1) * (drawContext.damageScale or 1) * BASE_DAMAGE_HUD_SCALE
  local style = drawContext.style
  local colors = drawContext.colors
  local showRepair = drawContext.damageShowRepair ~= false
  local showDamage = drawContext.damageShowDamage ~= false

  local posStart = ui.getCursor()
  local imageSize = scaledVec(scale, 140, 289)
  local fontSize = 20 * scale
  local blownColor = style.damage.blown
  local repairColor = style.damage.repair
  local fontColor = colors.valueNeutral

  local engineRepair = calculateEngineRepairTime(car, self.pitRepairTimes.engine)
  local suspensionRepair = calculateSuspensionRepairTime(car, self.pitRepairTimes.suspension)
  local bodyRepair = calculateBodyRepairTime(car, self.pitRepairTimes.body)
  local engineDamageRatio = 1 - ((car.engineLifeLeft or 1000) / 1000)

  local damageImages = {
    { name = 'engine', value = engineDamageRatio },
    { name = 'gearbox', value = car.gearboxDamage or 0 },
    { name = 'rear_axle', value = 0 },
    { name = 'front', value = (car.damage[0] or 0) / 100 },
    { name = 'rear', value = (car.damage[1] or 0) / 100 },
    { name = 'dleft', value = (car.damage[2] or 0) / 100 },
    { name = 'dright', value = (car.damage[3] or 0) / 100 },
    { name = 'sus_fl', value = (car.wheels[0] and car.wheels[0].suspensionDamage) or 0 },
    { name = 'sus_fr', value = (car.wheels[1] and car.wheels[1].suspensionDamage) or 0 },
    { name = 'sus_rl', value = (car.wheels[2] and car.wheels[2].suspensionDamage) or 0 },
    { name = 'sus_rr', value = (car.wheels[3] and car.wheels[3].suspensionDamage) or 0 },
  }

  ui.pushDWriteFont(DAMAGE_FONT)
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(0, 0))

  for i = 1, #damageImages do
    local img = damageImages[i]
    ui.drawImage(DAMAGE_IMAGE_PATH .. img.name .. '.png', posStart, posStart + imageSize, getColor(img.value, style))
  end

  local tyreNames = { 'tyre_fl', 'tyre_fr', 'tyre_rl', 'tyre_rr' }
  for i = 0, 3 do
    local wheel = car.wheels[i]
    if wheel then
      local wearColor = getColor(wheel.tyreWear or 0, style)
      local color = wheel.isBlown and blownColor or wearColor
      ui.drawImage(DAMAGE_IMAGE_PATH .. tyreNames[i + 1] .. '.png', posStart, posStart + imageSize, color)
    end
  end

  if showDamage then
    drawTextLabel(string.format('%.0f%%', engineDamageRatio * 100), fontSize, posStart + scaledVec(scale, 70, 70),
      ui.Alignment.Center, fontColor, scale, colors)
    drawTextLabel(string.format('%.0f%%', (car.gearboxDamage or 0) * 100), fontSize, posStart + scaledVec(scale, 70, 110),
      ui.Alignment.Center, fontColor, scale, colors)
    drawTextLabel(string.format('%.0f%%', car.damage[0] or 0), fontSize, posStart + scaledVec(scale, 70, 0),
      ui.Alignment.Center, fontColor, scale, colors)
    drawTextLabel(string.format('%.0f%%', car.damage[1] or 0), fontSize, posStart + scaledVec(scale, 70, 260),
      ui.Alignment.Center, fontColor, scale, colors)
    drawTextLabel(string.format('%.0f%%', car.damage[3] or 0), fontSize, posStart + scaledVec(scale, 135, 130),
      ui.Alignment.End, fontColor, scale, colors)
    drawTextLabel(string.format('%.0f%%', car.damage[2] or 0), fontSize, posStart + scaledVec(scale, 0, 130),
      ui.Alignment.Start, fontColor, scale, colors)
  end

  if showRepair then
    drawTextLabel(string.format('Body %.0fs', bodyRepair), fontSize, posStart + scaledVec(scale, 70, 160),
      ui.Alignment.Center, repairColor, scale, colors)
    drawTextLabel(string.format('Eng %.0fs', engineRepair), fontSize, posStart + scaledVec(scale, 70, 40),
      ui.Alignment.Center, repairColor, scale, colors)
    drawTextLabel(string.format('Sus %.0fs', suspensionRepair), fontSize, posStart + scaledVec(scale, 70, 200),
      ui.Alignment.Center, repairColor, scale, colors)
  end

  ui.dummy(imageSize)
  ui.popStyleVar()
  ui.popDWriteFont()
end

return DamageWidget
