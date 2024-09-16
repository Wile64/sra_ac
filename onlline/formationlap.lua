--
-- Created by Wile64 on september 2024
--

-- Enable or disable the debug mode
DEBUG = false
-- List of all cars
local leaderboard = {}
-- Is variables Initialized ?
local isInitialized = false
-- Current session index
local currentSessionIndex = 0
-- Is the session started ?
local isSessionStarted = nil
-- Is formation lap
local isFormationLap = true
-- Screen resolution
local screen = vec2(ac.getSim().windowWidth, ac.getSim().windowHeight)
-- Scale for UI
local scale = screen.y / 1080
-- Default font size
local fontSize = 35 * scale
-- How many car is connected (not really used)
local connectedCar = 0
-- Steps during the formation lap
local lapSteps = 1
-- Distance to the car ahead
local aheadDistance = 0
-- Timer for displaying the green start
local greenStartTimer = 2
-- Runway side label
local sideStr = 'left'
-- Speed limiter in Kmh for show in screen
local speedLimte = ac.getSim().speedLimitKmh
-- Did the driver cross the starting line?
local isCrossedStartLine = nil
-- Is show the radar on screen ?
local isShowRadar = false
-- Track length in meters
local trackLengthM = ac.getSim().trackLengthM

-- Mark where to start the limter (300 meters before end track)
local markLimiter = trackLengthM - 300
-- Mark Warning of the area to speed limiter (400 meters before end track)
local markWarningLimiter = trackLengthM - 400
-- Mark for riding in double line (800 meters before end track)
local markSide = trackLengthM - 800

local function debug(text)
    if DEBUG then
        ac.log(string.format("%s: %s", os.date("%X"), text))
    end
end

--- Get the position in leaderbord by car index (0 based)
---@param index number
---@return integer
local function getPlayerPosition(index)
    for i = 1, #leaderboard do
        if leaderboard[i].index == index then return i end
    end
    return -1
end

--- Update the leaderbord and sort
local function updateLeaderboard()
    leaderboard = {}
    connectedCar = 0
    for i, c in ac.iterateCars.leaderboard() do
        leaderboard[i] = c
        if c.isConnected then
            connectedCar = connectedCar + 1
        end
    end

    table.sort(leaderboard, function(car1, car2)
        if not car1.isConnected and car2.isConnected then
            return false
        elseif car1.isConnected and not car2.isConnected then
            return true
        else
            return car1.racePosition < car2.racePosition
        end
    end)
end

--- Initialize variable to default values
local function initialize()
    updateLeaderboard()
    isFormationLap = true
    lapSteps = 1
    greenStartTimer = 2
    isCrossedStartLine = false
    currentSessionIndex = ac.getSim().currentSessionIndex
    isInitialized = true
    debug('Initialized')
end

if ac.onSessionStart then
    ac.onSessionStart(function()
        debug('New session start')
        initialize()
    end)
end

if ac.onOnlineWelcome then
    ac.onOnlineWelcome(function()
        debug('Join online server')
        -- Race started when connect
        initialize()
        if ac.getSim().isSessionStarted then
            isFormationLap = false
        end
    end)
end

--- Draw start race on screen
local function drawGreenStart()
    local winSize = vec2(400, (fontSize * 2) * scale)
    local size = fontSize - 2
    ui.beginTransparentWindow('formationLapGreen', vec2((screen.x - winSize.x) / 2, screen.y / 4), winSize)
    for i = 0, 5 do
        ui.drawCircleFilled(vec2(size, 0) + vec2(size * (i * 2), size), size, rgbm.colors.green, size)
    end
    ui.endTransparentWindow()
end

--- Draw speed limit on screen
local function drawSpeedlimite()
    local winSize = vec2((fontSize * 2) * scale, (fontSize * 2) * scale)
    local size = fontSize
    ui.beginTransparentWindow('formationLapGreen', vec2((screen.x - winSize.x) / 1.845, screen.y / 2.9), winSize)
    ui.drawCircleFilled(vec2(size, size), size, rgbm.colors.red, size)
    ui.drawCircleFilled(vec2(size, size), size / 1.2, rgbm.colors.white, size)
    ui.dwriteDrawTextClipped(tostring(speedLimte), fontSize - 8, 0, winSize, ui.Alignment.Center,
        ui.Alignment.Center, false, rgbm.colors.blue)
    ui.endTransparentWindow()
end

--- Draw a text message on screen with a title
---@param title string
---@param text string
local function drawMessage(title, text)
    local winSize = vec2(400, (fontSize * 4) * scale)
    ui.beginTransparentWindow('formationLapMsg', vec2((screen.x - winSize.x) / 2, screen.y / 3), winSize)
    ui.dwriteDrawTextClipped(title, fontSize, 0, vec2(winSize.x, fontSize * 1.5), ui.Alignment.Center,
        ui.Alignment.Start, false, rgbm.colors.blue)
    ui.drawLine(vec2(0, fontSize * 1.5), vec2(winSize.x, fontSize * 1.5), rgbm.colors.green, 4)
    ui.dwriteDrawTextClipped(text, fontSize - 8, vec2(0, fontSize * 1.6), winSize, ui.Alignment.Center,
        ui.Alignment.Start, false, rgbm.colors.white)
    ui.endTransparentWindow()
end

--- Draw a mini radar, to keep the distance from the car in front
---@param ahead number
local function drawRadar(ahead)
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

