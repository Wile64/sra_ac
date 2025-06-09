--
-- Created by Wile64 on december 2023
--

local AppConfig = ac.storage {
  scale = 1,
  showRepair = true,
  showDamage = true,
  textColor = rgbm.colors.white,
  repairColor = rgbm.colors.red,
}


local sf = string.format
local appVisible = true
local carFocused = -1
local pitParams = {}

local function getPitParams()
  local carINI = ac.INIConfig.carData(carFocused, 'car.ini')
  pitParams = {
    tyreChangeTime = carINI:get("PIT_STOP", "TYRE_CHANGE_TIME_SEC", 0),       -- Temps pour changer tous les pneus
    bodyRepairTime = carINI:get("PIT_STOP", "BODY_REPAIR_TIME_SEC", 0),       -- Temps pour réparer 10% de la carrosserie
    engineRepairTime = carINI:get("PIT_STOP", "ENGINE_REPAIR_TIME_SEC", 0),   -- Temps pour réparer 10% du moteur
    suspensionRepairTime = carINI:get("PIT_STOP", "SUSP_REPAIR_TIME_SEC", 0), -- Temps pour réparer 10% de la suspension
  }
end

-- Fonction pour calculer le temps de réparation carrosserie selon les 4 zones
local function calculateBodyRepairTime(car, baseTime)
  local totalTime = 0
  local lowZones = {}
  local highZones = 0

  for i = 0, 3 do
    local d = car.damage[i] or 0
    if d > 0 then
      if d <= 3 then
        table.insert(lowZones, d)
      else
        totalTime = totalTime + math.max((d / 100) * baseTime, 3.0) + 1.0
        highZones = highZones + 1
      end
    end
  end

  local n = #lowZones
  if n > 0 then
    if n == 4 then
      totalTime = totalTime + 11
    else
      totalTime = totalTime + (3 * n)
    end
  end
  return totalTime
end

-- Calcule le temps pour réparer la suspension (moyenne des 4 roues)
local function calculateSuspensionTime(car, baseTime)
  local damage = 0
  for i = 0, 3 do
    damage = damage + (car.wheels[i].suspensionDamage or 0)
  end
  return damage * baseTime
end

-- Calcule le temps de réparation moteur basé sur la vie restante
local function calculateEngineTime(car, baseTime)
  local life = math.min(car.engineLifeLeft or 1000, 1000)
  local damage = 1 - life / 1000
  return damage * 100 * baseTime
end

--- Retour une couleur entre vert = 0 et rouge = 1
---@param value number -- Valeur doit etre entre 0 et 1
---@return rgbm
local function getColor(value)
  if value < 0 then
    value = 0
  elseif value > 1 then
    value = 1
  end
  local r = (value < 0.5) and (value * 3) or 1
  local g = 1 - value
  return rgbm(r, g, 0.3, 0.5)
end

---comment
---@param text string
---@param fontSize number
---@param pos vec2
---@param horizontalAligment ui.Alignment
---@param color rgbm
function DrawTextAt(text, fontSize, pos, horizontalAligment, color)
  local textSize = ui.measureDWriteText(text, fontSize)
  local offX = 0
  if horizontalAligment == ui.Alignment.Center then
    offX = textSize.x * 0.5
  end
  if horizontalAligment == ui.Alignment.End then
    offX = textSize.x
  end
  pos = pos - vec2(offX, 0)
  ui.drawRectFilled(pos, pos + textSize, rgbm(0.1, 0.1, 0.1, 0.7))
  ui.dwriteDrawText(text, fontSize, pos, color)
end

local function getScale(x, y)
  return vec2(x, y) * AppConfig.scale
end

