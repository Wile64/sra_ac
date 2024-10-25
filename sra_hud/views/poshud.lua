---comment
---@param text string
---@param icon ui.Icons
---@param Backcolor rgbm?
---@param fontColor rgbm?
local function drawItem(text, icon, Backcolor, fontColor)
    local pos = ui.getCursor()
    local size = vec2(120, 25) * SETTING.scale
    local rectText = vec2(110, 25) * SETTING.scale
    local iconPosX = 10 * SETTING.scale
    local iconPosY = 4 * SETTING.scale
    local iconSize = 18 * SETTING.scale
    local fontSize = 20 * SETTING.scale
    if fontColor == nil then
        fontColor = SETTING.fontColor
    end
    if Backcolor == nil then
        Backcolor = SETTING.styleColor
    end
    ui.drawRectFilled(pos, pos + size, Backcolor, 10 * SETTING.scale)
    ui.dwriteDrawTextClipped(text, fontSize, pos, pos + rectText,
        ui.Alignment.End, ui.Alignment.Center, false, fontColor)
    pos.x = pos.x + iconPosX
    pos.y = pos.y + iconPosY
    ui.drawIcon(icon, pos, pos + iconSize, fontColor)
    ui.dummy(size)
end

local sessionStr = {
    "Undefined",
    "Practice",
    "Qualify",
    "Race",
    "Hotlap",
    "TimeAttack",
    "Drift",
    "Drag" }

function script.posHUD(dt)
    ui.pushDWriteFont('OneSlot:/fonts;Weight=Bold')
    ui.pushStyleVar(ui.StyleVar.ItemSpacing, 1)
    local session = ac.getSim()

    --Session Type
    if SETTING.positionHUD.showSession then
        drawItem(sessionStr[ac.getSim().raceSessionType + 1], ".//img//session.png")
        if ui.itemHovered() then ui.setTooltip("Current session") end
    end

    -- Position
    if SETTING.positionHUD.showPosition then
        local posStr = string.format("%d/%d", CAR.carState.racePosition, session.carsCount)
        drawItem(posStr, ".//img//position.png")
        if ui.itemHovered() then ui.setTooltip("Position") end
    end
    -- Laps
    if SETTING.positionHUD.showLapCount then
        local totalLaps = 0
        local currentLap = 0
        local lapStr = "%d/%d"
        if session.raceSessionType == ac.SessionType.Race then
            totalLaps = ac.getSession(session.currentSessionIndex).laps
            currentLap = math.max(1, CAR.carState.sessionLapCount + 1)
            if currentLap > totalLaps then
                currentLap = totalLaps
                lapStr = "%d/%d"
            end
        else
            currentLap = math.max(1, CAR.carState.sessionLapCount + 1)
            lapStr = "%d"
        end
        local LapStr = string.format(lapStr, currentLap, totalLaps)
        drawItem(LapStr, ".//img//lapcount.png")
        if ui.itemHovered() then ui.setTooltip("Lap(s)") end
    end
    -- Timer
    if SETTING.positionHUD.showSessionTimer then
        local timeStr = ""
        if session.raceSessionType == ac.SessionType.Race and session.isTimedRace then
            if session.sessionTimeLeft <= 0 then
                timeStr = "Overtime"
            else
                timeStr = tostring(os.date("!%X", session.sessionTimeLeft / 1000))
            end
            drawItem(timeStr, ui.Icons.Clock)
            if ui.itemHovered() then ui.setTooltip("Session timer") end
        elseif session.raceSessionType ~= ac.SessionType.Race and session.isOnlineRace then
            if session.sessionTimeLeft <= 0 then
                timeStr = "Overtime"
            else
                timeStr = tostring(os.date("!%X", session.sessionTimeLeft / 1000))
            end
            drawItem(timeStr, ui.Icons.Clock)
            if ui.itemHovered() then ui.setTooltip("Session timer") end
        end
    end
    --Flag
    if SETTING.positionHUD.showFlag then
        local FlagStr = {
            'NONE',
            'GREEN',
            'Yellow',
            'Slippery',
            'Pit Close',
            'BLACK',
            'SLOW CAR',
            'Ambulance',
            'PENALTY',
            'Failure',
            'Unsportsmanlike',
            'StopCancel',
            'BLUE',
            'RACE OVER',
            'WHITE',
            'SessionSuspended',
            'Code60',
        }
        local FlagColor = {
            { rgbm.colors.transparent,  rgbm.colors.white },  -- ac.FlagType.None
            { rgbm.colors.green,  rgbm.colors.white },  -- ac.FlagType.Start
            { rgbm.colors.yellow, rgbm.colors.black },  --ac.FlagType.Caution
            { rgbm.colors.aqua,   rgbm.colors.black },  --ac.FlagType.Slippery
            { rgbm.colors.aqua,   rgbm.colors.black },  --ac.FlagType.PitLaneClosed
            { rgbm.colors.black,  rgbm.colors.white },  --ac.FlagType.Stop
            { rgbm.colors.yellow, rgbm.colors.black },  --ac.FlagType.SlowVehicle
            { rgbm.colors.red,    rgbm.colors.white },  --ac.FlagType.Ambulance
            { rgbm.colors.red,    rgbm.colors.white },  --ac.FlagType.ReturnToPits
            { rgbm.colors.aqua,   rgbm.colors.black },  --ac.FlagType.MechanicalFailure
            { rgbm.colors.aqua,   rgbm.colors.black },  --ac.FlagType.Unsportsmanlike
            { rgbm.colors.aqua,   rgbm.colors.black },  --ac.FlagType.StopCancel
            { rgbm.colors.blue,   rgbm.colors.white },  --ac.FlagType.FasterCar
            { rgbm.colors.gray,   rgbm.colors.white },  --ac.FlagType.Finished
            { rgbm.colors.white,  rgbm.colors.black },  --ac.FlagType.OneLapLeft
            { rgbm.colors.aqua,   rgbm.colors.black },  --ac.FlagType.SessionSuspended
            { rgbm.colors.aqua,   rgbm.colors.black },  --ac.FlagType.Code60

        }
        local flag = session.raceFlagType + 1
        drawItem(FlagStr[flag], ui.Icons.Flag, FlagColor[flag][1], FlagColor[flag][2])
        if ui.itemHovered() then ui.setTooltip("Session Flag") end
    end
    ui.popStyleVar()
    ui.popDWriteFont()
end
