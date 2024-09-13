--
-- Created by Wile64 on september 2024
--

local CARS = {}
local isInitialized = false
local currentSessionIndex = 0
local isSessionStarted = false

local formationLap = true
local screen = vec2(ac.getSim().windowWidth, ac.getSim().windowHeight)
local scale = screen.y / 1080
local fontSize = 35 * scale
local connectedCar = 0
local lapProgress = 1
local aheadDistance = 0
local focusedCarState = nil
local greenTimer = 3
local sideStr = 'left'
local speedLimte = ac.getSim().speedLimitKmh
local leaderIndex = 0
local startLinePast = false

local trackLengthM = ac.getSim().trackLengthM
local markLimiter = trackLengthM - 300
local markSide = trackLengthM - 800

local function initialize()
    isInitialized = true
    currentSessionIndex = ac.getSim().currentSessionIndex
    formationLap = true
    leaderIndex = 0
    lapProgress = 1
    CARS = {}
    for i = 0, ac.getSim().carsCount - 1 do
        local t = {}
        local c = ac.getCar(i)
        t.car = c
        t.index = i
        CARS[i + 1] = t
        if t.car.racePosition == 1 then
            leaderIndex = t.car.index
        end
    end
    greenTimer = 3
    startLinePast = false
    isInitialized = true
    isSessionStarted = false
    currentSessionIndex = ac.getSim().currentSessionIndex
    ac.log('Initialized')
end

if ac.onSessionStart then
    ac.onSessionStart(function()
        initialize()
    end)
end

if ac.onOnlineWelcome then
    ac.onOnlineWelcome(function()
        ac.log('onOnlineWelcome')
        -- Race started when connect
        if ac.getSim().isSessionStarted then
            formationLap = false
        end
    end)
end

local function drawGreen()
    local winSize = vec2(400, (fontSize * 2) * scale)
    local size = fontSize - 2
    ui.beginTransparentWindow('formationLapGreen', vec2((screen.x - winSize.x) / 2, screen.y / 4), winSize)
    for i = 0, 5 do
        ui.drawCircleFilled(vec2(size, 0) + vec2(size * (i * 2), size), size, rgbm.colors.green, size)
    end
    --ui.drawRect(0, winSize, rgbm.colors.red)
    ui.endTransparentWindow()
end

local function drawSpeedlimite()
    local winSize = vec2((fontSize * 2) * scale, (fontSize * 2) * scale)
    local size = fontSize
    ui.beginTransparentWindow('formationLapGreen', vec2((screen.x - winSize.x) / 1.89, screen.y / 2.6), winSize)
    ui.drawCircleFilled(vec2(size, size), size, rgbm.colors.red, size)
    ui.drawCircleFilled(vec2(size, size), size / 1.2, rgbm.colors.white, size)
    ui.dwriteDrawTextClipped(tostring(speedLimte), fontSize - 8, 0, winSize, ui.Alignment.Center,
        ui.Alignment.Center, false, rgbm.colors.blue)
    --ui.drawRect(0, winSize, rgbm.colors.red)
    ui.endTransparentWindow()
end

local function drawMessage(title, text)
    local winSize = vec2(400, (fontSize * 4) * scale)
    ui.beginTransparentWindow('formationLapMsg', vec2((screen.x - winSize.x) / 2, screen.y / 3), winSize)
    --ui.drawRect(0, winSize, rgbm.colors.red)
    ui.dwriteDrawTextClipped(title, fontSize, 0, vec2(winSize.x, fontSize * 1.5), ui.Alignment.Center,
        ui.Alignment.Start, false, rgbm.colors.blue)
    ui.drawLine(vec2(0, fontSize * 1.5), vec2(winSize.x, fontSize * 1.5), rgbm.colors.green, 4)
    --ui.drawRect(0, vec2(winSize.x, fontSize*1.5), rgbm.colors.red)
    --ui.drawRect(vec2(0, fontSize*1.5), winSize, rgbm.colors.green)
    ui.dwriteDrawTextClipped(text, fontSize - 8, vec2(0, fontSize * 1.6), winSize, ui.Alignment.Center,
        ui.Alignment.Start, false, rgbm.colors.white)
    ui.endTransparentWindow()
end

