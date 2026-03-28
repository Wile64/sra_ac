local PanelWidget = {}
PanelWidget.__index = PanelWidget

local TyreLogic = require('core.tyre_logic')

local DEG = string.char(194, 176)
local KMH_TO_MPH = 0.621371
local LITER_TO_GALLON = 0.2641720524
local buttonPrev = ac.ControlButton('sra_hud/Previous Page')
local buttonNext = ac.ControlButton('sra_hud/Next Page')
local buttonUp = ac.ControlButton('sra_hud/Previous Row')
local buttonDown = ac.ControlButton('sra_hud/Next Row')
local buttonMinus = ac.ControlButton('sra_hud/Decrease Value')
local buttonPlus = ac.ControlButton('sra_hud/Increase Value')
local sessionNames = {
  'Undefined',
  'Practice',
  'Qualify',
  'Race',
  'Hotlap',
  'TimeAttack',
  'Drift',
  'Drag',
}
local compass = { 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW' }

local function isPatchVersionAtLeast(targetMajor, targetMinor, targetPatch)
  local version = ac.getPatchVersion() or ''
  local major, minor, patch = version:match('(%d+)%.(%d+)%.(%d+)')
  if not major then
    return false
  end

  major = tonumber(major) or 0
  minor = tonumber(minor) or 0
  patch = tonumber(patch) or 0

  if major ~= targetMajor then
    return major > targetMajor
  end
  if minor ~= targetMinor then
    return minor > targetMinor
  end
  return patch >= targetPatch
end

local pitstopSupported = isPatchVersionAtLeast(0, 2, 11)
    and type(ac.getPitstopSpinners) == 'function'
    and type(ac.setPitstopSpinnerValue) == 'function'
    and type(ac.setCurrentQuickPitPreset) == 'function'
local PANEL_ROW_HEIGHT = 17
local PANEL_GAUGE_ROW_HEIGHT = 19
local DEBUG_MGU_BOUNDS = false

local function clampPageIndex(value, count)
  if value < 1 then
    return count
  end
  if value > count then
    return 1
  end
  return value
end

local function resolvePanelAccent(colors, accent)
  if type(accent) ~= 'string' then
    return accent
  end

  if accent == 'info' then
    return colors.valueStatic
  end
  if accent == 'control' then
    return colors.valueEdit
  end
  if accent == 'text' then
    return colors.valueNeutral
  end
  if accent == 'title' then
    return colors.label
  end
  return colors.valueNeutral
end

local function formatTemperature(valueC, useFahrenheit)
  local value = valueC or 0
  local unit = 'C'
  if useFahrenheit then
    value = value * 9 / 5 + 32
    unit = 'F'
  end
  return string.format('%.0f %s%s', value, DEG, unit)
end

local function formatWindSpeed(valueKmh, useMph)
  local value = valueKmh or 0
  local unit = 'km/h'
  if useMph then
    value = value * KMH_TO_MPH
    unit = 'mph'
  end
  return string.format('%.0f %s', value, unit)
end

local function formatFuelUnit(valueLiters, useGallons)
  local value = valueLiters or 0
  local unit = 'L'
  if useGallons then
    value = value * LITER_TO_GALLON
    unit = 'gal'
  end
  return string.format('%.1f %s', value, unit)
end

local function formatPercent(value, factor)
  return string.format('%.1f%%', (value or 0) * (factor or 1))
end

local function formatMode(label, value)
  if (value or 0) <= 0 then
    return label ~= '' and (label .. ' Off') or 'Off'
  end
  return label ~= '' and string.format('%s %d', label, value) or tostring(value)
end

local function getAssistLabel(value, maxValue)
  local currentValue = value or 0
  local maxModes = maxValue or 0

  if currentValue <= 0 then
    return 'OFF'
  end

  if maxModes <= 1 then
    return 'ON'
  end

  local modeIndex = math.min(math.max(1, currentValue), maxModes)
  if modeIndex == 1 then
    return 'MAX'
  end
  if modeIndex == maxModes then
    return 'MIN'
  end

  local middleModes = maxModes - 2
  if middleModes <= 0 then
    return 'ON'
  end

  local middleIndex = modeIndex - 1
  local baseSize = math.floor(middleModes / 3)
  local remainder = middleModes % 3
  local bucketSizes = { baseSize, baseSize, baseSize }

  for i = 1, remainder do
    bucketSizes[2] = bucketSizes[2] + 1
    if i == 2 then
      bucketSizes[1] = bucketSizes[1] + 1
    elseif i == 3 then
      bucketSizes[3] = bucketSizes[3] + 1
    end
  end

  local cumulative = bucketSizes[1]
  if middleIndex <= cumulative then
    return 'HIGH'
  end
  cumulative = cumulative + bucketSizes[2]
  if middleIndex <= cumulative then
    return 'MED'
  end

  return 'LOW'
end

local function formatMgukDeliveryLabel(car)
  local deliveryIndex = car and (car.mgukDelivery or 0) or 0
  local programName = car and ac.getMGUKDeliveryName(car.index, deliveryIndex) or nil
  if programName and programName ~= '' then
    return string.format('Delivery (%s)', programName)
  end
  return 'Delivery'
end

local function formatSessionTime(sessionTimeLeft)
  if not sessionTimeLeft or sessionTimeLeft <= 0 then
    return 'Overtime'
  end
  return tostring(os.date('!%X', sessionTimeLeft / 1000))
end

local function formatWindDirection(value)
  local degrees = ((value or 0) + 180) % 360
  local index = math.floor((degrees + 22.5) / 45) % 8 + 1
  return string.format('%.0f° %s', degrees, compass[index])
end

local function formatOnOff(value)
  return value and 'On' or 'Off'
end

local function isWheelSlipping(wheel)
  if not wheel or wheel.isBlown then
    return false
  end

  local slip = math.abs(wheel.ndSlip or 0)
  local slipRatio = math.abs(wheel.slipRatio or 0)
  local slipAngle = math.abs(wheel.slipAngle or 0)
  return slipRatio > 0.10 or slipAngle > 5 or slip > 1
end

local function formatOptionalInt(value)
  if not value or value <= 0 then
    return '--'
  end
  return tostring(math.floor(value))
end

local function formatFuelMap(value)
  local v = math.floor(value or 0)
  if v == 0 then
    return 'Low'
  end
  if v == 1 then
    return 'Balanced'
  end
  if v == 2 then
    return 'High'
  end
  if v < 0 then
    return '--'
  end
  return tostring(v)
end

local function formatTurboWastegate(value)
  return string.format('%.0f%%', math.max(0, math.min(1, value or 0)) * 100)
end

local function formatLapsRemaining(fuel, fuelPerLap)
  if not fuelPerLap or fuelPerLap <= 0 then
    return '--'
  end
  return string.format('%.1f', fuel / fuelPerLap)
end

local function formatRemainingTime(ms)
  if not ms or ms <= 0 then
    return '--'
  end

  local totalSeconds = math.floor(ms / 1000 + 0.5)
  local hours = math.floor(totalSeconds / 3600)
  local minutes = math.floor((totalSeconds % 3600) / 60)
  local seconds = totalSeconds % 60

  if hours > 0 then
    return string.format('%d:%02d:%02d', hours, minutes, seconds)
  end

  return string.format('%02d:%02d', minutes, seconds)
end

local function formatValue(value, fmt, fallback)
  if value == nil then
    return fallback or '--'
  end
  return string.format(fmt, value)
end

local function formatAngle(value)
  if not value or value <= 0 then
    return '--'
  end
  return string.format('%.0f %s', value, DEG)
end

local function formatTyrePressure(value)
  if not value or value <= 0 then
    return '--'
  end
  return string.format('%.1f psi', value)
end

local function formatPressureDelta(value)
  if not value or math.abs(value) < 0.05 then
    return 'Ideal'
  end
  return string.format('%+.1f psi', value)
end

local function formatPitTime(seconds)
  if not seconds or seconds <= 0.05 then
    return '--'
  end
  return string.format('%.0fs', seconds)
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

local function formatPitstopName(name)
  local names = {
    fuel = 'Fuel',
    compound = 'Tyres',
    repair = 'Repair',
    repair_body = 'Body',
    repair_engine = 'Engine',
    repair_suspension = 'Susp',
    pressure = 'Pressure',
    wing = 'Wing',
  }
  return names[name] or (name and name:gsub('^%l', string.upper)) or '--'
end

local function estimateRepairSpinnerTime(spinnerName, bodyRepair, engineRepair, suspensionRepair)
  local name = (spinnerName or ''):lower()
  if name:find('body', 1, true) then
    return bodyRepair
  end
  if name:find('engine', 1, true) or name:find('motor', 1, true) then
    return engineRepair
  end
  if name:find('susp', 1, true) then
    return suspensionRepair
  end
  return 0
end

local function getPitstopSpinnerValue(spinner, presetIndex)
  if not spinner then
    return 0
  end
  local values = spinner.values
  local presetSlot = (presetIndex or 0) + 1
  if values and values[presetSlot] ~= nil then
    return values[presetSlot]
  end
  return spinner.value or 0
end

local function formatPitstopValue(car, spinner, presetIndex)
  if not spinner then
    return '--'
  end

  local value = getPitstopSpinnerValue(spinner, presetIndex)
  if spinner.type == 'fuel' then
    return string.format('%d L', value)
  end
  if spinner.type == 'pressure' then
    return string.format('%d', value)
  end
  if spinner.type == 'compound' then
    if value == -1 then
      return 'keep'
    end
    local carIndex = car and car.index or 0
    local shortName = ac.getTyresName(carIndex, value)
    if shortName and shortName ~= '' then
      return shortName
    end
    return tostring(value)
  end
  if spinner.type == 'repair' then
    return value > 0 and 'Yes' or 'No'
  end
  return tostring(value)
end

local function formatTyreCompound(car)
  if not car then
    return '--'
  end

  local carIndex = car.index or 0
  local compoundIndex = car.compoundIndex or 0
  local longName = ac.getTyresLongName(carIndex, compoundIndex, true) or ''
  if longName ~= '' then
    return longName
  end
  return car:tyresName() or '--'
end

function PanelWidget:new(storage)
  return setmetatable({
    id = 'panel',
    title = 'Panel',
    windowId = 'windowPanel',
    storage = storage,
    pages = {},
    currentPage = math.floor(storage.panelPage or storage.panelTestPage or 1),
    prevBindDown = false,
    nextBindDown = false,
    upBindDown = false,
    downBindDown = false,
    currentAmbientC = 0,
    currentRoadC = 0,
    currentWindKmh = 0,
    currentFuelLiters = 0,
    currentFuelPerLap = 0,
    currentOilTemperatureC = 0,
    currentExhaustTemperatureC = 0,
    currentCar = nil,
    fuelDataAvailable = true,
    tyreDataAvailable = true,
    focusedCarIndex = -1,
    wheelData = {},
    tyreLogic = TyreLogic:new(),
    systemsRows = {},
    weatherRows = {},
    raceRows = {},
    fuelRows = {},
    kersRows = {},
    mguRows = {},
    pitstopSpinners = {},
    pitstopPreset = 0,
    pitstopAvailable = false,
    pitRepairTimes = {
      tyre = 0,
      fuelPerLiter = 0,
      body = 0,
      engine = 0,
      suspension = 0,
    },
    currentPitTotalEstimate = 0,
    currentPitEstimates = {},
    pitHoldAction = nil,
    pitHoldElapsed = 0,
    pitHoldNext = 0,
    valueHoldAction = nil,
    valueHoldElapsed = 0,
    valueHoldNext = 0,
    selectedSystemsRow = 0,
    selectedMguRow = 0,
    selectedPitRow = 0,
    quickChatAvailable = false,
    quickChatRows = {},
    selectedQuickChatRow = 0,
  }, self)
end

function PanelWidget:setPage(index)
  local pageCount = math.max(1, #self.pages)
  self.currentPage = clampPageIndex(index, pageCount)
  self.storage.panelPage = self.currentPage
  self.storage.panelTestPage = self.currentPage
  local page = self.pages[self.currentPage]
  self.selectedSystemsRow = page and page.kind == 'systems' and 1 or 0
  self.selectedMguRow = page and page.kind == 'mgu' and 1 or 0
  self.selectedPitRow = page and page.kind == 'pit' and 1 or 0
  self.selectedQuickChatRow = page and page.kind == 'chat' and 1 or 0
end

function PanelWidget:nextPage()
  self:setPage(self.currentPage + 1)
end

function PanelWidget:previousPage()
  self:setPage(self.currentPage - 1)
end

function PanelWidget:movePitSelection(delta)
  local maxRow = math.max(1, 1 + #self:getVisiblePitstopSpinners())
  self.selectedPitRow = math.max(1, math.min(maxRow, (self.selectedPitRow or 1) + delta))
end

function PanelWidget:moveSystemsSelection(delta)
  local maxRow = #self.systemsRows
  self.selectedSystemsRow = math.max(1, math.min(maxRow, (self.selectedSystemsRow or 1) + delta))
end

function PanelWidget:moveMguSelection(delta)
  local maxRow = #self.mguRows
  self.selectedMguRow = math.max(1, math.min(maxRow, (self.selectedMguRow or 1) + delta))
end

function PanelWidget:moveQuickChatSelection(delta)
  local maxRow = math.max(0, #self.quickChatRows)
  self.selectedQuickChatRow = math.max(0, math.min(maxRow, (self.selectedQuickChatRow or 0) + delta))
end

function PanelWidget:refreshPitstopData(sim)
  if not pitstopSupported then
    self.pitstopPreset = 0
    self.pitstopAvailable = false
    self.pitstopSpinners = {}
    self.selectedPitRow = 0
    return
  end

  local currentSim = sim or ac.getSim()
  local simPreset = currentSim and currentSim.currentQuickPitPreset
  if simPreset ~= nil then
    self.pitstopPreset = simPreset
  end
  self.pitstopAvailable = pitstopSupported and self.fuelDataAvailable and self.pitstopPreset ~= nil
  self.pitstopSpinners = self.pitstopAvailable and ac.getPitstopSpinners() or {}
  self.selectedPitRow = math.max(1,
    math.min(self.selectedPitRow or 1, math.max(1, 1 + #self:getVisiblePitstopSpinners())))
end

function PanelWidget:getVisiblePitstopSpinners()
  local visible = {}
  local compoundValue = nil

  for i = 1, #self.pitstopSpinners do
    local spinner = self.pitstopSpinners[i]
    if spinner.type == 'compound' then
      compoundValue = getPitstopSpinnerValue(spinner, self.pitstopPreset)
      break
    end
  end

  for i = 1, #self.pitstopSpinners do
    local spinner = self.pitstopSpinners[i]
    if not (spinner.type == 'pressure' and compoundValue == -1) then
      table.insert(visible, spinner)
    end
  end

  return visible
end

function PanelWidget:setPitstopPreset(preset)
  self.pitstopPreset = math.max(0, math.min(2, preset or 0))
end

function PanelWidget:loadPitRepairTimes(carIndex)
  local carINI = ac.INIConfig.carData(carIndex, 'car.ini')
  if not carINI then
    self.pitRepairTimes = { tyre = 0, fuelPerLiter = 0, body = 0, engine = 0, suspension = 0 }
    return
  end

  self.pitRepairTimes = {
    tyre = carINI:get('PIT_STOP', 'TYRE_CHANGE_TIME_SEC', 0),
    fuelPerLiter = carINI:get('PIT_STOP', 'FUEL_LITER_TIME_SEC', 0),
    body = carINI:get('PIT_STOP', 'BODY_REPAIR_TIME_SEC', 0),
    engine = carINI:get('PIT_STOP', 'ENGINE_REPAIR_TIME_SEC', 0),
    suspension = carINI:get('PIT_STOP', 'SUSP_REPAIR_TIME_SEC', 0),
  }
end

function PanelWidget:updatePitstopSpinnerLocal(spinnerName, value, presetIndex)
  for i = 1, #self.pitstopSpinners do
    local spinner = self.pitstopSpinners[i]
    if spinner.name == spinnerName then
      spinner.value = value
      if spinner.values then
        spinner.values[(presetIndex or 0) + 1] = value
      end
      break
    end
  end
end

function PanelWidget:calculatePitEstimates()
  local visibleSpinners = self:getVisiblePitstopSpinners()
  local car = self.currentCar
  local bodyRepair = car and calculateBodyRepairTime(car, self.pitRepairTimes.body or 0) or 0
  local engineRepair = car and calculateEngineRepairTime(car, self.pitRepairTimes.engine or 0) or 0
  local suspensionRepair = car and calculateSuspensionRepairTime(car, self.pitRepairTimes.suspension or 0) or 0
  local totalEstimate = 0
  local estimates = {}

  for i = 1, #visibleSpinners do
    local spinner = visibleSpinners[i]
    local value = getPitstopSpinnerValue(spinner, self.pitstopPreset)
    local estimate = 0

    if spinner.type == 'fuel' and value > 0 then
      estimate = value * (self.pitRepairTimes.fuelPerLiter or 0)
    elseif spinner.type == 'compound' and value ~= -1 then
      estimate = self.pitRepairTimes.tyre or 0
    elseif spinner.type == 'repair' and value > 0 then
      estimate = estimateRepairSpinnerTime(spinner.name, bodyRepair, engineRepair, suspensionRepair)
    end

    estimates[i] = estimate
    totalEstimate = math.max(totalEstimate, estimate)
  end

  return estimates, totalEstimate
end

function PanelWidget:adjustSelectedPitSpinner(delta)
  local selectedRow = self.selectedPitRow or 0
  local visibleSpinners = self:getVisiblePitstopSpinners()
  if selectedRow == 1 then
    local nextPreset = math.max(0, math.min(2, (self.pitstopPreset or 0) + delta))
    if nextPreset == (self.pitstopPreset or 0) then
      return false
    end
    if ac.setCurrentQuickPitPreset(nextPreset) then
      self:setPitstopPreset(nextPreset)
      return true
    end
    return false
  end

  local row = selectedRow - 1
  if row < 1 then
    return false
  end

  local spinner = visibleSpinners[row]
  if not spinner or spinner.readOnly then
    return false
  end

  local currentValue = getPitstopSpinnerValue(spinner, self.pitstopPreset)
  local nextValue = math.max(spinner.min or currentValue,
    math.min(spinner.max or currentValue, currentValue + delta))
  if nextValue == currentValue then
    return false
  end

  if ac.setPitstopSpinnerValue(spinner.name, nextValue, self.pitstopPreset) then
    self:updatePitstopSpinnerLocal(spinner.name, nextValue, self.pitstopPreset)
    return true
  end

  return false
end

function PanelWidget:processPitButtonHold(actionKey, dt, callback)
  if ui.itemActive() and ui.mouseDown(ui.MouseButton.Left) then
    if self.pitHoldAction ~= actionKey then
      self.pitHoldAction = actionKey
      self.pitHoldElapsed = 0
      self.pitHoldNext = 0.35
    else
      self.pitHoldElapsed = self.pitHoldElapsed + dt
      if self.pitHoldElapsed >= self.pitHoldNext then
        callback()
        self.pitHoldNext = self.pitHoldNext + 0.08
      end
    end
    return true
  end

  if self.pitHoldAction == actionKey then
    self.pitHoldAction = nil
    self.pitHoldElapsed = 0
    self.pitHoldNext = 0
  end
  return false
end

function PanelWidget:processValueBindHold(actionKey, isDown, dt, callback)
  if isDown then
    if self.valueHoldAction ~= actionKey then
      self.valueHoldAction = actionKey
      self.valueHoldElapsed = 0
      self.valueHoldNext = 0.35
    else
      self.valueHoldElapsed = self.valueHoldElapsed + dt
      if self.valueHoldElapsed >= self.valueHoldNext then
        callback()
        self.valueHoldNext = self.valueHoldNext + 0.08
      end
    end
    return
  end

  if self.valueHoldAction == actionKey then
    self.valueHoldAction = nil
    self.valueHoldElapsed = 0
    self.valueHoldNext = 0
  end
end

function PanelWidget:adjustSelectedSystem(delta)
  if not self.currentCar or not (self.currentCar.isUserControlled or self.currentCar.index == 0) then
    return false
  end

  local row = self.selectedSystemsRow or 0
  local rowData = self.systemsRows[row]
  local rowId = rowData and rowData[4] or nil
  if rowId == 'tc' then
    local maxModes = math.max(0, self.currentCar.tractionControlModes or 0)
    local nextValue = math.max(0, math.min(maxModes, (self.currentCar.tractionControlMode or 0) + delta))
    if nextValue ~= (self.currentCar.tractionControlMode or 0) then
      ac.setTC(nextValue)
      return true
    end
  elseif rowId == 'bb' then
    local currentValue = self.currentCar.brakeBias or 0
    local nextValue = math.max(0, math.min(1, currentValue + delta * 0.01))
    if math.abs(nextValue - currentValue) > 0.001 then
      ac.setBrakeBias(nextValue)
      return true
    end
  elseif rowId == 'abs' then
    local maxModes = math.max(0, self.currentCar.absModes or 0)
    local nextValue = math.max(0, math.min(maxModes, (self.currentCar.absMode or 0) + delta))
    if nextValue ~= (self.currentCar.absMode or 0) then
      ac.setABS(nextValue)
      return true
    end
  elseif rowId == 'turbo' then
    if self.currentCar.adjustableTurbo and (self.currentCar.turboCount or 0) > 0 and ac.isTurboWastegateAdjustable(0) then
      local currentValue = ((self.currentCar.turboWastegates and self.currentCar.turboWastegates[0]) or 0)
      local nextValue = math.max(0, math.min(1, currentValue + delta * 0.10))
      if math.abs(nextValue - currentValue) > 0.001 then
        ac.setTurboWastegate(nextValue, 0)
        return true
      end
    end
  elseif rowId == 'engine_brake' then
    if self.currentCar.hasEngineBrakeSettings then
      local currentValue = self.currentCar.currentEngineBrakeSetting or 0
      local nextValue = math.max(0, math.min(20, currentValue + delta))
      if nextValue ~= currentValue then
        ac.setEngineBrakeSetting(nextValue)
        return true
      end
    end
  end

  return false
end

function PanelWidget:adjustSelectedMgu(delta)
  if not self.currentCar or not (self.currentCar.isUserControlled or self.currentCar.index == 0) then
    return false
  end

  local row = self.selectedMguRow or 0
  local rowData = self.mguRows[row]
  local rowId = rowData and rowData[4] or nil

  if rowId == 'mguk_delivery' then
    local maxModes = math.max(0, self.currentCar.mgukDeliveryCount or 0)
    if maxModes <= 1 then
      return false
    end
    local currentValue = self.currentCar.mgukDelivery or 0
    local nextValue = math.max(0, math.min(maxModes - 1, currentValue + delta))
    if nextValue ~= currentValue then
      ac.setMGUKDelivery(nextValue)
      return true
    end
  elseif rowId == 'mguk_recovery' then
    if not self.currentCar.hasCockpitERSRecovery then
      return false
    end
    local currentValue = self.currentCar.mgukRecovery or 0
    local nextValue = math.max(0, math.min(10, currentValue + delta))
    if nextValue ~= currentValue then
      ac.setMGUKRecovery(nextValue)
      return true
    end
  end

  return false
end

function PanelWidget:update(dt, context)
  local car = context.car
  local sim = context.sim
  local session = sim and ac.getSession(sim.currentSessionIndex) or nil

  local nextBindDown = buttonNext:pressed()
  local prevBindDown = buttonPrev:pressed()
  local upBindDown = buttonUp:pressed()
  local downBindDown = buttonDown:pressed()
  local minusBindDown = buttonMinus:down()
  local plusBindDown = buttonPlus:down()
  local currentPage = self.pages[self.currentPage]
  local systemsRowSelected = currentPage and currentPage.kind == 'systems' and (self.selectedSystemsRow or 0) > 0
  local mguRowSelected = currentPage and currentPage.kind == 'mgu' and (self.selectedMguRow or 0) > 0
  local pitRowSelected = currentPage and currentPage.kind == 'pit' and (self.selectedPitRow or 0) > 0
  local chatRowSelected = currentPage and currentPage.kind == 'chat' and (self.selectedQuickChatRow or 0) > 0

  if nextBindDown and not self.nextBindDown then
    self:nextPage()
  end
  if prevBindDown and not self.prevBindDown then
    self:previousPage()
  end
  if upBindDown and not self.upBindDown then
    if currentPage and currentPage.kind == 'systems' then
      self:moveSystemsSelection(-1)
    elseif currentPage and currentPage.kind == 'mgu' then
      self:moveMguSelection(-1)
    elseif currentPage and currentPage.kind == 'pit' then
      self:movePitSelection(-1)
    elseif currentPage and currentPage.kind == 'chat' then
      self:moveQuickChatSelection(-1)
    end
  end
  if downBindDown and not self.downBindDown then
    if currentPage and currentPage.kind == 'systems' then
      self:moveSystemsSelection(1)
    elseif currentPage and currentPage.kind == 'mgu' then
      self:moveMguSelection(1)
    elseif currentPage and currentPage.kind == 'pit' then
      self:movePitSelection(1)
    elseif currentPage and currentPage.kind == 'chat' then
      self:moveQuickChatSelection(1)
    end
  end
  if plusBindDown and not self.plusBindDown then
    if chatRowSelected then
      self:sendSelectedQuickChat()
    elseif systemsRowSelected then
      self:adjustSelectedSystem(1)
    elseif mguRowSelected then
      self:adjustSelectedMgu(1)
    elseif pitRowSelected then
      self:adjustSelectedPitSpinner(1)
    end
  end
  if minusBindDown and not self.minusBindDown then
    if systemsRowSelected then
      self:adjustSelectedSystem(-1)
    elseif mguRowSelected then
      self:adjustSelectedMgu(-1)
    elseif pitRowSelected then
      self:adjustSelectedPitSpinner(-1)
    end
  end

  if systemsRowSelected then
    self:processValueBindHold('systems_plus_' .. tostring(self.selectedSystemsRow or 0), plusBindDown and self.plusBindDown, dt,
      function()
        self:adjustSelectedSystem(1)
      end)
    self:processValueBindHold('systems_minus_' .. tostring(self.selectedSystemsRow or 0), minusBindDown and self.minusBindDown, dt,
      function()
        self:adjustSelectedSystem(-1)
      end)
  elseif mguRowSelected then
    self:processValueBindHold('mgu_plus_' .. tostring(self.selectedMguRow or 0), plusBindDown and self.plusBindDown, dt,
      function()
        self:adjustSelectedMgu(1)
      end)
    self:processValueBindHold('mgu_minus_' .. tostring(self.selectedMguRow or 0), minusBindDown and self.minusBindDown, dt,
      function()
        self:adjustSelectedMgu(-1)
      end)
  elseif pitRowSelected then
    self:processValueBindHold('pit_plus_' .. tostring(self.selectedPitRow or 0), plusBindDown and self.plusBindDown, dt,
      function()
        self:adjustSelectedPitSpinner(1)
      end)
    self:processValueBindHold('pit_minus_' .. tostring(self.selectedPitRow or 0), minusBindDown and self.minusBindDown, dt,
      function()
        self:adjustSelectedPitSpinner(-1)
      end)
  else
    self.valueHoldAction = nil
    self.valueHoldElapsed = 0
    self.valueHoldNext = 0
  end

  self.nextBindDown = nextBindDown
  self.prevBindDown = prevBindDown
  self.upBindDown = upBindDown
  self.downBindDown = downBindDown
  self.minusBindDown = minusBindDown
  self.plusBindDown = plusBindDown

  self.currentAmbientC = sim and sim.ambientTemperature or 0
  self.currentRoadC = sim and sim.roadTemperature or 0
  self.currentCar = car
  if car and (self.focusedCarIndex ~= car.index or self.tyreLogic.compoundIndex ~= (car.compoundIndex or 0)) then
    self.focusedCarIndex = car.index
    self.tyreLogic:load(car.index, car.compoundIndex or 0)
    self:loadPitRepairTimes(car.index)
  end
  self.selectedSystemsRow = math.max(1, math.min(self.selectedSystemsRow or 1, math.max(1, #self.systemsRows)))
  self.selectedMguRow = math.max(1, math.min(self.selectedMguRow or 1, math.max(1, #self.mguRows)))
  self.quickChatAvailable = sim and sim.isOnlineRace or false
  self.fuelDataAvailable = car and (car.isUserControlled or car.index == 0) or false
  self.tyreDataAvailable = self.fuelDataAvailable
  self.currentFuelLiters = self.fuelDataAvailable and (car and car.fuel or 0) or 0
  self.currentFuelPerLap = self.fuelDataAvailable and (car and car.fuelPerLap or 0) or 0
  self.currentFuelReferenceLapTimeMs = car and
  math.max(car.previousLapTimeMs or 0, car.bestLapTimeMs or 0, car.lapTimeMs or 0) or 0
  self.currentOilTemperatureC = car and car.oilTemperature or 0
  self.currentExhaustTemperatureC = car and car.exhaustTemperature or 0
  self:refreshPitstopData(sim)
  self.selectedPitRow = math.max(1,
    math.min(self.selectedPitRow or 1, math.max(1, 1 + #self:getVisiblePitstopSpinners())))
  local pitEstimates, pitTotalEstimate = self:calculatePitEstimates()
  self.currentPitEstimates = pitEstimates or {}
  self.currentPitTotalEstimate = pitTotalEstimate or 0
  local wheels = self.tyreDataAvailable and car and car.wheels or nil
  self.wheelData = {}
  for i = 0, 3 do
    local wheel = wheels and wheels[i] or nil
    local pressure = wheel and
        ((wheel.tyrePressure and wheel.tyrePressure > 0) and wheel.tyrePressure or wheel.tyreStaticPressure) or 0
    local core = wheel and wheel.tyreCoreTemperature or 0
    local optimum = wheel and wheel.tyreOptimumTemperature or 0
    local tyreEval = self.tyreLogic:evaluateWheel(i + 1, pressure, core, optimum, wheel and wheel.tyreVirtualKM or 0)
    self.wheelData[i + 1] = {
      isBlown = wheel and wheel.isBlown or false,
      isSlipping = isWheelSlipping(wheel),
      pressure = pressure,
      core = core,
      inside = wheel and wheel.tyreInsideTemperature or 0,
      middle = wheel and wheel.tyreMiddleTemperature or 0,
      outside = wheel and wheel.tyreOutsideTemperature or 0,
      optimum = optimum,
      wear = wheel and wheel.tyreWear or 0,
      idealPressure = tyreEval.idealPressure or 0,
      idealTemp = tyreEval.idealTemp or 0,
      idealMinTemp = tyreEval.idealMinTemp or 0,
      idealMaxTemp = tyreEval.idealMaxTemp or 0,
      pressureDelta = tyreEval.pressureDelta or 0,
      performanceRatio = tyreEval.performanceRatio,
      wearGrip = tyreEval.wearGrip,
    }
  end

  local wind = (sim and sim.weatherConditions and sim.weatherConditions.wind and sim.weatherConditions.wind.speedFrom) or
      0
  local windDirection = (sim and sim.weatherConditions and sim.weatherConditions.wind and
    (sim.weatherConditions.wind.direction or sim.weatherConditions.wind.heading)) or 0
  self.currentWindKmh = wind

  local activeCars = 0
  local totalCars = sim and sim.carsCount or 0
  for i = 0, math.max(0, totalCars - 1) do
    local otherCar = ac.getCar(i)
    if otherCar and (otherCar.isActive == nil or otherCar.isActive) then
      activeCars = activeCars + 1
    end
  end

  local sessionName = sessionNames[(sim and sim.raceSessionType or 0) + 1] or 'Session'
  local sessionLength = '--'
  if sim then
    if sim.raceSessionType == ac.SessionType.Race and session and not sim.isTimedRace and (session.laps or 0) > 0 then
      sessionLength = string.format('%d laps', session.laps)
    else
      sessionLength = formatSessionTime(sim.sessionTimeLeft)
    end
  end

  self.systemsRows = {
    {
      string.format('TC (%s)', getAssistLabel(car and car.tractionControlMode or 0, car and car.tractionControlModes or 0)),
      formatMode('', car and car.tractionControlMode or 0),
      'control',
      'tc'
    },
    {
      string.format('Bias (%.0f/%.0f)',
        100 - (car and (car.brakeBias or 0) or 0) * 100,
        (car and (car.brakeBias or 0) or 0) * 100),
      string.format('%.0f%%', (car and (car.brakeBias or 0) or 0) * 100),
      'control',
      'bb'
    },
    {
      string.format('ABS (%s)', getAssistLabel(car and car.absMode or 0, car and car.absModes or 0)),
      formatMode('', car and car.absMode or 0),
      'control',
      'abs'
    },
    { 'Fuel Map',   formatFuelMap(car and car.fuelMap or 0),                    'info',    nil },
  }
  if car and car.adjustableTurbo and (car.turboCount or 0) > 0 and ac.isTurboWastegateAdjustable(0) then
    table.insert(self.systemsRows, 4, {
      'Turbo',
      formatTurboWastegate((car.turboWastegates and car.turboWastegates[0]) or 0),
      'control',
      'turbo'
    })
  end
  if car and car.hasEngineBrakeSettings then
    table.insert(self.systemsRows, {
      'Eng Brake',
      formatOptionalInt((car.currentEngineBrakeSetting or 0) + 1),
      'control',
      'engine_brake'
    })
  end

  self.weatherRows = {
    { 'Ambient',   formatTemperature(self.currentAmbientC, false), 'info' },
    { 'Road',      formatTemperature(self.currentRoadC, false),    'info' },
    { 'Wind',      formatWindSpeed(self.currentWindKmh, false),    'info' },
    { 'Direction', formatWindDirection(windDirection),             'info' },
  }

  self.raceRows = {
    { 'Session',    sessionName,                                               'info' },
    { 'Length',     sessionLength,                                             'info' },
    { 'Drivers',    string.format('%d/%d', activeCars, totalCars),             'info' },
    { 'Grip',       formatPercent(sim and sim.roadGrip or 1, 100),             'info' },
    { 'Damage',     formatPercent(sim and sim.mechanicalDamageRate or 1, 100), 'info' },
    { 'Tyre Rate',  formatPercent(sim and sim.tyreConsumptionRate or 1, 100),  'info' },
    { 'Fuel Rate',  formatPercent(sim and sim.fuelConsumptionRate or 1, 100),  'info' },
    { 'Restrictor', formatValue(car and car.restrictor or 0, '%.0f%%'),        'info' },
    { 'Ballast',    formatValue(car and car.ballast or 0, '%.0f kg'),          'info' },
    { 'Steer Lock', formatAngle(car and car.steerLock or 0),                   'info' },
  }

  self.fuelRows = {
    { 'Fuel',      self.fuelDataAvailable and formatFuelUnit(self.currentFuelLiters, false) or 'N/A',                       'info' },
    { 'Fuel/Lap',  self.fuelDataAvailable and formatFuelUnit(self.currentFuelPerLap, false) or 'N/A',                       'info' },
    { 'Laps Left', self.fuelDataAvailable and formatLapsRemaining(self.currentFuelLiters, self.currentFuelPerLap) or 'N/A', 'info' },
    { 'Time Left', self.fuelDataAvailable and
    formatRemainingTime((self.currentFuelPerLap > 0 and self.currentFuelReferenceLapTimeMs > 0)
      and ((self.currentFuelLiters / self.currentFuelPerLap) * self.currentFuelReferenceLapTimeMs) or 0) or 'N/A',
      'info' },
  }

  self.kersRows = {
    { 'Charge',   formatPercent(car and car.kersCharge or 0, 100),        'info' },
    { 'Input',    formatPercent(car and car.kersInput or 0, 100),         'info' },
    { 'Current',  formatValue(car and car.kersCurrentKJ or 0, '%.1f kJ'), 'info' },
    { 'Max',      formatValue(car and car.kersMaxKJ or 0, '%.1f kJ'),     'info' },
    { 'Load',     formatPercent(car and car.kersLoad or 0, 100),          'info' },
    { 'Charging', formatOnOff(car and car.kersCharging),                  'info' },
  }

  local mgukDeliveryCount = car and (car.mgukDeliveryCount or 0) or 0
  local mgukDeliveryAdjustable = mgukDeliveryCount > 1
  local mgukRecoveryAdjustable = car and car.hasCockpitERSRecovery or false

  self.mguRows = {
    {
      formatMgukDeliveryLabel(car),
      formatOptionalInt(car and ((car.mgukDelivery or 0) + 1) or 0),
      mgukDeliveryAdjustable and 'control' or 'info',
      mgukDeliveryAdjustable and 'mguk_delivery' or nil
    },
    {
      'Recovery',
      (car and (car.mgukRecovery or 0) or 0) <= 0 and 'OFF' or string.format('%.0f%%', (car and car.mgukRecovery or 0) * 10),
      mgukRecoveryAdjustable and 'control' or 'info',
      mgukRecoveryAdjustable and 'mguk_recovery' or nil
    },
    { 'Modes', formatOptionalInt(car and car.mgukDeliveryCount or 0),         'info' },
    { 'Batteries',  formatOnOff(car and car.mguhChargingBatteries),                'info' },
    { 'ERS Deliv',  formatOnOff(car and car.hasCockpitERSDelivery),                'info' },
    { 'ERS Recov',  formatOnOff(car and car.hasCockpitERSRecovery),                'info' },
  }

  self.quickChatRows = {}
  for i = 1, 6 do
    local message = self.storage['quickChat' .. i]
    if message and message ~= '' then
      table.insert(self.quickChatRows, {
        tostring(i),
        message,
        'info',
      })
    end
  end
  self.selectedQuickChatRow = math.max(0, math.min(self.selectedQuickChatRow or 0, math.max(0, #self.quickChatRows)))

  self.pages = {
    { title = 'Systems', rows = self.systemsRows, kind = 'systems' },
  }

  if car and ((car.mgukDeliveryCount or 0) > 0 or car.hasCockpitMGUHMode or car.hasCockpitERSDelivery or car.hasCockpitERSRecovery) then
    table.insert(self.pages, { title = 'MGU', rows = self.mguRows, kind = 'mgu' })
  end

  if pitstopSupported then
    table.insert(self.pages, { title = 'Pit', kind = 'pit' })
  end

  table.insert(self.pages, { title = 'Weather', rows = self.weatherRows })
  table.insert(self.pages, { title = 'Race', rows = self.raceRows })
  table.insert(self.pages, { title = 'Fuel', rows = self.fuelRows })
  table.insert(self.pages, { title = 'Tyres', kind = 'tyres' })

  if self.quickChatAvailable then
    table.insert(self.pages, { title = 'Chat', kind = 'chat' })
  end

  if car and (car.kersPresent or (car.kersMaxKJ or 0) > 0) then
    table.insert(self.pages, { title = 'KERS', rows = self.kersRows, kind = 'kers' })
  end

  self.currentPage = clampPageIndex(self.currentPage, #self.pages)
  local currentPage = self.pages[self.currentPage]
  if currentPage and currentPage.kind == 'chat' and #self.quickChatRows > 0 and (self.selectedQuickChatRow or 0) == 0 then
    self.selectedQuickChatRow = 1
  end
end

function PanelWidget:drawHeader(panelPos, panelWidth, headerHeight, font, colors, scale, highlighted)
  local page = self.pages[self.currentPage]
  local title = page and page.title or 'Panel'
  if page and page.kind == 'pit' then
    title = string.format('Pit (%s)', formatPitTime(self.currentPitTotalEstimate or 0))
  end
  if highlighted then
    ui.drawRectFilled(panelPos + vec2(4 * scale, 2 * scale), panelPos + vec2(panelWidth - 4 * scale, headerHeight),
      colors.selection, 5 * scale)
  end
  ui.dwriteDrawTextClipped(title, font.size * 0.92 * scale, panelPos + vec2(38 * scale, 0),
    panelPos + vec2(panelWidth - 38 * scale, headerHeight), ui.Alignment.Center, ui.Alignment.Center, false, colors
    .title)

  ui.setCursor(panelPos + vec2(6 * scale, 4 * scale))
  if ui.button('<', vec2(24 * scale, 18 * scale)) then
    self:previousPage()
  end

  ui.setCursor(panelPos + vec2(panelWidth - 30 * scale, 4 * scale))
  if ui.button('>', vec2(24 * scale, 18 * scale)) then
    self:nextPage()
  end
end

function PanelWidget:drawPageDots(panelPos, panelWidth, panelHeight, colors, scale)
  local spacing = 10 * scale
  local radius = 2.5 * scale
  local totalWidth = (#self.pages - 1) * spacing
  local startX = panelPos.x + panelWidth * 0.5 - totalWidth * 0.5
  local y = panelPos.y + panelHeight - 8 * scale

  for i = 1, #self.pages do
    local center = vec2(startX + (i - 1) * spacing, y)
    local color = i == self.currentPage and colors.label or colors.pageDot
    ui.drawCircleFilled(center, radius, color, 12)
  end
end

function PanelWidget:drawColumn(rows, panelPos, headerHeight, width, font, colors, scale)
  local rowHeight = PANEL_ROW_HEIGHT * scale
  local start = panelPos + vec2(8 * scale, headerHeight + 6 * scale)
  local rowWidth = width - 16 * scale

  for i = 1, #rows do
    local pos = start + vec2(0, (i - 1) * rowHeight)
    local rowA = pos
    local rowB = pos + vec2(rowWidth, rowHeight - 2 * scale)
    local accent = resolvePanelAccent(colors, rows[i][3])

    if i % 2 == 1 then
      ui.drawRectFilled(rowA, rowB, colors.rowStripe, 4 * scale)
    end

    ui.dwriteDrawTextClipped(rows[i][1], font.size * 0.82 * scale,
      rowA + vec2(8 * scale, 0), rowA + vec2(rowWidth * 0.42, rowHeight - 2 * scale),
      ui.Alignment.Start, ui.Alignment.Center, false, colors.label)

    ui.dwriteDrawTextClipped(rows[i][2], font.size * scale,
      rowA + vec2(rowWidth * 0.42, 0), rowB - vec2(8 * scale, 0),
      ui.Alignment.End, ui.Alignment.Center, false, accent)
  end
end

function PanelWidget:drawGauge(label, value, valueText, pos, width, font, colors, accent, scale)
  local rowHeight = PANEL_GAUGE_ROW_HEIGHT * scale
  local labelWidth = 60 * scale
  local gaugeHeight = 8 * scale
  local gaugeWidth = width - labelWidth - 60 * scale
  local gaugePos = pos + vec2(labelWidth, rowHeight * 0.5 - gaugeHeight * 0.5)
  local gaugeEnd = gaugePos + vec2(gaugeWidth, gaugeHeight)
  local fill = math.max(0, math.min(1, value or 0))

  ui.dwriteDrawTextClipped(label, font.size * 0.82 * scale,
    pos + vec2(8 * scale, 0), pos + vec2(labelWidth - 6 * scale, rowHeight),
    ui.Alignment.Start, ui.Alignment.Center, false, colors.label)

  ui.drawRectFilled(gaugePos, gaugeEnd, colors.gaugeBackground, 3 * scale)
  if fill > 0 then
    ui.drawRectFilled(gaugePos, gaugePos + vec2(gaugeWidth * fill, gaugeHeight), accent, 3 * scale)
  end
  ui.drawRect(gaugePos, gaugeEnd, colors.border, 3 * scale)

  ui.dwriteDrawTextClipped(valueText, font.size * 0.82 * scale,
    pos + vec2(labelWidth + gaugeWidth + 8 * scale, 0), pos + vec2(width - 8 * scale, rowHeight),
    ui.Alignment.End, ui.Alignment.Center, false, accent)

  return rowHeight
end

function PanelWidget:drawKersPage(panelPos, headerHeight, width, font, colors, scale)
  local car = self.currentCar
  if not car then
    return
  end

  local start = panelPos + vec2(8 * scale, headerHeight + 8 * scale)
  local rowWidth = width - 16 * scale
  local y = start.y

  y = y + self:drawGauge('Charge', car.kersCharge or 0, formatPercent(car.kersCharge or 0, 100),
    vec2(start.x, y), rowWidth, font, colors, colors.valueStatic, scale)
  y = y + self:drawGauge('Input', car.kersInput or 0, formatPercent(car.kersInput or 0, 100),
    vec2(start.x, y), rowWidth, font, colors, colors.valueStatic, scale)
  y = y + self:drawGauge('Load', car.kersLoad or 0, formatPercent(car.kersLoad or 0, 100),
    vec2(start.x, y), rowWidth, font, colors, colors.valueStatic, scale)

  local infoRows = {
    { 'Current',  formatValue(car.kersCurrentKJ or 0, '%.1f kJ'), 'info' },
    { 'Max',      formatValue(car.kersMaxKJ or 0, '%.1f kJ'),     'info' },
    { 'Charging', formatOnOff(car.kersCharging),                  'info' },
  }

  self:drawColumn(infoRows, vec2(panelPos.x, y - 4 * scale), 0, width, font, colors, scale)
end

function PanelWidget:drawSystemsPage(panelPos, headerHeight, width, font, colors, scale)
  local rowHeight = PANEL_ROW_HEIGHT * scale
  local start = panelPos + vec2(8 * scale, headerHeight + 6 * scale)
  local rowLeft = start.x
  local rowRight = panelPos.x + width - 15 * scale
  local rowWidth = rowRight - rowLeft
  local buttonSize = vec2(18 * scale, 16 * scale)
  local rightButtonLeft = rowRight - buttonSize.x
  local controlsLeft = rightButtonLeft - buttonSize.x - 46 * scale
  local valueLeft = controlsLeft + buttonSize.x + 1 * scale
  local valueRight = rightButtonLeft - 4 * scale
  local labelRight = valueLeft - 30 * scale
  local canEditSystems = self.currentCar and (self.currentCar.isUserControlled or self.currentCar.index == 0)

  for i = 1, #self.systemsRows do
    local pos = start + vec2(0, (i - 1) * rowHeight)
    local rowA = pos
    local rowB = pos + vec2(rowWidth, rowHeight - 2 * scale)
    local accent = resolvePanelAccent(colors, self.systemsRows[i][3])
    local isAdjustable = canEditSystems and self.systemsRows[i][4] ~= nil

    if (self.selectedSystemsRow or 0) == i then
      ui.drawRectFilled(rowA, rowB, colors.selection, 4 * scale)
    elseif i % 2 == 1 then
      ui.drawRectFilled(rowA, rowB, colors.rowStripe, 4 * scale)
    end

    ui.dwriteDrawTextClipped(self.systemsRows[i][1], font.size * 0.82 * scale,
      rowA + vec2(8 * scale, 0), vec2(labelRight, rowA.y + rowHeight - 2 * scale),
      ui.Alignment.Start, ui.Alignment.Center, false, colors.label)

    if isAdjustable then
      ui.pushID('sys' .. tostring(i))

      ui.setCursor(vec2(controlsLeft, pos.y + 1 * scale))
      if ui.button('-##sysDec', buttonSize) then
        self.selectedSystemsRow = i
        self:adjustSelectedSystem(-1)
      end

      ui.dwriteDrawTextClipped(self.systemsRows[i][2], font.size * scale,
        vec2(valueLeft, pos.y), vec2(valueRight, pos.y + rowHeight - 2 * scale),
        ui.Alignment.Center, ui.Alignment.Center, false, accent)

      ui.setCursor(vec2(rightButtonLeft, pos.y + 1 * scale))
      if ui.button('+##sysInc', buttonSize) then
        self.selectedSystemsRow = i
        self:adjustSelectedSystem(1)
      end

      ui.popID()
    else
      ui.dwriteDrawTextClipped(self.systemsRows[i][2], font.size * scale,
        vec2(valueLeft, pos.y), vec2(valueRight, pos.y + rowHeight - 2 * scale),
        ui.Alignment.End, ui.Alignment.Center, false, accent)
    end
  end
end

function PanelWidget:drawMguPage(panelPos, headerHeight, width, font, colors, scale)
  local rowHeight = PANEL_ROW_HEIGHT * scale
  local start = panelPos + vec2(8 * scale, headerHeight + 6 * scale)
  local rowLeft = start.x
  local rowRight = panelPos.x + width - 15 * scale
  local rowWidth = rowRight - rowLeft
  local buttonSize = vec2(18 * scale, 16 * scale)
  local rightButtonLeft = rowRight - buttonSize.x
  local controlsLeft = rightButtonLeft - buttonSize.x - 46 * scale
  local valueLeft = controlsLeft + buttonSize.x + 1 * scale
  local valueRight = rightButtonLeft - 4 * scale
  local labelRight = valueLeft - 30 * scale
  local canEditMgu = self.currentCar and (self.currentCar.isUserControlled or self.currentCar.index == 0)

  for i = 1, #self.mguRows do
    local pos = start + vec2(0, (i - 1) * rowHeight)
    local rowA = pos
    local rowB = pos + vec2(rowWidth, rowHeight - 2 * scale)
    local accent = resolvePanelAccent(colors, self.mguRows[i][3])
    local isAdjustable = canEditMgu and self.mguRows[i][4] ~= nil

    if (self.selectedMguRow or 0) == i then
      ui.drawRectFilled(rowA, rowB, colors.selection, 4 * scale)
    elseif i % 2 == 1 then
      ui.drawRectFilled(rowA, rowB, colors.rowStripe, 4 * scale)
    end

    ui.dwriteDrawTextClipped(self.mguRows[i][1], font.size * 0.82 * scale,
      rowA + vec2(8 * scale, 0), vec2(labelRight, rowA.y + rowHeight - 2 * scale),
      ui.Alignment.Start, ui.Alignment.Center, false, colors.label)
    if DEBUG_MGU_BOUNDS then
      ui.drawRect(rowA + vec2(8 * scale, 0), vec2(labelRight, rowA.y + rowHeight - 2 * scale), rgbm(1, 0, 0, 1), 0, nil, 1)
    end

    if isAdjustable then
      ui.pushID('mgu' .. tostring(i))

      ui.setCursor(vec2(controlsLeft, pos.y + 1 * scale))
      if ui.button('-##mguDec', buttonSize) then
        self.selectedMguRow = i
        self:adjustSelectedMgu(-1)
      end
      if DEBUG_MGU_BOUNDS then
        ui.drawRect(vec2(controlsLeft, pos.y + 1 * scale), vec2(controlsLeft, pos.y + 1 * scale) + buttonSize, rgbm(1, 0, 0, 1), 0, nil, 1)
      end

      ui.dwriteDrawTextClipped(self.mguRows[i][2], font.size * scale,
        vec2(valueLeft, pos.y), vec2(valueRight, pos.y + rowHeight - 2 * scale),
        ui.Alignment.Center, ui.Alignment.Center, false, accent)
      if DEBUG_MGU_BOUNDS then
        ui.drawRect(vec2(valueLeft, pos.y), vec2(valueRight, pos.y + rowHeight - 2 * scale), rgbm(1, 0, 0, 1), 0, nil, 1)
      end

      ui.setCursor(vec2(rightButtonLeft, pos.y + 1 * scale))
      if ui.button('+##mguInc', buttonSize) then
        self.selectedMguRow = i
        self:adjustSelectedMgu(1)
      end
      if DEBUG_MGU_BOUNDS then
        ui.drawRect(vec2(rightButtonLeft, pos.y + 1 * scale), vec2(rightButtonLeft, pos.y + 1 * scale) + buttonSize, rgbm(1, 0, 0, 1), 0, nil, 1)
      end

      ui.popID()
    else
      ui.dwriteDrawTextClipped(self.mguRows[i][2], font.size * scale,
        vec2(valueLeft, pos.y), vec2(valueRight, pos.y + rowHeight - 2 * scale),
        ui.Alignment.End, ui.Alignment.Center, false, accent)
      if DEBUG_MGU_BOUNDS then
        ui.drawRect(vec2(valueLeft, pos.y), vec2(valueRight, pos.y + rowHeight - 2 * scale), rgbm(1, 0, 0, 1), 0, nil, 1)
      end
    end
  end
end

local function tyreTempColor(style, tempC, optimumC, performanceRatio, idealMinTemp, idealMaxTemp)
  local function mix(a, b, t)
    return a + (b - a) * t
  end

  if tempC <= 0 or optimumC <= 0 then
    return style.tyres.tempUnknown
  end

  local cold = style.tyres.tempCold
  local ideal = style.tyres.tempIdeal
  local hot = style.tyres.tempHot
  local rangeMin = idealMinTemp and idealMinTemp > 0 and idealMinTemp or optimumC
  local rangeMax = idealMaxTemp and idealMaxTemp > 0 and idealMaxTemp or optimumC
  if rangeMax < rangeMin then
    rangeMin, rangeMax = rangeMax, rangeMin
  end
  local coldTransition = performanceRatio ~= nil and 6 or 5
  local hotTransition = performanceRatio ~= nil and 6 or 5

  if tempC < rangeMin then
    local t = math.max(0, math.min(1, (tempC - (rangeMin - coldTransition)) / coldTransition))
    return rgbm(
      mix(cold.r, ideal.r, t),
      mix(cold.g, ideal.g, t),
      mix(cold.b, ideal.b, t),
      1
    )
  end

  if tempC <= rangeMax then
    return ideal
  end

  local t = math.max(0, math.min(1, (tempC - rangeMax) / hotTransition))
  return rgbm(
    mix(ideal.r, hot.r, t),
    mix(ideal.g, hot.g, t),
    mix(ideal.b, hot.b, t),
    1
  )
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function tyreWearColor(style, wear, wearGrip)
  if wearGrip ~= nil then
    if wearGrip > 98 then
      return style.tyres.wearGood
    elseif wearGrip > 96 then
      return style.tyres.wearWarn
    else
      return style.tyres.wearBad
    end
  end

  local t = math.max(0, math.min(1, wear or 0))
  local good = style.tyres.wearGood
  local bad = style.tyres.wearBad
  return rgbm(
    lerp(good.r, bad.r, t),
    lerp(good.g, bad.g, t),
    lerp(good.b, bad.b, t),
    1
  )
end

function PanelWidget:drawTyreBlock(label, wheel, pos, size, font, colors, scale, useFahrenheit)
  if wheel.isBlown then
    ui.drawRectFilled(pos, pos + size, colors.backgroundAlt, 8 * scale)
    ui.drawRect(pos, pos + size, self.style.damage.bad, 8 * scale)
    ui.dwriteDrawTextClipped('BLOWN', font.size * 1.1 * scale,
      pos + vec2(4 * scale, 0), pos + vec2(size.x - 4 * scale, size.y),
      ui.Alignment.Center, ui.Alignment.Center, false, colors.valueNegative)

    return {
      wear = math.max(0, math.min(1, wheel.wear or 0)),
      wearBarWidth = 8 * scale,
      remaining = math.max(0, math.min(1, 1 - (wheel.wear or 0))),
    }
  end

  local optimum = (wheel.idealTemp and wheel.idealTemp > 0) and wheel.idealTemp or (wheel.optimum or 0)
  local fill = tyreTempColor(self.style, wheel.core or 0, optimum, wheel.performanceRatio, wheel.idealMinTemp,
    wheel.idealMaxTemp)
  local wear = math.max(0, math.min(1, wheel.wear or 0))
  local remaining = 1 - wear
  local wearBarWidth = 8 * scale
  local textColor = colors.valueNeutral
  local slipColor = self.style.tyres.slip
  ui.drawRectFilled(pos, pos + size, fill, 8 * scale)
  ui.drawRect(pos, pos + size, colors.border, 8 * scale)

  if wheel.isSlipping then
    ui.drawRectFilled(pos - vec2(1, 1) * scale, pos + size + vec2(1, 1) * scale,
      rgbm(slipColor.r, slipColor.g, slipColor.b, 0.18), 9 * scale)
    ui.drawRectFilled(pos, pos + size, rgbm(slipColor.r, slipColor.g, slipColor.b, 0.30), 8 * scale)
    ui.drawRect(pos - vec2(1, 1) * scale, pos + size + vec2(1, 1) * scale, slipColor, 9 * scale, nil, 2)
    ui.drawRect(pos, pos + size, rgbm(slipColor.r, slipColor.g, slipColor.b, 0.95), 8 * scale, nil, 2)
  end

  ui.dwriteDrawTextClipped(formatTemperature(wheel.core or 0, useFahrenheit), font.size * scale,
    pos + vec2(4 * scale, 4 * scale), pos + vec2(size.x - 4 * scale, 22 * scale),
    ui.Alignment.Center, ui.Alignment.Center, false, textColor)

  ui.dwriteDrawTextClipped(formatTyrePressure(wheel.pressure or 0), font.size * scale,
    pos + vec2(6 * scale, size.y * 0.31), pos + vec2(size.x - 6 * scale, size.y * 0.58),
    ui.Alignment.Center, ui.Alignment.Center, false, textColor)

  ui.dwriteDrawTextClipped(formatPressureDelta(wheel.pressureDelta or 0), font.size * scale,
    pos + vec2(6 * scale, size.y * 0.54), pos + vec2(size.x - 6 * scale, size.y - 6 * scale),
    ui.Alignment.Center, ui.Alignment.Center, false, textColor)

  return {
    wear = wear,
    wearBarWidth = wearBarWidth,
    remaining = remaining,
  }
end

function PanelWidget:drawTyresPage(panelPos, headerHeight, width, font, colors, scale, useFahrenheit)
  if not self.tyreDataAvailable then
    self:drawColumn({
      { 'Tyres',  'N/A',             'text' },
      { 'Reason', 'Player car only', 'title' },
    }, panelPos, headerHeight, width, font, colors, scale)
    return
  end

  local start = panelPos + vec2(30 * scale, headerHeight + 23 * scale)
  local gap = 20 * scale
  local gapY = 14 * scale
  local blockSize = vec2((width - 60 * scale - gap) * 0.5, 72 * scale)
  local positions = {
    start,
    start + vec2(blockSize.x + gap, 0),
    start + vec2(0, blockSize.y + gapY),
    start + vec2(blockSize.x + gap, blockSize.y + gapY),
  }

  local compound = formatTyreCompound(self.currentCar)
  ui.dwriteDrawTextClipped(compound, font.size * 0.76 * scale,
    panelPos + vec2(12 * scale, headerHeight), panelPos + vec2(width - 12 * scale, headerHeight + 18 * scale),
    ui.Alignment.Center, ui.Alignment.Center, false, colors.valueStatic)

  for i = 1, 4 do
    local wheel = self.wheelData[i] or {}
    local wearData = self:drawTyreBlock(nil, wheel, positions[i], blockSize, font, colors, scale, useFahrenheit)
    local barOnLeft = i == 1 or i == 3
    local barPos = barOnLeft
        and (positions[i] - vec2(wearData.wearBarWidth + 4 * scale, 0))
        or (positions[i] + vec2(blockSize.x + 4 * scale, 0))
    local barSize = vec2(wearData.wearBarWidth, blockSize.y)

    if wearData.remaining > 0 then
      local fillTop = barPos.y + barSize.y * (1 - wearData.remaining)
      ui.drawRectFilled(vec2(barPos.x, fillTop), barPos + barSize, tyreWearColor(self.style, wearData.wear, wheel.wearGrip),
        3 * scale)
    end
    ui.drawRect(barPos, barPos + barSize, self.style.tyres.wearOutline, 3 * scale)
  end
end

function PanelWidget:drawPitPage(dt, panelPos, headerHeight, width, font, colors, scale)
  if not pitstopSupported then
    self:drawColumn({
      { 'Pit', 'CSP 0.2.11+', 'text' },
    }, panelPos, headerHeight, width, font, colors, scale)
    return
  end

  if not self.pitstopAvailable then
    self:drawColumn({
      { 'Pit',    'N/A',             'text' },
      { 'Reason', 'Player car only', 'title' },
    }, panelPos, headerHeight, width, font, colors, scale)
    return
  end

  local start = panelPos + vec2(8 * scale, headerHeight + 8 * scale)
  local rowLeft = start.x
  local rowRight = panelPos.x + width - 15 * scale
  local rowWidth = rowRight - rowLeft
  local rowHeight = PANEL_ROW_HEIGHT * scale
  local buttonSize = vec2(18 * scale, 16 * scale)
  local buttonGap = 2 * scale
  local plusButtonLeft = rowRight - buttonSize.x
  local minusButtonLeft = plusButtonLeft - buttonSize.x - 46 * scale
  local valueLeft = minusButtonLeft + buttonSize.x + 1 * scale
  local valueRight = plusButtonLeft - 4 * scale
  local labelLeft = rowLeft + 8 * scale
  local labelRight = valueLeft - 30 * scale
  local y = start.y
  local holdActive = false

  if (self.selectedPitRow or 0) == 1 then
    ui.drawRectFilled(vec2(rowLeft, y), vec2(rowRight, y + rowHeight), colors.selection, 4 * scale)
  end
  ui.dwriteDrawTextClipped('Preset', font.size * 0.82 * scale,
    vec2(labelLeft, y), vec2(labelRight, y + rowHeight),
    ui.Alignment.Start, ui.Alignment.Center, false, colors.label)


  ui.setCursor(vec2(minusButtonLeft, y + 2 * scale))
  if ui.button('<##pitPresetPrev', buttonSize) then
    local targetPreset = math.max(0, self.pitstopPreset - 1)
    if ac.setCurrentQuickPitPreset(targetPreset) then
      self:setPitstopPreset(targetPreset)
    end
  end
  holdActive = self:processPitButtonHold('pit_preset_prev', dt, function()
    local targetPreset = math.max(0, self.pitstopPreset - 1)
    if ac.setCurrentQuickPitPreset(targetPreset) then
      self:setPitstopPreset(targetPreset)
    end
  end) or holdActive

  ui.dwriteDrawTextClipped(string.format('%d / 3', (self.pitstopPreset or 0) + 1), font.size * 0.92 * scale,
    vec2(valueLeft, y), vec2(valueRight, y + rowHeight),
    ui.Alignment.Center, ui.Alignment.Center, false, colors.valueEdit)

  ui.setCursor(vec2(plusButtonLeft, y + 1 * scale))
  if ui.button('>##pitPresetNext', buttonSize) then
    local targetPreset = math.min(2, self.pitstopPreset + 1)
    if ac.setCurrentQuickPitPreset(targetPreset) then
      self:setPitstopPreset(targetPreset)
    end
  end
  holdActive = self:processPitButtonHold('pit_preset_next', dt, function()
    local targetPreset = math.min(2, self.pitstopPreset + 1)
    if ac.setCurrentQuickPitPreset(targetPreset) then
      self:setPitstopPreset(targetPreset)
    end
  end) or holdActive

  y = y + rowHeight + 4 * scale

  if #self.pitstopSpinners == 0 then
    self:drawColumn({
      { 'Quick Pit', 'No data', 'text' },
    }, vec2(panelPos.x, y - 2 * scale), 0, width, font, colors, scale)
    return
  end

  local visibleSpinners = self:getVisiblePitstopSpinners()
  local estimates = select(1, self:calculatePitEstimates())

  for i = 1, #visibleSpinners do
    local spinner = visibleSpinners[i]
    local estimate = estimates[i] or 0
    local rowA = vec2(rowLeft, y)
    local rowB = rowA + vec2(rowWidth, rowHeight)

    if (self.selectedPitRow or 0) == i + 1 then
      ui.drawRectFilled(rowA, rowB, colors.selection, 4 * scale)
    elseif i % 2 == 1 then
      ui.drawRectFilled(rowA, rowB, colors.rowStripe, 4 * scale)
    end

    local label = formatPitstopName(spinner.name)
    if estimate > 0 then
      label = string.format('%s (%s)', label, formatPitTime(estimate))
    end
    local labelMin = vec2(labelLeft, y)
    local labelMax = vec2(labelRight, y + rowHeight)
    ui.dwriteDrawTextClipped(label, font.size * 0.74 * scale,
      labelMin, labelMax,
      ui.Alignment.Start, ui.Alignment.Center, false, colors.label)

    ui.pushID(spinner.name .. tostring(i))

    if not spinner.readOnly then
      ui.setCursor(vec2(minusButtonLeft, y + 1 * scale))
      if ui.button('-##pitDec', buttonSize) then
        self.selectedPitRow = i + 1
        self:adjustSelectedPitSpinner(-1)
      end
      holdActive = self:processPitButtonHold('pit_dec_' .. spinner.name .. '_' .. tostring(i), dt, function()
        self.selectedPitRow = i + 1
        self:adjustSelectedPitSpinner(-1)
      end) or holdActive
    end

    local valueMin = vec2(valueLeft, y)
    local valueMax = vec2(valueRight, y + rowHeight)
    ui.dwriteDrawTextClipped(formatPitstopValue(self.currentCar, spinner, self.pitstopPreset), font.size * 0.82 * scale,
      valueMin, valueMax,
      ui.Alignment.Center, ui.Alignment.Center, false, spinner.readOnly and colors.valueNeutral or colors.valueEdit)

    if not spinner.readOnly then
      ui.setCursor(vec2(plusButtonLeft, y + 1 * scale))
      if ui.button('+##pitInc', buttonSize) then
        self.selectedPitRow = i + 1
        self:adjustSelectedPitSpinner(1)
      end
      holdActive = self:processPitButtonHold('pit_inc_' .. spinner.name .. '_' .. tostring(i), dt, function()
        self.selectedPitRow = i + 1
        self:adjustSelectedPitSpinner(1)
      end) or holdActive
    end

    ui.popID()
    y = y + rowHeight + buttonGap
  end

  if not holdActive then
    self.pitHoldAction = nil
    self.pitHoldElapsed = 0
    self.pitHoldNext = 0
  end
end

function PanelWidget:sendSelectedQuickChat()
  if not self.quickChatAvailable or #self.quickChatRows == 0 then
    return
  end
  local row = self.quickChatRows[self.selectedQuickChatRow or 1]
  if (self.selectedQuickChatRow or 0) <= 0 then
    return
  end
  if not row or row[2] == '' then
    return
  end
  ac.sendChatMessage(row[2])
end

function PanelWidget:drawQuickChatPage(panelPos, headerHeight, width, font, colors, scale)
  if not self.quickChatAvailable then
    self:drawColumn({
      { 'Chat', 'Online only', 'text' },
    }, panelPos, headerHeight, width, font, colors, scale)
    return
  end

  if #self.quickChatRows == 0 then
    self:drawColumn({
      { 'Chat',  'No messages',               'text' },
      { 'Setup', 'Add messages in Panel HUD', 'title' },
    }, panelPos, headerHeight, width, font, colors, scale)
    return
  end

  local rowHeight = PANEL_ROW_HEIGHT * scale
  local start = panelPos + vec2(8 * scale, headerHeight + 6 * scale)
  local rowWidth = width - 16 * scale

  for i = 1, #self.quickChatRows do
    local pos = start + vec2(0, (i - 1) * rowHeight)
    local rowA = pos
    local rowB = pos + vec2(rowWidth, rowHeight - 2 * scale)
    local accent = resolvePanelAccent(colors, self.quickChatRows[i][3])

    if (self.selectedQuickChatRow or 0) == i then
      ui.drawRectFilled(rowA, rowB, colors.selection, 4 * scale)
    elseif i % 2 == 1 then
      ui.drawRectFilled(rowA, rowB, colors.rowStripe, 4 * scale)
    end

    ui.dwriteDrawTextClipped(self.quickChatRows[i][1], font.size * 0.82 * scale,
      rowA + vec2(8 * scale, 0), rowA + vec2(26 * scale, rowHeight - 2 * scale),
      ui.Alignment.Start, ui.Alignment.Center, false, colors.label)

    ui.dwriteDrawTextClipped(self.quickChatRows[i][2], font.size * 0.92 * scale,
      rowA + vec2(28 * scale, 0), rowB - vec2(8 * scale, 0),
      ui.Alignment.Start, ui.Alignment.Center, false, accent)
  end
end

function PanelWidget:draw(dt, drawContext)
  local scale = (drawContext.scale or 1) * (drawContext.panelScale or 1)
  local colors = drawContext.colors
  self.style = drawContext.style
  local font = drawContext.font
  local useMph = drawContext.speedUseMph or false
  local useFahrenheit = drawContext.weatherUseFahrenheit or false
  local useGallons = drawContext.fuelUseGallons or false

  if self.weatherRows[1] then
    self.weatherRows[1][2] = formatTemperature(self.currentAmbientC, useFahrenheit)
  end
  if self.weatherRows[2] then
    self.weatherRows[2][2] = formatTemperature(self.currentRoadC, useFahrenheit)
  end
  if self.weatherRows[3] then
    self.weatherRows[3][2] = formatWindSpeed(self.currentWindKmh, useMph)
  end
  if self.fuelRows[1] then
    self.fuelRows[1][2] = self.fuelDataAvailable and formatFuelUnit(self.currentFuelLiters, useGallons) or 'N/A'
  end
  if self.fuelRows[2] then
    self.fuelRows[2][2] = self.fuelDataAvailable and formatFuelUnit(self.currentFuelPerLap, useGallons) or 'N/A'
  end
  if self.fuelRows[4] then
    self.fuelRows[4][2] = self.fuelDataAvailable and
    formatRemainingTime((self.currentFuelPerLap > 0 and self.currentFuelReferenceLapTimeMs > 0)
      and ((self.currentFuelLiters / self.currentFuelPerLap) * self.currentFuelReferenceLapTimeMs) or 0) or 'N/A'
  end
  local panelPos = ui.getCursor()
  local panelWidth = 230 * scale
  local currentPage = self.pages[self.currentPage]
  local headerHeight = 22 * scale
  local panelHeight = 236 * scale
  local panelSize = vec2(panelWidth, panelHeight)

  ui.pushDWriteFont(font.police)
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(4 * scale, 4 * scale))

  ui.drawRectFilled(panelPos, panelPos + panelSize, colors.background, 8 * scale,
    ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)
  ui.drawRect(panelPos, panelPos + panelSize, colors.border, 8 * scale,
    ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)

  local page = currentPage
  local headerSelected = false
  if page and page.kind == 'chat' then
    headerSelected = (self.selectedQuickChatRow or 0) == 0
  end
  self:drawHeader(panelPos, panelWidth, headerHeight, font, colors, scale, headerSelected)

  if page then
    if page.kind == 'kers' then
      self:drawKersPage(panelPos, headerHeight, panelWidth, font, colors, scale)
    elseif page.kind == 'mgu' then
      self:drawMguPage(panelPos, headerHeight, panelWidth, font, colors, scale)
    elseif page.kind == 'systems' then
      self:drawSystemsPage(panelPos, headerHeight, panelWidth, font, colors, scale)
    elseif page.kind == 'chat' then
      self:drawQuickChatPage(panelPos, headerHeight, panelWidth, font, colors, scale)
    elseif page.kind == 'pit' then
      self:drawPitPage(dt, panelPos, headerHeight, panelWidth, font, colors, scale)
    elseif page.kind == 'tyres' then
      self:drawTyresPage(panelPos, headerHeight, panelWidth, font, colors, scale, useFahrenheit)
    else
      self:drawColumn(page.rows, panelPos, headerHeight, panelWidth, font, colors, scale)
    end
  end

  self:drawPageDots(panelPos, panelWidth, panelHeight, colors, scale)

  ui.dummy(panelSize)
  ui.popStyleVar()
  ui.popDWriteFont()
end

return PanelWidget