--- Show debug window
local function drawDebug()
    local winSize = vec2(300, 900)
    ui.beginToolWindow('formationLapState', vec2((screen.x - winSize.x) / 3.5, 150), winSize)
    ui.text(string.format("isInitialized : %s", isInitialized))
    ui.text(string.format("formationLap : %s", isFormationLap))
    ui.text(string.format("currentSessionIndex : %s", currentSessionIndex))
    ui.text(string.format("carcount : %0.0f ", #leaderboard))
    ui.text(string.format("connectedCar : %0.0f ", connectedCar))
    ui.text(string.format("isSessionStarted : %s", isSessionStarted))
    ui.text(string.format("isCrossedStartLine : %s", isCrossedStartLine))
    ui.text(string.format("lapSteps : %d", lapSteps))
    ui.text(string.format("greenTimer : %0.3f", greenStartTimer))
    ui.text(string.format("lapcount : %d", ac.getCar(0).lapCount))
    ui.text(string.format("aheadDistance : %d", aheadDistance))
    ui.text(string.format("raceSessionType : %d", ac.getSim().raceSessionType))

    ui.newLine()
    for i = 1, #leaderboard do
        if leaderboard[i] ~= nil and leaderboard[i].isConnected then
            ui.text(string.format("racePosition: %d, %s", i, ac.getDriverName(leaderboard[i].index)))
        end
    end
    ui.endToolWindow()
end

function script.drawUI()
    if DEBUG then
        drawDebug()
    end
    if not isFormationLap then return end
    if not isSessionStarted then return end
    if not isCrossedStartLine then return end


    -- follow the lap progress
    if lapSteps == 1 then
        -- Step 1, run in single file
        drawMessage("Formation Lap", "Line up single file")
    elseif lapSteps == 2 then
        -- Step 2, run in double file
        drawMessage("Formation Lap", "Align on double file\n Keep " .. sideStr)
    elseif lapSteps == 3 then
        -- Step 3, run with the speed limiter
        drawMessage("Formation Lap", "Speed Limiter on\n Keep " .. sideStr)
        drawSpeedlimite()
    elseif lapSteps == 4 then
        -- Step 4, warning about the limiter zone
        drawMessage("Formation Lap", "speed limit at 100 meters\n Keep " .. sideStr)
        drawSpeedlimite()
    end

    if lapSteps == 5 then
        -- Step 5, Formation lap ended, run
        drawMessage("Formation Lap", "Green flag Race start\ngo... go... go...")
        drawGreenStart()
    end
    -- show the radar between ahead car
    if isShowRadar then
        drawRadar(aheadDistance)
    end
end

function script.update(dt)
    
    -- Exit if not online and not race
    local sim = ac.getSim()
    if sim.isOnlineRace and sim.raceSessionType == ac.SessionType.Race then
        -- check if race started
        if isSessionStarted ~= sim.isSessionStarted then
            isSessionStarted = sim.isSessionStarted
            debug("Race started " .. tostring(isSessionStarted))
            initialize()
        end

        if isSessionStarted and isFormationLap then
            -- update car data and count connected cars
            if isFormationLap then
                updateLeaderboard()
            end
            -- Get the stateCar of current car, always 0
            local focusedCarState = nil
            focusedCarState = ac.getCar(0)

            -- Check if the car crossed start line
            if focusedCarState.splinePosition < 0.001 and not focusedCarState.isInPit then
                isCrossedStartLine = true
                debug("Crossed start line")
            end

            -- If lap is 1 or more, switch to step 5 (end formation lap)
            if focusedCarState.lapCount >= 1 then
                lapSteps = 5
                debug("Step 5")
            end

            -- On step 5, decrease the counter of green flag
            if lapSteps == 5 then
                greenStartTimer = greenStartTimer - dt
                if greenStartTimer <= 0 then
                    -- Formation lap is ended
                    isFormationLap = false
                end
            else
                local currentPositionM = leaderboard[1].splinePosition * trackLengthM

                if currentPositionM <= markSide then
                    -- As long as you are not at the first mark, you ride in single file
                    lapSteps = 1
                elseif currentPositionM >= markLimiter then
                    -- The speed limiter mark has passed, activate the speed limiter
                    lapSteps = 3
                elseif currentPositionM >= markWarningLimiter then
                    -- The zone limiter mark has passed, the speed limit zone is coming
                    lapSteps = 4
                elseif currentPositionM >= markSide then
                    -- The side mark has passed, drive in double file
                    lapSteps = 2
                end
            end

            if lapSteps == 3 then
                -- Speed ​​control on limiter zone
                if (focusedCarState.speedKmh > speedLimte + 2) and sim.isOnlineRace then
                    physics.setCarPenalty(ac.PenaltyType.MandatoryPits, 5)
                end
            end

            if focusedCarState.racePosition > 1 and connectedCar > 1 then
                -- Calculate the distance to the car in front
                aheadDistance = focusedCarState.position:distance(leaderboard
                    [getPlayerPosition(focusedCarState.index) - 1].position)
                isShowRadar = true
            else
                isShowRadar = false
            end

            -- Even positions are on the right, odd positions are on the left
            --to have the opposite, do focusedCarState.racePosition % 2 == 1
            if focusedCarState.racePosition % 2 == 0 then
                sideStr = "right"
            else
                sideStr = "left"
            end
        end
    end
end
