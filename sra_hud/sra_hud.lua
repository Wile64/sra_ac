--
-- Created by Wile64 on october 2023
--

require('classes/carsra')
require('views/chronohud')
require('views/timehud')
require('views/ledhud')
require('views/poshud')
require('views/sectorhud')
require('views/weatherhud')
require('views/racehud')
require('views/speedhud')
require('classes/settings')

CAR = CarSRA()
SETTING = Settings()

local function tabChrono()
  if ui.checkbox('Show Delta', SETTING.chronoHUD.showDelta) then
    SETTING.chronoHUD.showDelta = not SETTING.chronoHUD.showDelta
  end
  if ui.checkbox('Show Current', SETTING.chronoHUD.showCurrent) then
    SETTING.chronoHUD.showCurrent = not SETTING.chronoHUD.showCurrent
  end
  if ui.checkbox('Show Estimated', SETTING.chronoHUD.showEstimated) then
    SETTING.chronoHUD.showEstimated = not SETTING.chronoHUD.showEstimated
  end
  if ui.checkbox('Show Previous', SETTING.chronoHUD.showPrevious) then
    SETTING.chronoHUD.showPrevious = not SETTING.chronoHUD.showPrevious
  end
  if ui.checkbox('Show Best Session', SETTING.chronoHUD.showBest) then
    SETTING.chronoHUD.showBest = not SETTING.chronoHUD.showBest
  end
  if ui.checkbox('Show Personal Best', SETTING.chronoHUD.showPersonal) then
    SETTING.chronoHUD.showPersonal = not SETTING.chronoHUD.showPersonal
  end
end
local function tabWeather()
  if ui.checkbox('Show Ambient Temperature', SETTING.weatherHUD.showAmbientTemp) then
    SETTING.weatherHUD.showAmbientTemp = not SETTING.weatherHUD.showAmbientTemp
  end
  if ui.checkbox('Show Road Temperature', SETTING.weatherHUD.showRoadTemp) then
    SETTING.weatherHUD.showRoadTemp = not SETTING.weatherHUD.showRoadTemp
  end
  if ui.checkbox('Show Wind Speed', SETTING.weatherHUD.showWindSpeed) then
    SETTING.weatherHUD.showWindSpeed = not SETTING.weatherHUD.showWindSpeed
  end
end

local function tabRace()
  if ui.checkbox('Show Road Grip', SETTING.raceHUD.showRoadGrip) then
    SETTING.raceHUD.showRoadGrip = not SETTING.raceHUD.showRoadGrip
  end
  if ui.checkbox('Show Fuel Rate', SETTING.raceHUD.showFuelRate) then
    SETTING.raceHUD.showFuelRate = not SETTING.raceHUD.showFuelRate
  end
  if ui.checkbox('Show Damage Rate', SETTING.raceHUD.showDamageRate) then
    SETTING.raceHUD.showDamageRate = not SETTING.raceHUD.showDamageRate
  end
  if ui.checkbox('Show Tyre Rate', SETTING.raceHUD.showTyreRate) then
    SETTING.raceHUD.showTyreRate = not SETTING.raceHUD.showTyreRate
  end
end

local function tabPosition()
  if ui.checkbox('Show Session', SETTING.positionHUD.showSession) then
    SETTING.positionHUD.showSession = not SETTING.positionHUD.showSession
  end
  if ui.checkbox('Show Position', SETTING.positionHUD.showPosition) then
    SETTING.positionHUD.showPosition = not SETTING.positionHUD.showPosition
  end
  if ui.checkbox('Show Lap Count', SETTING.positionHUD.showLapCount) then
    SETTING.positionHUD.showLapCount = not SETTING.positionHUD.showLapCount
  end
  if ui.checkbox('Show Session Timer', SETTING.positionHUD.showSessionTimer) then
    SETTING.positionHUD.showSessionTimer = not SETTING.positionHUD.showSessionTimer
  end
  if ui.checkbox('Show Flag', SETTING.positionHUD.showFlag) then
    SETTING.positionHUD.showFlag = not SETTING.positionHUD.showFlag
  end
