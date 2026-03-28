VERSION = "1.0.0"

if ac.getPatchVersionCode() < 3116 then
  local function showVersionError(dt)
    ui.text('CSP v0.2.4 or above is required.')
  end

  script.update = function(dt)
  end

  script.windowMain = showVersionError
  script.windowSpeed = showVersionError
  script.windowChrono = showVersionError
  script.windowPosition = showVersionError
  script.windowFuel = showVersionError
  script.windowTime = showVersionError
  script.windowGForce = showVersionError
  script.windowSector = showVersionError
  script.windowDamage = showVersionError
  script.windowLed = showVersionError
  script.windowDelta = showVersionError
  script.windowLeaderboard = showVersionError
  script.windowPanel = showVersionError
  script.windowRadar = showVersionError
  return
end

local panelPrevControl = ac.ControlButton('sra_hud/Previous Page')
local panelNextControl = ac.ControlButton('sra_hud/Next Page')
local panelUpControl = ac.ControlButton('sra_hud/Previous Row')
local panelDownControl = ac.ControlButton('sra_hud/Next Row')
local panelMinusControl = ac.ControlButton('sra_hud/Decrease Value')
local panelPlusControl = ac.ControlButton('sra_hud/Increase Value')

local appConfig = ac.storage({
  theme = 'default',
  scale = 1,
  fuelUseGallons = false,
  speedUseMph = false,
  speedScale = 1.0,
  chronoScale = 1.0,
  positionScale = 1.0,
  fuelScale = 1.0,
  timeScale = 1.0,
  gforceScale = 1.0,
  sectorScale = 1.0,
  damageScale = 1.0,
  ledScale = 1.0,
  pedalsScale = 1.0,
  weatherUseFahrenheit = false,
  chronoShowDelta = true,
  chronoShowCurrent = true,
  chronoShowPrevious = true,
  chronoShowBest = true,
  fuelShowBar = true,
  fuelShowPerLap = true,
  fuelShowLaps = true,
  fuelShowTimeLeft = true,
  sectorShowCurrent = true,
  sectorShowLast = true,
  sectorShowBest = true,
  damageShowRepair = true,
  damageShowDamage = true,
  ledShowDRS = true,
  ledShowTC = true,
  ledShowABS = true,
  ledShowSpeedLimiter = true,
  ledShowLight = true,
  ledShowFlashingLight = true,
  ledShowHazard = true,
  ledShowTurningLight = true,
  pedalsShowClutch = true,
  pedalsShowBrake = true,
  pedalsShowThrottle = true,
  deltaShowRefLap = true,
  deltaShowDeltaBar = true,
  deltaShowSectorBar = true,
  deltaScale = 1.0,
  deltaSectorThresholdMs = 30,
  leaderboardRows = 7,
  leaderboardScale = 1.0,
  leaderboardMode = 2,
  leaderboardShowPositionChange = true,
  leaderboardShowLap = true,
  leaderboardShowCompoundColumn = true,
  leaderboardShowNationFlag = true,
  leaderboardShowCarLogo = true,
  panelScale = 1.0,
  panelPage = 1,
  panelTestPage = 1,
  quickChat1 = 'Sorry',
  quickChat2 = 'Thank you',
  quickChat3 = 'My bad',
  quickChat4 = 'Good race',
  quickChat5 = 'Pitting this lap',
  quickChat6 = 'Go ahead',
})

local SpeedWidget = require('widgets.speed')
local ChronoWidget = require('widgets.chrono')
local PositionWidget = require('widgets.position')
local FuelWidget = require('widgets.fuel')
local TimeWidget = require('widgets.time')
local GForceWidget = require('widgets.gforce')
local SectorWidget = require('widgets.sector')
local DamageWidget = require('widgets.damage')
local LedWidget = require('widgets.led')
local PedalsWidget = require('widgets.pedals')
local DeltaWidget = require('widgets.delta')
local LeaderboardWidget = require('widgets.leaderboard')
local PanelWidget = require('widgets.panel')
local RadarView = require('views.radar')
local WidgetManager = require('core.widget_manager')
local Style = require('core.style')

