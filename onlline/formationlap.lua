--
-- Created by Wile64 on september 2024
--

local CARS = {}
local isInitialized = false
local currentSessionIndex = 0
local meter = 1 / ac.getSim().trackLengthM
local formationLap = true
local screen = vec2(ac.getSim().windowWidth, ac.getSim().windowHeight)
local scale = screen.x / 1920 -- ui.windowSize().x / 1920
local fontSize = 20 * scale

local function initialize()
    isInitialized = true
    currentSessionIndex = ac.getSim().currentSessionIndex
    formationLap = true
    CARS = {}
    local index = 1
    for i, c in ac.iterateCars.leaderboard() do
        local t = {}
        t.car = c
        t.index = c.index
        CARS[index] = t
        index = index + 1
    end
    isInitialized = true
    currentSessionIndex = ac.getSim().currentSessionIndex
    ac.log('Initialized')
end

if ac.onSessionStart then
    ac.onSessionStart(function()
        initialize()
    end)
end

local function drawGreen()
    local uiState = ac.getUI()
    local size = 30
    ui.beginTransparentWindow('formationLapGreen', vec2(uiState.windowSize.x / 2.14, uiState.windowSize.y / 5),
        vec2(size * (2 * 6), size * 2))
    ui.drawRect(0, vec2(size * (2 * 6), size * 2), rgbm.colors.red)
    for i = 0, 5 do
        ui.drawCircleFilled(vec2(size, 0) + vec2(size * (i * 2), size), size, rgbm.colors.green, size)
    end
    ui.endTransparentWindow()
end

local function drawMessage(title, text)
    local uiState = ac.getUI()
    local size = 30
    ui.beginTransparentWindow('formationLapMsg', vec2(uiState.windowSize.x / 2.151, uiState.windowSize.y / 3),
        vec2(400, size * 5))
    --ui.drawRect(0, vec2(400, size * 5), rgbm.colors.red)
    --ui.drawRect(0, vec2(400, 45), rgbm.colors.green)
    ui.dwriteDrawTextClipped(title, size, 0, vec2(400, 45), ui.Alignment.Center,
        ui.Alignment.Start, false, rgbm.colors.blea)
    ui.drawLine(vec2(0, 45), vec2(400, 45), rgbm.colors.green, 4)
    --ui.drawRect(vec2(0, 45), vec2(400, 150), rgbm.colors.green)
    ui.dwriteDrawTextClipped(text, size - 3, vec2(0, 45), vec2(400, 150), ui.Alignment.Center,
        ui.Alignment.Start, false, rgbm.colors.white)
    ui.endTransparentWindow()
end

local function drawState(ahead)
    local winSize = vec2(150, fontSize * scale)
    ui.beginTransparentWindow('formationLapState', vec2((screen.x - winSize.x) / 2, screen.y / 2), winSize)
    ui.drawRect(0, winSize, rgbm.colors.red)
    ui.dwriteDrawTextClipped("stay in the middle", fontSize - 43, 0, winSize, ui.Alignment.Center,
        ui.Alignment.Start, false, rgbm.colors.white)
    local lenMax = math.min(50, ahead) * 2
    local minAhead = 8
    local carColor = rgbm.colors.green
    if lenMax < minAhead * scale then
        carColor = rgbm.colors.red
    elseif lenMax > winSize.y - (35 * scale) then
        carColor = rgbm.colors.blue
    end
    local carSize = vec2(15 * scale, 25 * scale)
    local carPos = vec2((winSize.x - carSize.x) / 2, (1 + lenMax))
    ui.drawLine(vec2(5 * scale, minAhead * scale), vec2(winSize.x - (5 * scale), minAhead * scale), rgbm.colors.red,
        1.3 * scale)
    ui.drawLine(vec2(5 * scale, winSize.y - (10 * scale)), vec2(winSize.x - (5 * scale), winSize.y - (10 * scale)),
        rgbm.colors.red, 4)
    ui.drawRectFilled(carPos, carPos + carSize, carColor)
    ui.endTransparentWindow()
end

function script.update(dt)
    local sim = ac.getSim()
    -- Check if online
    --if not sim.isOnlineRace then return end

    -- check if Race
    if sim.raceSessionType ~= 3 then return end

    if sim.currentSessionIndex ~= currentSessionIndex then
        isInitialized = false
    end

    if not isInitialized then
        -- initialize one time on start
        initialize()
    end

    -- check if race started
    if not sim.isSessionStarted then return end

    if not formationLap then return end

    -- update car data
    for i = 1, #CARS do
        CARS[i].car = ac.getCar(CARS[i].index)
    end

end

function script.drawUI()
    if not formationLap then return end
    local focused = ac.getCar(ac.getSim().focusedCar).racePosition
    local focusedState = CARS[focused].car
    local side
    if focusedState.racePosition % 2 == 0 then
        ui.text(string.format("Right State"))
        side = "right"
    else
        ui.text(string.format("Left State"))
        side = "left"
    end
    local uiState = ac.getUI()
    local size = 30
    ui.beginTransparentWindow('formationLapMsg', vec2(uiState.windowSize.x / 2.151, uiState.windowSize.y / 3),
        vec2(400, size * 5))
    if CARS[1].car.splinePosition <= (1 - (meter * 500)) then
        ui.dwriteDrawTextClipped("Formation Lap", size, 0, vec2(400, 45), ui.Alignment.Center,
        ui.Alignment.Start, false, rgbm.colors.blea)
        ui.dwriteDrawTextClipped("Line up single file", size - 3, vec2(0, 45), vec2(400, 150), ui.Alignment.Center,
        ui.Alignment.Start, false, rgbm.colors.white)
        -- last 400 meters on double file
    elseif CARS[1].car.splinePosition <= (1 - (meter * 400)) then
        ui.dwriteDrawTextClipped("Formation Lap", size, 0, vec2(400, 45), ui.Alignment.Center,
        ui.Alignment.Start, false, rgbm.colors.blea)
        ui.dwriteDrawTextClipped("Align on double\rfile Keep " .. side, size - 3, vec2(0, 45), vec2(400, 150), ui.Alignment.Center,
        ui.Alignment.Start, false, rgbm.colors.white)

        -- last 200 meters with pit limiter
    elseif CARS[1].car.splinePosition <= (1 - (meter * 200)) then
        ui.dwriteDrawTextClipped("Formation Lap", size, 0, vec2(400, 45), ui.Alignment.Center,
        ui.Alignment.Start, false, rgbm.colors.blea)
        ui.dwriteDrawTextClipped("Speed Limiter on", size - 3, vec2(0, 45), vec2(400, 150), ui.Alignment.Center,
        ui.Alignment.Start, false, rgbm.colors.white)        
    end
    ui.drawLine(vec2(0, 45), vec2(400, 45), rgbm.colors.green, 4)
    ui.endTransparentWindow()

    -- follow the leader's progress


    -- if the leader crosses the line, announces the GREEN FLAGS
    if CARS[1].car.lapCount >= 1 then
        drawMessage("Formation Lap", "Green flag Race start")
        drawGreen()
        formationLap = false
    end
    -- Gap Calculation
    if focusedState.racePosition > 1 then
        --    local gap = ac.getGapBetweenCars(CARS[focusedState.racePosition - 1].car.index, focusedState.index)
        --    ui.text(string.format('gap before %0.3f', gap))
        local ahead = focusedState.position:distance(CARS[focusedState.racePosition - 1].car.position)
        drawState(ahead)
    end
end
