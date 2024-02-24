---comment
---@param text string
---@param icon ui.Icons
local function drawItem(text, icon)
    local pos = ui.getCursor()
    local size = vec2(120, 25) * SETTING.scale
    local rectText = vec2(110, 25) * SETTING.scale
    local bckImage = ".//img//timerbg.png"
    local iconPosX = 10 * SETTING.scale
    local iconPosY = 4 * SETTING.scale
    local iconSize = 18 * SETTING.scale
    local fontSize = 20 * SETTING.scale

    ui.drawImage(bckImage, pos, pos + size, SETTING.styleColor)
    ui.dwriteDrawTextClipped(text, fontSize, pos, pos + rectText,
        ui.Alignment.End, ui.Alignment.Center, false, SETTING.fontColor)
    pos.x = pos.x + iconPosX
    pos.y = pos.y + iconPosY
    ui.drawIcon(icon, pos, pos + iconSize, SETTING.fontColor)
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
    ui.pushDWriteFont('OneSlot:\\fonts\\.')
    ui.pushStyleVar(ui.StyleVar.ItemSpacing, 0)

    --Session Type
    drawItem(sessionStr[ac.getSim().raceSessionType + 1], ".//img//session.png")
    if ui.itemHovered() then ui.setTooltip("Current session") end

    -- Position
    local session = ac.getSim()
    local posStr = string.format("%d/%d", CAR.carState.racePosition, session.carsCount)
    drawItem(posStr, ".//img//position.png")
    if ui.itemHovered() then ui.setTooltip("Position") end

    -- Laps
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

    -- Timer
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

    ui.popStyleVar()
    ui.popDWriteFont()
end