local widgetManager = WidgetManager:new()
local radarView = RadarView:new()
local themeNames = Style.getThemeNames()
local currentThemeName = nil
local theme = nil
widgetManager:register(SpeedWidget:new())
widgetManager:register(ChronoWidget:new())
widgetManager:register(PositionWidget:new())
widgetManager:register(FuelWidget:new())
widgetManager:register(TimeWidget:new())
widgetManager:register(GForceWidget:new())
widgetManager:register(SectorWidget:new())
widgetManager:register(DamageWidget:new())
widgetManager:register(LedWidget:new())
widgetManager:register(PedalsWidget:new())
widgetManager:register(DeltaWidget:new())
widgetManager:register(LeaderboardWidget:new())
widgetManager:register(PanelWidget:new(appConfig))

local SectionSetup = rgbm(0.96, 0.83, 0.52, 1.00)

local drawContext = {
  colors = nil,
  style = nil,
  font = {
    size = 15,
    police = "OneSlot:/fonts;Weight=Bold",
  }
}

local function refreshTheme()
  local nextThemeName = appConfig.theme or 'default'
  if nextThemeName ~= currentThemeName then
    Style.reset()
    theme = Style.getTheme(nextThemeName)
    currentThemeName = nextThemeName
    drawContext.colors = theme.colors
    drawContext.style = theme
  end
end

local function prepareDrawContext()
  refreshTheme()
  drawContext.scale = appConfig.scale
  drawContext.fuelUseGallons = appConfig.fuelUseGallons
  drawContext.speedUseMph = appConfig.speedUseMph
  drawContext.speedScale = appConfig.speedScale
  drawContext.chronoScale = appConfig.chronoScale
  drawContext.positionScale = appConfig.positionScale
  drawContext.fuelScale = appConfig.fuelScale
  drawContext.timeScale = appConfig.timeScale
  drawContext.gforceScale = appConfig.gforceScale
  drawContext.sectorScale = appConfig.sectorScale
  drawContext.damageScale = appConfig.damageScale
  drawContext.ledScale = appConfig.ledScale
  drawContext.pedalsScale = appConfig.pedalsScale
  drawContext.weatherUseFahrenheit = appConfig.weatherUseFahrenheit
  drawContext.chronoShowDelta = appConfig.chronoShowDelta
  drawContext.chronoShowCurrent = appConfig.chronoShowCurrent
  drawContext.chronoShowPrevious = appConfig.chronoShowPrevious
  drawContext.chronoShowBest = appConfig.chronoShowBest
  drawContext.fuelShowBar = appConfig.fuelShowBar
  drawContext.fuelShowPerLap = appConfig.fuelShowPerLap
  drawContext.fuelShowLaps = appConfig.fuelShowLaps
  drawContext.fuelShowTimeLeft = appConfig.fuelShowTimeLeft
  drawContext.sectorShowCurrent = appConfig.sectorShowCurrent
  drawContext.sectorShowLast = appConfig.sectorShowLast
  drawContext.sectorShowBest = appConfig.sectorShowBest
  drawContext.damageShowRepair = appConfig.damageShowRepair
  drawContext.damageShowDamage = appConfig.damageShowDamage
  drawContext.ledShowDRS = appConfig.ledShowDRS
  drawContext.ledShowTC = appConfig.ledShowTC
  drawContext.ledShowABS = appConfig.ledShowABS
  drawContext.ledShowSpeedLimiter = appConfig.ledShowSpeedLimiter
  drawContext.ledShowLight = appConfig.ledShowLight
  drawContext.ledShowFlashingLight = appConfig.ledShowFlashingLight
  drawContext.ledShowHazard = appConfig.ledShowHazard
  drawContext.ledShowTurningLight = appConfig.ledShowTurningLight
  drawContext.pedalsShowClutch = appConfig.pedalsShowClutch
  drawContext.pedalsShowBrake = appConfig.pedalsShowBrake
  drawContext.pedalsShowThrottle = appConfig.pedalsShowThrottle
  drawContext.deltaShowRefLap = appConfig.deltaShowRefLap
  drawContext.deltaShowDeltaBar = appConfig.deltaShowDeltaBar
  drawContext.deltaShowSectorBar = appConfig.deltaShowSectorBar
  drawContext.deltaScale = appConfig.deltaScale
  drawContext.deltaSectorThresholdMs = appConfig.deltaSectorThresholdMs
  drawContext.leaderboardRows = appConfig.leaderboardRows
  drawContext.leaderboardScale = appConfig.leaderboardScale
  drawContext.leaderboardMode = appConfig.leaderboardMode
  drawContext.leaderboardShowPositionChange = appConfig.leaderboardShowPositionChange
  drawContext.leaderboardShowLap = appConfig.leaderboardShowLap
  drawContext.leaderboardShowCompoundColumn = appConfig.leaderboardShowCompoundColumn
  drawContext.leaderboardShowNationFlag = appConfig.leaderboardShowNationFlag
  drawContext.leaderboardShowCarLogo = appConfig.leaderboardShowCarLogo
  drawContext.panelScale = appConfig.panelScale
  return drawContext
