local fileIni = ac.getFolder(ac.FolderID.ACDocuments) .. "\\personalbest.ini"
local mapData = ac.INIConfig.load(fileIni)
local personalBest = mapData:get(string.upper(tostring(ac.getCarID(0))) .. "@" .. string.upper(ac.getTrackFullID('-')),
    'TIME', {})[1] or 0

---comment
---@param text string
---@param icon ui.Icons
local function drawItem(text, icon, textColor)
    local pos = ui.getCursor()
    local size = vec2(120, 25) * SETTING.scale
    local rectText = vec2(110, 25) * SETTING.scale
    local iconPosX = 10 * SETTING.scale
    local iconPosY = 4 * SETTING.scale
    local iconSize = 18 * SETTING.scale
    local fontSize = 20 * SETTING.scale

    ui.drawRectFilled(pos, pos + size, SETTING.styleColor, 10 * SETTING.scale)
    ui.dwriteDrawTextClipped(text, fontSize, pos, pos + rectText,
        ui.Alignment.End, ui.Alignment.Center, false, textColor)
    pos.x = pos.x + iconPosX
    pos.y = pos.y + iconPosY
    ui.drawIcon(icon, pos, pos + iconSize, textColor)
    ui.dummy(size)
end

function script.chronoHUD(dt)
    ui.pushDWriteFont('OneSlot:/fonts;Weight=Bold')
    ui.pushStyleVar(ui.StyleVar.ItemSpacing, 1)
    local fontColor = SETTING.fontColor
    if not CAR.carState.isLapValid then
        fontColor = rgbm.colors.red
    end
    if SETTING.chronoHUD.showDelta then
        drawItem(string.format("%1.3f", CAR.carState.performanceMeter), ".//img//chronodelta.png", fontColor)
        if ui.itemHovered() then ui.setTooltip("Delta time") end
    end
    if SETTING.chronoHUD.showCurrent then
        drawItem(ac.lapTimeToString(CAR.carState.lapTimeMs), ".//img//chrono.png", fontColor)
        if ui.itemHovered() then ui.setTooltip("Current lap time") end
    end
    if SETTING.chronoHUD.showEstimated then
        drawItem(ac.lapTimeToString(CAR.carState.estimatedLapTimeMs), ".//img//chronoestimated.png", fontColor)
        if ui.itemHovered() then ui.setTooltip("Estimated lap time") end
    end

    if CAR.carID == 0 then
        if SETTING.chronoHUD.showPrevious then
            if CAR.carState.isLastLapValid then
                drawItem(ac.lapTimeToString(CAR.carState.previousLapTimeMs), ".//img//chronolast.png", SETTING.fontColor)
            else
                drawItem(ac.lapTimeToString(CAR.carState.previousLapTimeMs), ".//img//chronolast.png", rgbm.colors.red)
            end
            if ui.itemHovered() then ui.setTooltip("Lasp lap time") end
        end
        if SETTING.chronoHUD.showBest then
            drawItem(ac.lapTimeToString(CAR.carState.bestLapTimeMs), ".//img//chronobest.png", SETTING.fontColor)
            if ui.itemHovered() then ui.setTooltip("Best session lap time") end
        end
        if SETTING.chronoHUD.showPersonal then
            drawItem(ac.lapTimeToString(personalBest), ".//img//chronopersonal.png", SETTING.fontColor)
            if ui.itemHovered() then ui.setTooltip("Personal lap time") end
        end
    end
    ui.popStyleVar()
    ui.popDWriteFont()
end