function script.windowMain(dt)
  if carFocused ~= ac.getSim().focusedCar then
    carFocused = ac.getSim().focusedCar
    getPitParams()
  end

  local carState = ac.getCar(carFocused)
  if carState == nil then return end

  ui.pushDWriteFont('OneSlot:/fonts')
  local imageStart = ui.getCursor()
  local imageSize = getScale(140, 289)
  local middleX = 140 * 0.5
  local fontSize = 18 * AppConfig.scale
  local blownColor = rgbm(0.1, 0.1, 0.1, 0.6)

  local engineRepairTime = calculateEngineTime(carState, pitParams.engineRepairTime)
  local suspensionRepairTime = calculateSuspensionTime(carState, pitParams.suspensionRepairTime)
  local bodyRepairTime = calculateBodyRepairTime(carState, pitParams.bodyRepairTime)

  local engineLifeLeft = 1 - (carState.engineLifeLeft / 1000)
  local gearboxDamage = carState.gearboxDamage

  local frontDamage = carState.damage[0] / 100
  local rearDamage = carState.damage[1] / 100
  local leftDamage = carState.damage[2] / 100
  local rightDamage = carState.damage[3] / 100

  local suspensionFL = carState.wheels[0].suspensionDamage
  local suspensionFR = carState.wheels[1].suspensionDamage
  local suspensionRL = carState.wheels[2].suspensionDamage
  local suspensionRR = carState.wheels[3].suspensionDamage

  local tyreFL = carState.wheels[0].tyreFlatSpot
  local tyreFR = carState.wheels[1].tyreFlatSpot
  local tyreRL = carState.wheels[2].tyreFlatSpot
  local tyreRR = carState.wheels[3].tyreFlatSpot

  local tyreWearFL = carState.wheels[0].tyreWear
  local tyreWearFR = carState.wheels[1].tyreWear
  local tyreWearRL = carState.wheels[2].tyreWear
  local tyreWearRR = carState.wheels[3].tyreWear

  ui.drawImage('damage\\engine.png', imageStart, imageSize, getColor(engineLifeLeft))
  ui.drawImage('damage\\gearbox.png', imageStart, imageSize, getColor(gearboxDamage))
  ui.drawImage('damage\\rear_axle.png', imageStart, imageSize, rgbm.colors.gray)

  ui.drawImage('damage\\front.png', imageStart, imageSize, getColor(frontDamage))
  ui.drawImage('damage\\rear.png', imageStart, imageSize, getColor(rearDamage))
  ui.drawImage('damage\\left.png', imageStart, imageSize, getColor(leftDamage))
  ui.drawImage('damage\\right.png', imageStart, imageSize, getColor(rightDamage))

  ui.drawImage('damage\\sus_fl.png', imageStart, imageSize, getColor(suspensionFL))
  ui.drawImage('damage\\sus_rl.png', imageStart, imageSize, getColor(suspensionRL))
  ui.drawImage('damage\\sus_fr.png', imageStart, imageSize, getColor(suspensionFR))
  ui.drawImage('damage\\sus_rr.png', imageStart, imageSize, getColor(suspensionRR))
  if carState.wheels[0].isBlown then
    ui.drawImage('damage\\tyre_fl.png', imageStart, imageSize, blownColor)
  else
    ui.drawImage('damage\\tyre_fl.png', imageStart, imageSize, getColor(tyreWearFL))
  end
  if carState.wheels[1].isBlown then
    ui.drawImage('damage\\tyre_fl.png', imageStart, imageSize, blownColor)
  else
    ui.drawImage('damage\\tyre_rl.png', imageStart, imageSize, getColor(tyreWearRL))
  end
  if carState.wheels[2].isBlown then
    ui.drawImage('damage\\tyre_fl.png', imageStart, imageSize, blownColor)
  else
    ui.drawImage('damage\\tyre_fr.png', imageStart, imageSize, getColor(tyreWearFR))
  end
  if carState.wheels[3].isBlown then
    ui.drawImage('damage\\tyre_fl.png', imageStart, imageSize, blownColor)
  else
    ui.drawImage('damage\\tyre_rr.png', imageStart, imageSize, getColor(tyreWearRR))
  end

  if AppConfig.showDamage then
    DrawTextAt(sf("%.0f%%", engineLifeLeft * 100), fontSize, imageStart + getScale(middleX, 70), ui.Alignment.Center,
      AppConfig.textColor)
    DrawTextAt(sf("%.0f%%", gearboxDamage * 100), fontSize, imageStart + getScale(middleX, 110), ui.Alignment.Center,
      AppConfig.textColor)

    DrawTextAt(sf("%.0f%%", frontDamage * 100), fontSize, imageStart + getScale(middleX, 0), ui.Alignment.Center,
      AppConfig.textColor)
    DrawTextAt(sf("%.0f%%", rearDamage * 100), fontSize, imageStart + getScale(middleX, 245), ui.Alignment.Center,
      AppConfig.textColor)
    DrawTextAt(sf("%.0f%%", rightDamage * 100), fontSize, imageStart + getScale(140, 130), ui.Alignment.End,
      AppConfig.textColor)
    DrawTextAt(sf("%.0f%%", leftDamage * 100), fontSize, imageStart + getScale(0, 130), ui.Alignment.Start,
      AppConfig.textColor)
  end

  if AppConfig.showRepair then
    DrawTextAt(sf("Body %.0fs", bodyRepairTime), fontSize, imageStart + getScale(middleX, 150), ui.Alignment.Center,
      AppConfig
      .repairColor)
    DrawTextAt(sf("Eng %.0fs", engineRepairTime), fontSize, imageStart + getScale(middleX, 40), ui.Alignment.Center,
      AppConfig
      .repairColor)
    DrawTextAt(sf("Sus %.0fs", suspensionRepairTime), fontSize, imageStart + getScale(middleX, 200), ui.Alignment.Center,
      AppConfig.repairColor)
  end

  ui.popDWriteFont()
  ui.dummy(imageSize - vec2(0, 22))
end

local function colorButtonEX(label, color)
  local originalColor = color:clone()
  ui.colorButton(label, color, ui.ColorPickerFlags.PickerHueBar)
  ui.sameLine()
  ui.text(label)
  return originalColor:vec4():distance(color:vec4()) > 0
end

function script.windowSetting(dt)
  AppConfig.scale = ui.slider('##scaleSlider', AppConfig.scale, 1.0, 2.0, 'Scale: %1.1f%')

  if ui.checkbox("Show repairs", AppConfig.showRepair) then
    AppConfig.showRepair = not AppConfig.showRepair
  end
  if ui.checkbox("Show Damages", AppConfig.showDamage) then
    AppConfig.showDamage = not AppConfig.showDamage
  end
  if colorButtonEX('Text color', AppConfig.textColor) then
    AppConfig.textColor = AppConfig.textColor
  end
  if colorButtonEX('Repair color', AppConfig.repairColor) then
    AppConfig.repairColor = AppConfig.repairColor
  end
end

function script.onShowWindowMain() appVisible = true end

function script.onHideWindowMain() appVisible = false end