end

local function drawWidget(id, dt)
  widgetManager:draw(id, dt, prepareDrawContext())
end

local function checkboxBool(label, key)
  if ui.checkbox(label, appConfig[key]) then
    appConfig[key] = not appConfig[key]
  end
end

local function sectionTitle(title, color)
  refreshTheme()
  ui.dwriteText(title, 16, color or SectionSetup)
  ui.separator()
end

local function controlRow(label, control)
  ui.text(label)
  ui.sameLine(130, 0)
  control(vec2(ui.availableSpaceX(), 32))
end

local function tabChrono()
  checkboxBool('Show Delta', 'chronoShowDelta')
  checkboxBool('Show Current', 'chronoShowCurrent')
  checkboxBool('Show Previous', 'chronoShowPrevious')
  checkboxBool('Show Best', 'chronoShowBest')
end

local function tabFuel()
  checkboxBool('Show Current', 'fuelShowBar')
  checkboxBool('Show Fuel/Lap', 'fuelShowPerLap')
  checkboxBool('Show Remaining Laps', 'fuelShowLaps')
  checkboxBool('Show Remaining Time', 'fuelShowTimeLeft')
end

local function tabSector()
  checkboxBool('Show Current', 'sectorShowCurrent')
  checkboxBool('Show Last', 'sectorShowLast')
  checkboxBool('Show Best', 'sectorShowBest')
end

local function tabDamage()
  checkboxBool('Show Repairs', 'damageShowRepair')
  checkboxBool('Show Damages', 'damageShowDamage')
end

local function tabLed()
  checkboxBool('Show DRS', 'ledShowDRS')
  checkboxBool('Show TC', 'ledShowTC')
  checkboxBool('Show ABS', 'ledShowABS')
  checkboxBool('Show Speed Limiter', 'ledShowSpeedLimiter')
  checkboxBool('Show Light', 'ledShowLight')
  checkboxBool('Show Flashing Light', 'ledShowFlashingLight')
  checkboxBool('Show Hazard', 'ledShowHazard')
  checkboxBool('Show Turning Light', 'ledShowTurningLight')
end

local function tabPedals()
  checkboxBool('Show Clutch', 'pedalsShowClutch')
  checkboxBool('Show Brake', 'pedalsShowBrake')
  checkboxBool('Show Throttle', 'pedalsShowThrottle')
end