end

local function tabLed()
  SETTING.ledHUD.scale = ui.slider('##Scale', SETTING.ledHUD.scale, 1.0, 3.0, 'Scale: %1.1f')

  if ui.checkbox('Show DRS', SETTING.ledHUD.showDRS) then
    SETTING.ledHUD.showDRS = not SETTING.ledHUD.showDRS
  end
  if ui.checkbox('Show TC', SETTING.ledHUD.showTC) then
    SETTING.ledHUD.showTC = not SETTING.ledHUD.showTC
  end
  if ui.checkbox('Show ABS', SETTING.ledHUD.showABS) then
    SETTING.ledHUD.showABS = not SETTING.ledHUD.showABS
  end
  if ui.checkbox('Show Speed Limiter', SETTING.ledHUD.showSpeedLimiter) then
    SETTING.ledHUD.showSpeedLimiter = not SETTING.ledHUD.showSpeedLimiter
  end
  if ui.checkbox('Show Light', SETTING.ledHUD.showLight) then
    SETTING.ledHUD.showLight = not SETTING.ledHUD.showLight
  end
  if ui.checkbox('Show Flashing Light', SETTING.ledHUD.showFlashingLight) then
    SETTING.ledHUD.showFlashingLight = not SETTING.ledHUD.showFlashingLight
  end
  if ui.checkbox('Show Hazard', SETTING.ledHUD.showHazard) then
    SETTING.ledHUD.showHazard = not SETTING.ledHUD.showHazard
  end
  if ui.checkbox('Show Turning Light', SETTING.ledHUD.showTurningLight) then
    SETTING.ledHUD.showTurningLight = not SETTING.ledHUD.showTurningLight
  end
end

local function tabSector()
  SETTING.sectorHUD.scale = ui.slider('##Scale', SETTING.sectorHUD.scale, 1.0, 3.0, 'Scale: %1.1f')

  if ui.checkbox('Show current sector', SETTING.sectorHUD.showCurrent) then
    SETTING.sectorHUD.showCurrent = not SETTING.sectorHUD.showCurrent
  end
  if ui.checkbox('Show last sector', SETTING.sectorHUD.showLast) then
    SETTING.sectorHUD.showLast = not SETTING.sectorHUD.showLast
  end
  if ui.checkbox('Show best sector', SETTING.sectorHUD.showBest) then
    SETTING.sectorHUD.showBest = not SETTING.sectorHUD.showBest
  end
end

local function tabGeneral()
  SETTING.scale = ui.slider('##Scale', SETTING.scale, 1.0, 3.0, 'Scale: %1.1f')

  if ui.colorButton('##StyleColor', SETTING.styleColor, ui.ColorPickerFlags.AlphaBar + ui.ColorPickerFlags.PickerHueBar) then
    SETTING.styleColor = SETTING.styleColor
  end
  ui.sameLine()
  ui.text('Style Color')

  if ui.colorButton('backgroundColor##', SETTING.fontColor, ui.ColorPickerFlags.NoAlpha + ui.ColorPickerFlags.PickerHueBar) then
    SETTING.fontColor = SETTING.fontColor
  end
  ui.sameLine()
  ui.text('Font Color')
end

function script.windowSetup(dt)
  ui.tabBar('someTabBarID', function()
    ui.tabItem('HUD', tabGeneral)
    ui.tabItem('Chrono HUD', tabChrono)
    ui.tabItem('Weather HUD', tabWeather)
    ui.tabItem('Race HUD', tabRace)
    ui.tabItem('Position HUD', tabPosition)
    ui.tabItem('Led HUD', tabLed)
    ui.tabItem('Sector HUD', tabSector)
  end)

  ui.separator()
  ui.setCursorX(210)
  if ui.iconButton(ui.Icons.Save, vec2(50, 0), 0, true, ui.ButtonFlags.Activable) then
    SETTING:save()
  end
end

function script.update(dt)
  CAR:setFocusedCar()
  CAR:update(dt)
end
