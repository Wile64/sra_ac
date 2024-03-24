--
-- Created by Wile64 on december 2023
--
VERSION = 1.102

require('classes/settings')
local config = Settings()
local sf = string.format

local function getColor(value)
  value = math.min(math.max(value, 0), 100)
  value = value / 100
  value = math.min(math.max(value, 0), 1)
  local r, g, b

  if value < 0.5 then
    r = value * 3
    g = 1 - value
    b = 0
  else
    r = 1
    g = 1 - value
    b = 0
  end
  return rgbm(r, g, b, 0.5)
end

function script.windowMain(dt)
  ac.setWindowTitle('windowMain', string.format('SRA Damage v%2.3f', VERSION))
  ui.pushDWriteFont('OneSlot:\\fonts\\.')
  local carState = ac.getCar(ac.getSim().focusedCar)
  if carState == nil then return end
  local imageSize = vec2(100, 320) * config.scale
  local imageStart = ui.getCursor()
  local fontSize = 16 * config.scale
  local tyreColor = rgbm.colors.gray
  local adjustY = fontSize / 2

  local engineLifeLeft = carState.engineLifeLeft > 0 and (1 - carState.engineLifeLeft / 1000) * 100 or 100
  local gearboxDamage = carState.gearboxDamage < 1 and carState.gearboxDamage * 100 or 100
  local frontDamage = carState.damage[0] <= 100 and carState.damage[0] or 100
  local rearDamage = carState.damage[1] <= 100 and carState.damage[1] or 100
  local leftDamage = carState.damage[2] <= 100 and carState.damage[2] or 100
  local rightDamage = carState.damage[3] <= 100 and carState.damage[3] or 100
  local suspensionFL = carState.wheels[0].suspensionDamage
  local suspensionFR = carState.wheels[1].suspensionDamage
  local suspensionRL = carState.wheels[2].suspensionDamage
  local suspensionRR = carState.wheels[3].suspensionDamage

  ui.drawImage('damage\\engine.png', imageStart, imageSize, getColor(engineLifeLeft))

  ui.drawImage('damage\\gearbox.png', imageStart, imageSize, getColor(gearboxDamage))

  ui.drawImage('damage\\front.png', imageStart, imageSize, getColor(frontDamage))
  ui.drawImage('damage\\rear.png', imageStart, imageSize, getColor(rearDamage))

  ui.drawImage('damage\\left.png', imageStart, imageSize, getColor(leftDamage))
  ui.drawImage('damage\\sus_fl.png', imageStart, imageSize, getColor(suspensionFL))
  ui.drawImage('damage\\tyre_fl.png', imageStart, imageSize, tyreColor)

  ui.drawImage('damage\\sus_rl.png', imageStart, imageSize, getColor(suspensionRL))
  ui.drawImage('damage\\tyre_rl.png', imageStart, imageSize, tyreColor)

  ui.drawImage('damage\\right.png', imageStart, imageSize, getColor(rightDamage))
  ui.drawImage('damage\\sus_fr.png', imageStart, imageSize, getColor(suspensionFR))
  ui.drawImage('damage\\tyre_fr.png', imageStart, imageSize, tyreColor)

  ui.drawImage('damage\\sus_rr.png', imageStart, imageSize, getColor(suspensionRR))
  ui.drawImage('damage\\tyre_rr.png', imageStart, imageSize, tyreColor)

  ui.dwriteDrawText(sf("%0.0f%%", engineLifeLeft), fontSize,
    vec2(42, 78 - adjustY) * config.scale, config.textColor)  -- engine
  ui.dwriteDrawText(sf("%0.0f%%", gearboxDamage), fontSize,
    vec2(45, 120 - adjustY) * config.scale, config.textColor) -- gearbox

  ui.dwriteDrawText(sf("%0.0f%%", frontDamage), fontSize,
    vec2(47, 46 - adjustY) * config.scale, config.textColor)  --front
  ui.dwriteDrawText(sf("%0.0f%%", rearDamage), fontSize,
    vec2(42, 290 - adjustY) * config.scale, config.textColor) -- rear

  ui.dwriteDrawText(sf("%0.0f%%", rightDamage), fontSize,
    vec2(80, 170 - adjustY) * config.scale, config.textColor) -- right
  ui.dwriteDrawText(sf("%0.0f%%", leftDamage), fontSize,
    vec2(5, 170 - adjustY) * config.scale, config.textColor)   -- left
  ui.dummy(imageSize + 1)
  ui.popDWriteFont()
end

function script.windowSetting(dt)
  local newScale = ui.slider('##scaleSlider', config.scale, 1.0, 2.0, 'Scale: %1.1f%')
  if ui.itemEdited() then
    config.scale = newScale
  end

  if ui.colorButton(
        'textColor##',
        config.textColor,
        ui.ColorPickerFlags.NoAlpha + ui.ColorPickerFlags.PickerHueBar) then
    config.textColor = config.textColor
  end
  ui.sameLine()
  ui.text('Text  Color')

  ui.separator()
  ui.setCursorX(210)
  if ui.iconButton(ui.Icons.Save, vec2(50, 0), 0, true, ui.ButtonFlags.Activable) then
    config:save()
  end
end