local function tabDelta()
  sectionTitle('Display', SectionSetup)
  checkboxBool('Show Sector Bar', 'deltaShowSectorBar')
  checkboxBool('Show Delta Bar', 'deltaShowDeltaBar')
  checkboxBool('Show Reference Lap', 'deltaShowRefLap')
  ui.newLine()
  sectionTitle('Threshold', SectionSetup)
  appConfig.deltaSectorThresholdMs = ui.slider('##DeltaThreshold', appConfig.deltaSectorThresholdMs, 5, 100,
    'Threshold: %.0f ms')
  ui.textWrapped(
    'Lower threshold values are better for experienced drivers. Higher values are more forgiving and easier to read for beginners.')
  ui.separator()

  local widget = widgetManager:get('delta')
  ui.newLine()
  sectionTitle('Reference', SectionSetup)
  if widget and ui.button('Save current reference') then
    widget:saveReference()
  end
  if widget and ui.button('Reset reference lap') then
    widget:resetReference()
  end
end

local function tabLeaderboard()
  appConfig.leaderboardRows = ui.slider('##LeaderboardRows', appConfig.leaderboardRows, 3, 24, 'Rows: %.0f')
  local modeLabels = { 'Top only', 'Around focus', 'Leader + focus' }

  ui.text('Mode')
  ui.sameLine(130, 0)
  ui.combo('##LeaderboardMode', modeLabels[appConfig.leaderboardMode] or modeLabels[2], 0, function()
    for i = 1, #modeLabels do
      if ui.selectable(modeLabels[i], appConfig.leaderboardMode == i) then
        appConfig.leaderboardMode = i
      end
    end
  end)

  checkboxBool('Show Position Change', 'leaderboardShowPositionChange')
  checkboxBool('Show Lap Count', 'leaderboardShowLap')
  checkboxBool('Show Compound Column', 'leaderboardShowCompoundColumn')
  checkboxBool('Show Nation Flag', 'leaderboardShowNationFlag')
  checkboxBool('Show Car Logo', 'leaderboardShowCarLogo')
end

local function tabPanel()
  sectionTitle('Navigation', SectionSetup)
  controlRow('Previous page', function(size)
    panelPrevControl:control(size, ui.ControlButtonControlFlags.SingleEntry)
  end)
  controlRow('Next page', function(size)
    panelNextControl:control(size, ui.ControlButtonControlFlags.SingleEntry)
  end)
  controlRow('Previous row', function(size)
    panelUpControl:control(size, ui.ControlButtonControlFlags.SingleEntry)
  end)
  controlRow('Next row', function(size)
    panelDownControl:control(size, ui.ControlButtonControlFlags.SingleEntry)
  end)
  controlRow('Decrease value', function(size)
    panelMinusControl:control(size, ui.ControlButtonControlFlags.SingleEntry)
  end)
  controlRow('Increase value', function(size)
    panelPlusControl:control(size, ui.ControlButtonControlFlags.SingleEntry)
  end)
  ui.newLine()
  sectionTitle('Quick Chat', SectionSetup)
  ui.textWrapped(
    'Right sends the selected quick chat message when Chat page is active and online.')
  ui.separator()
  appConfig.quickChat1 = ui.inputText('Quick chat 1', appConfig.quickChat1 or '')
  appConfig.quickChat2 = ui.inputText('Quick chat 2', appConfig.quickChat2 or '')
  appConfig.quickChat3 = ui.inputText('Quick chat 3', appConfig.quickChat3 or '')
  appConfig.quickChat4 = ui.inputText('Quick chat 4', appConfig.quickChat4 or '')
  appConfig.quickChat5 = ui.inputText('Quick chat 5', appConfig.quickChat5 or '')
  appConfig.quickChat6 = ui.inputText('Quick chat 6', appConfig.quickChat6 or '')
end

local function tabRadar()
  radarView:drawSetup(SectionSetup)
end

