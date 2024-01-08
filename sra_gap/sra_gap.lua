require('classes/settings')
require('classes/car')

local config = Settings()


local isInitialized = false
local CARS = {}
local sf = string.format
local counter = 0
local currentSessionIndex = 0
local currentSessionType = 0
local isSessionStarted = false

local function initialize()
  CARS = {}
  for i = 0, ac.getSim().carsCount - 1 do
    CARS[i + 1] = CarsInfo(i);
  end
  isInitialized = true
  currentSessionIndex = ac.getSim().currentSessionIndex
  isSessionStarted = false
  currentSessionType = ac.getSim().raceSessionType
  ac.debug('Initialized', ac.getSim().time)
end

if ac.onSessionStart then
  ac.onSessionStart(function()
    initialize()
  end)
end

local function drawLine(text, lenght, fontColor, bgColor, align)
  local fontSize = 16 * config.scale
  local height = fontSize + 7
  lenght = lenght * config.scale
  ui.drawRectFilled(ui.getCursor(), ui.getCursor() + vec2(lenght, height), bgColor)
  local start = ui.getCursor()
  start.x = start.x + 2
  ui.dwriteDrawTextClipped(text, fontSize, start, start + vec2(lenght - 4, height),
    align, ui.Alignment.Center, false, fontColor)
  ui.dummy(vec2(lenght, height))
end

local function drawList(car, gap, pos)
  ui.pushDWriteFont('OneSlot:\\fonts\\.')
  local fontColor = rgbm.colors.white
  if not car.isActive then
    fontColor = rgbm.colors.gray
  end
  drawLine(sf("%02d", pos), 25, fontColor, rgbm.colors.red, ui.Alignment.Center)
  ui.sameLine()
  drawLine(car.nickName, 150, fontColor, rgbm.colors.cyan, ui.Alignment.Start)
  ui.sameLine()
  drawLine(sf("%02d", car.laps), 30, fontColor, rgbm.colors.cyan, ui.Alignment.Center)
  ui.sameLine()
  if config.bestLap then
    drawLine(ac.lapTimeToString(car.bestLapTimeMs), 70, fontColor, rgbm.colors.cyan, ui.Alignment.End)
    ui.sameLine()
  end
  if config.lastLap then
    drawLine(ac.lapTimeToString(car.previousLapTimeMs), 70, fontColor, rgbm.colors.cyan, ui.Alignment.End)
    ui.sameLine()
  end
  if config.tyres then
    drawLine(car.tyreName, 30, fontColor, rgbm.colors.gray, ui.Alignment.Center)
    ui.sameLine()
  end
  drawLine(gap, 70, fontColor, rgbm.colors.orange, ui.Alignment.End)
  if car.inPit then
    ui.sameLine()
    drawLine("P", 20, rgbm.colors.black, rgbm.colors.white, ui.Alignment.Center)
  end
  ui.popDWriteFont()
end

function script.windowMain(dt)
  local pos = ac.getCar(0).racePosition
  local show = config.carCount
  local nombre = math.max(pos - show, 1)
  local min = math.max(math.min(nombre, #CARS + 1), 0)
  local max = math.max(math.min(min + (show + show), #CARS), 0)

  ui.pushStyleVar(ui.StyleVar.ItemSpacing, 1)
  for i = min, max do
    local gap = ''
    if currentSessionType == ac.SessionType.Race then
      if i > 1 and CARS[i].isActive then
        if not CARS[i].inPit then
          gap = getRealGapStr(CARS[i - 1], CARS[i])
        end
      end
    else
      if i > 1 and CARS[i].isActive then
        if not CARS[i].inPit and CARS[i].bestLapTimeMs ~= 0 then
          gap = getTimeGapStr(CARS[i - 1], CARS[i])
        end
      end
    end
    drawList(CARS[i], gap, i)
  end
  ui.popStyleVar()
end

function script.windowSetting(dt)
  config.scale = ui.slider('##Scale', config.scale, 1.0, 3.0, 'Scale: %1.1f')

  config.carCount = ui.slider('##CarCount', config.carCount, 1.0, 10.0, 'car: %1.0f')

  if ui.checkbox("Show Best Lap", config.bestLap) then
    config.bestLap = not config.bestLap
  end
  if ui.checkbox("Show Last Lap", config.lastLap) then
    config.lastLap = not config.lastLap
  end
  if ui.checkbox("Show Tyres", config.tyres) then
    config.tyres = not config.tyres
  end

  ui.separator()
  ui.setCursorX(210)
  if ui.iconButton(ui.Icons.Save, vec2(50, 0), 0, true, ui.ButtonFlags.Activable) then
    config:save()
  end
end

function script.update(dt)
  counter = counter + dt

  local sim = ac.getSim()

  if sim.currentSessionIndex ~= currentSessionIndex or sim.isSessionStarted ~= isSessionStarted then
    isInitialized = false
  end
  if not isInitialized then
    initialize()
  end
  if sim.isSessionStarted then
    isSessionStarted = true
  end

  for i = 0, #CARS - 1 do
    CARS[i + 1]:update(dt, ac.getCar(CARS[i + 1].id))
  end
  local raceSessionType = ac.getSim().raceSessionType
  if counter > 0.4 then
    if raceSessionType == ac.SessionType.Race then
      table.sort(CARS, function(car1, car2)
        return car1.racePosition < car2.racePosition
      end)
    elseif raceSessionType == ac.SessionType.Qualify or raceSessionType == ac.SessionType.Practice then
      table.sort(CARS, function(car1, car2)
        if car1.bestLapTimeMs == 0 and car2.bestLapTimeMs == 0 then
          return car1.racePosition < car2.racePosition
        elseif car1.bestLapTimeMs == car2.bestLapTimeMs then
          return car1.racePosition < car2.racePosition
        elseif car1.bestLapTimeMs == 0 then
          return false
        elseif car2.bestLapTimeMs == 0 then
          return true
        else
          return car1.bestLapTimeMs < car2.bestLapTimeMs
        end
      end)
    end
    counter = 0
  end
end
