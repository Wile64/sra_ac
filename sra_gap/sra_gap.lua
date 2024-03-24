require('classes/settings')
require('classes/car')

VERSION = 1.123
local config = Settings()


local isInitialized = false
local CARS = {}
local connectedCar = 0;
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

local function drawMyCar(car, gap, pos)
  ui.pushDWriteFont('OneSlot:\\fonts\\.')
  local fontColor = rgbm.colors.white

  local backColor = rgbm.colors.gray
  drawLine(sf("%02d", pos), 25, fontColor, rgbm.colors.red, ui.Alignment.Center)
  ui.sameLine()
  drawLine(car.nickName, 150, fontColor, backColor, ui.Alignment.Start)
  ui.sameLine()
  drawLine(sf("%02d", car.laps), 30, fontColor, backColor, ui.Alignment.Center)
  ui.sameLine()
  if config.bestLap then
    drawLine(ac.lapTimeToString(car.bestLapTimeMs), 70, fontColor, backColor, ui.Alignment.End)
    ui.sameLine()
  end
  if config.lastLap then
    if car.isLastLapValid then
      drawLine(ac.lapTimeToString(car.previousLapTimeMs), 70, fontColor, backColor, ui.Alignment.End)
    else
      drawLine(ac.lapTimeToString(car.previousLapTimeMs), 70, rgbm.colors.red, backColor, ui.Alignment.End)
    end
    ui.sameLine()
  end
  if gap == '' then
    drawLine(gap, 70, fontColor, backColor, ui.Alignment.End)
  else
    if gap < '1' then
      drawLine(gap, 70, fontColor, rgbm.colors.maroon, ui.Alignment.End)
    else
      drawLine(gap, 70, fontColor, rgbm.colors.olive, ui.Alignment.End)
    end
  end
  if config.tyres then
    ui.sameLine()
    drawLine(car.tyreName, 30, fontColor, rgbm.colors.gray, ui.Alignment.Center)
  end
  if car.inPit then
    ui.sameLine()
    drawLine("P", 20, rgbm.colors.black, rgbm.colors.white, ui.Alignment.Center)
  end
  ui.popDWriteFont()
end

local function drawList(car, gap, pos)
  ui.pushDWriteFont('OneSlot:\\fonts\\.')
  local fontColor = rgbm.colors.white
  local backColor = rgbm.colors.black

  drawLine(sf("%02d", pos), 25, rgbm.colors.black, rgbm.colors.white, ui.Alignment.Center)
  ui.sameLine()
  drawLine(car.nickName, 150, fontColor, backColor, ui.Alignment.Start)
  ui.sameLine()
  drawLine(sf("%02d", car.laps), 30, fontColor, backColor, ui.Alignment.Center)
  ui.sameLine()
  if config.bestLap then
    drawLine(ac.lapTimeToString(car.bestLapTimeMs), 70, fontColor, backColor, ui.Alignment.End)
    ui.sameLine()
  end
  if config.lastLap then
    if car.isLastLapValid then
      drawLine(ac.lapTimeToString(car.previousLapTimeMs), 70, fontColor, backColor, ui.Alignment.End)
    else
      drawLine(ac.lapTimeToString(car.previousLapTimeMs), 70, rgbm.colors.red, backColor, ui.Alignment.End)
    end
    ui.sameLine()
  end
  if gap == '' then
    drawLine(gap, 70, fontColor, backColor, ui.Alignment.End)
  else
    if gap < '1' then
      drawLine(gap, 70, fontColor, rgbm.colors.maroon, ui.Alignment.End)
    else
      drawLine(gap, 70, fontColor, rgbm.colors.olive, ui.Alignment.End)
    end
  end
  if config.tyres then
    ui.sameLine()
    drawLine(car.tyreName, 30, fontColor, rgbm.colors.gray, ui.Alignment.Center)
  end
  if car.inPit then
    ui.sameLine()
    drawLine("P", 20, rgbm.colors.black, rgbm.colors.white, ui.Alignment.Center)
  end
  ui.popDWriteFont()
end

function script.windowMain(dt)
  ac.setWindowTitle('windowGap', string.format('SRA Gap v%2.3f', VERSION))
  local pos = ac.getCar(0).racePosition
  local show = config.carCount
  local nombre = math.max(pos - show, 1)
  --  local min = math.max(math.min(nombre, connectedCar), 0)
  local min = math.max(nombre, 1)
  --local max = math.max(math.min(min + (show + show), connectedCar), 0)
  local max = math.min(pos + show, connectedCar)
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, 1)
  for i = min, max do
    if CARS[i].isActive then
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
      if CARS[i].id == 0 then
        drawMyCar(CARS[i], gap, i)
      else
        drawList(CARS[i], gap, i)
      end
    end
  end
  ui.popStyleVar()
end

function script.windowSetting(dt)
  config.scale = ui.slider('##Scale', config.scale, 1.0, 3.0, 'Scale: %1.1f')

  config.carCount = ui.slider('##CarCount', config.carCount, 1.0, 40.0, 'car: %1.0f')

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
  connectedCar = 0
  for i = 0, #CARS - 1 do
    CARS[i + 1]:update(dt, ac.getCar(CARS[i + 1].id))
    if CARS[i + 1].isActive then
      connectedCar = connectedCar + 1
    end
  end
  local raceSessionType = ac.getSim().raceSessionType
  if counter > 0.4 then
    if raceSessionType == ac.SessionType.Race then
      table.sort(CARS, function(car1, car2)
        if not car1.isActive and car2.isActive then
          return false
        elseif car1.isActive and not car2.isActive then
          return true
        else
          return car1.racePosition < car2.racePosition
        end
      end)
    elseif raceSessionType == ac.SessionType.Qualify or raceSessionType == ac.SessionType.Practice then
      table.sort(CARS, function(car1, car2)
        if not car1.isActive and car2.isActive then
          return false
        elseif car1.isActive and not car2.isActive then
          return true
        elseif car1.bestLapTimeMs == 0 and car2.bestLapTimeMs == 0 then
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