local function tabScale()
  sectionTitle('Global', SectionSetup)
  appConfig.scale = ui.slider('##GlobalScale', appConfig.scale, 1.0, 3.0, 'Global scale: %1.2f')
  ui.newLine()
  sectionTitle('Widgets', SectionSetup)
  ui.beginGroup()
  appConfig.speedScale = ui.slider('##SpeedScale', appConfig.speedScale, 0.50, 2.00, 'Speed scale: %1.2f')
  appConfig.chronoScale = ui.slider('##ChronoScale', appConfig.chronoScale, 0.50, 2.00, 'Chrono scale: %1.2f')
  appConfig.positionScale = ui.slider('##PositionScale', appConfig.positionScale, 0.50, 2.00, 'Position scale: %1.2f')
  appConfig.fuelScale = ui.slider('##FuelScale', appConfig.fuelScale, 0.50, 2.00, 'Fuel scale: %1.2f')
  appConfig.timeScale = ui.slider('##TimeScale', appConfig.timeScale, 0.50, 2.00, 'Time scale: %1.2f')
  appConfig.gforceScale = ui.slider('##GForceScale', appConfig.gforceScale, 0.50, 2.00, 'G-Force scale: %1.2f')
  ui.endGroup()
  ui.sameLine(0, 28)
  ui.beginGroup()
  appConfig.sectorScale = ui.slider('##SectorScale', appConfig.sectorScale, 0.50, 2.00, 'Sector scale: %1.2f')
  appConfig.damageScale = ui.slider('##DamageScale', appConfig.damageScale, 0.50, 2.00, 'Damage scale: %1.2f')
  appConfig.ledScale = ui.slider('##LedScale', appConfig.ledScale, 0.50, 2.00, 'LED scale: %1.2f')
  appConfig.pedalsScale = ui.slider('##PedalsScale', appConfig.pedalsScale, 0.50, 2.00, 'Pedals scale: %1.2f')
  appConfig.deltaScale = ui.slider('##DeltaScale', appConfig.deltaScale, 0.50, 2.00, 'Delta scale: %1.2f')
  appConfig.leaderboardScale = ui.slider('##LeaderboardScale', appConfig.leaderboardScale, 0.50, 2.00,
    'Leaderboard scale: %1.2f')
  appConfig.panelScale = ui.slider('##PanelScale', appConfig.panelScale, 0.50, 2.00, 'Panel scale: %1.2f')
  ui.endGroup()
end

local function tabTheme()
  refreshTheme()
  ui.text('Theme')
  ui.sameLine(130, 0)
  ui.combo('##Theme', appConfig.theme or 'default', 0, function()
    for i = 1, #themeNames do
      local name = themeNames[i]
      if ui.selectable(name, appConfig.theme == name) then
        appConfig.theme = name
        refreshTheme()
      end
    end
  end)
end

local function tabGeneral()
  refreshTheme()
  sectionTitle('Units', SectionSetup)
  checkboxBool('Use mph (default km/h)', 'speedUseMph')
  checkboxBool('Use gal (default L)', 'fuelUseGallons')
  checkboxBool('Use Fahrenheit (default C)', 'weatherUseFahrenheit')

  sectionTitle('About', SectionSetup)
  ui.dwriteText('SRA HUD Version ' .. VERSION, 16, rgbm(0.8, 0.3, 0, 1))
end

local function drawSetup()
  refreshTheme()
  ui.tabBar('someTabBarID', function()
    ui.tabItem('HUD', tabGeneral)
    ui.tabItem('Theme', tabTheme)
    ui.tabItem('Scale', tabScale)
    ui.tabItem('Chrono HUD', tabChrono)
    ui.tabItem('Fuel HUD', tabFuel)
    ui.tabItem('Sector HUD', tabSector)
    ui.tabItem('Damage HUD', tabDamage)
    ui.tabItem('LED HUD', tabLed)
    ui.tabItem('Pedals HUD', tabPedals)
    ui.tabItem('Delta HUD', tabDelta)
    ui.tabItem('Leaderboard HUD', tabLeaderboard)
    ui.tabItem('Panel HUD', tabPanel)
    ui.tabItem('Radar HUD', tabRadar)
  end)
  ui.separator()
  ui.dwriteText('Settings are saved automatically', 15, rgbm(0.5, 1, 0.5, 0.7))