local function drawState(ahead)
    local winSize = vec2(150, (fontSize * 5) * scale)
    ui.beginTransparentWindow('formationLapState', vec2((screen.x - winSize.x) / 2, screen.y / 1.8), winSize)
    ui.drawRect(0, winSize, rgbm.colors.red)
    ui.dwriteDrawTextClipped("stay in the middle", fontSize / 2, 0, winSize, ui.Alignment.Center,
        ui.Alignment.Start, false, rgbm.colors.white)
    local lenMax = math.min(100, ahead) * 2
    local minAhead = fontSize * scale
    local carColor = rgbm.colors.green
    local carSize = vec2(fontSize, fontSize * 1.5)
    if lenMax < minAhead then
        carColor = rgbm.colors.red
    elseif lenMax >= winSize.y - (minAhead + carSize.y) then
        carColor = rgbm.colors.blue
    end
    local carPos = vec2((winSize.x - carSize.x) / 2, (1 + lenMax))
    ui.drawLine(vec2(5 * scale, minAhead), vec2(winSize.x - (5 * scale), minAhead), rgbm.colors.red, 4)
    ui.drawLine(vec2(5 * scale, winSize.y - (minAhead)), vec2(winSize.x - (5 * scale), winSize.y - (minAhead)),
        rgbm.colors.red, 4)
    ui.drawRectFilled(carPos, carPos + carSize, carColor)
    ui.endTransparentWindow()
end

function script.update(dt)
    local sim = ac.getSim()
    -- Check if online
    if not sim.isOnlineRace then return end

    -- check if Race
    if sim.raceSessionType ~= 3 then return end

    if sim.currentSessionIndex ~= currentSessionIndex then
        isInitialized = false
    end

    -- check if race started
    if not sim.isSessionStarted then return end
    isSessionStarted = true

    if not isInitialized then
        -- initialize one time on start
        initialize()
    end

    if not formationLap then return end

    if ac.getCar(0).splinePosition < 0.001 then
        startLinePast = true
    end

    -- update car data
    connectedCar = 0
    for i = 1, #CARS do
        CARS[i].car = ac.getCar(CARS[i].index)
        if CARS[i].car.isActive then
            connectedCar = connectedCar + 1
        end
    end

    focusedCarState = ac.getCar(0)

    local currentPositionM = CARS[leaderIndex].car.splinePosition * trackLengthM
    if currentPositionM <= markSide then
        lapProgress = 1
    elseif currentPositionM >= markLimiter then
        lapProgress = 3
    elseif currentPositionM >= markSide then
        lapProgress = 2
    end

    if CARS[leaderIndex].car.lapCount >= 1 then
        lapProgress = 4
        greenTimer = 1
    end
    if lapProgress == 3 then
        if focusedCarState.speedKmh > speedLimte + 2 then
            physics.setCarPenalty(ac.PenaltyType.MandatoryPits, 5)
        end
    end

    if focusedCarState.racePosition > 1 and connectedCar > 1 then
        --    local gap = ac.getGapBetweenCars(CARS[focusedState.racePosition - 1].car.index, focusedState.index)
        --    ui.text(string.format('gap before %0.3f', gap))
        aheadDistance = focusedCarState.position:distance(CARS[focusedCarState.racePosition - 1].car.position)
    end
    if focusedCarState.racePosition % 2 == 0 then
        sideStr = "right"
    else
        sideStr = "left"
    end
end

function script.drawUI()
    if not formationLap then return end
    if not isSessionStarted then return end
    if not startLinePast then return end

    -- follow the leader's progress

    if lapProgress == 1 then
        drawMessage("Formation Lap", "Line up single file")
        -- last 400 meters on double file
    elseif lapProgress == 2 then
        drawMessage("Formation Lap", "Align on double file\n Keep " .. sideStr)
        -- last 200 meters with pit limiter
    elseif lapProgress == 3 then
        drawMessage("Formation Lap", "Speed Limiter on")
        drawSpeedlimite()
    end

    -- if the leader crosses the line, announces the GREEN FLAGS
    if lapProgress == 4 then
        drawMessage("Formation Lap", "Green flag Race start\ngo... go... go...")
        drawGreen()
        greenTimer = greenTimer - ui.deltaTime()

        if greenTimer <= 0 then
            formationLap = false
        end
    end
    -- Gap Calculation
    if focusedCarState ~= nil then
        if focusedCarState.racePosition > 1 and connectedCar > 1 then
            drawState(aheadDistance)
        end
    end
end