end

function script.update(dt)
  refreshTheme()
  local context = {
    sim = ac.getSim(),
    car = ac.getCar(ac.getSim().focusedCar),
    colors = theme.colors,
    deltaShowSectorBar = appConfig.deltaShowSectorBar,
    deltaSectorThresholdMs = appConfig.deltaSectorThresholdMs,
  }

  widgetManager:update(dt, context)
end

function script.windowMain(dt)
  drawSetup()
end

function script.windowSpeed(dt)
  drawWidget('speed', dt)
end

function script.windowChrono(dt)
  drawWidget('chrono', dt)
end

function script.windowPosition(dt)
  drawWidget('position', dt)
end

function script.windowFuel(dt)
  drawWidget('fuel', dt)
end

function script.windowTime(dt)
  drawWidget('time', dt)
end

function script.windowGForce(dt)
  drawWidget('gforce', dt)
end

function script.windowSector(dt)
  drawWidget('sector', dt)
end

function script.windowDamage(dt)
  drawWidget('damage', dt)
end

function script.windowLed(dt)
  drawWidget('led', dt)
end

function script.windowPedals(dt)
  drawWidget('pedals', dt)
end

function script.windowDelta(dt)
  drawWidget('delta', dt)
end

function script.windowLeaderboard(dt)
  drawWidget('leaderboard', dt)
end

function script.windowPanel(dt)
  drawWidget('panel', dt)
end

function script.windowRadar(dt)
  radarView:draw(dt)
end

function script.onShowWindowSpeed()
  widgetManager:setWindowVisible('speed', true)
end

function script.onHideWindowSpeed()
  widgetManager:setWindowVisible('speed', false)
end

function script.onShowWindowChrono()
  widgetManager:setWindowVisible('chrono', true)
end

function script.onHideWindowChrono()
  widgetManager:setWindowVisible('chrono', false)
end

function script.onShowWindowPosition()
  widgetManager:setWindowVisible('position', true)
end

function script.onHideWindowPosition()
  widgetManager:setWindowVisible('position', false)
end

function script.onShowWindowFuel()
  widgetManager:setWindowVisible('fuel', true)
end

function script.onHideWindowFuel()
  widgetManager:setWindowVisible('fuel', false)
end

function script.onShowWindowTime()
  widgetManager:setWindowVisible('time', true)
end

function script.onHideWindowTime()
  widgetManager:setWindowVisible('time', false)
end

function script.onShowWindowGForce()
  widgetManager:setWindowVisible('gforce', true)
end

function script.onHideWindowGForce()
  widgetManager:setWindowVisible('gforce', false)
end

function script.onShowWindowSector()
  widgetManager:setWindowVisible('sector', true)
end

function script.onHideWindowSector()
  widgetManager:setWindowVisible('sector', false)
end

function script.onShowWindowDamage()
  widgetManager:setWindowVisible('damage', true)
end

function script.onHideWindowDamage()
  widgetManager:setWindowVisible('damage', false)
end

function script.onShowWindowLed()
  widgetManager:setWindowVisible('led', true)
end

function script.onHideWindowLed()
  widgetManager:setWindowVisible('led', false)
end

function script.onShowWindowPedals()
  widgetManager:setWindowVisible('pedals', true)
end

function script.onHideWindowPedals()
  widgetManager:setWindowVisible('pedals', false)
end

function script.onShowWindowDelta()
  widgetManager:setWindowVisible('delta', true)
end

function script.onHideWindowDelta()
  widgetManager:setWindowVisible('delta', false)
end

function script.onShowWindowLeaderboard()
  widgetManager:setWindowVisible('leaderboard', true)
end

function script.onHideWindowLeaderboard()
  widgetManager:setWindowVisible('leaderboard', false)
end

function script.onShowWindowPanel()
  widgetManager:setWindowVisible('panel', true)
end

function script.onHideWindowPanel()
  widgetManager:setWindowVisible('panel', false)
end
