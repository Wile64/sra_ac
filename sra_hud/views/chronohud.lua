local fileIni = ac.getFolder(ac.FolderID.ACDocuments) .. "\\personalbest.ini"
local mapData = ac.INIConfig.load(fileIni)
local personalBest = mapData:get(string.upper(tostring(ac.getCarID(0))) .. "@" .. string.upper(ac.getTrackFullID('-')),
    'TIME', {})[1] or 0

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

function script.chronoHUD(dt)
    ui.pushDWriteFont('OneSlot:\\fonts\\.')
    ui.pushStyleVar(ui.StyleVar.ItemSpacing, 0)
    drawItem(string.format("%2.3f", CAR.carState.performanceMeter), ".//img//chronodelta.png")
    if ui.itemHovered() then ui.setTooltip("Delta time") end
    drawItem(ac.lapTimeToString(CAR.carState.lapTimeMs), ".//img//chrono.png")
    if ui.itemHovered() then ui.setTooltip("Current lap time") end
    drawItem(ac.lapTimeToString(CAR.carState.estimatedLapTimeMs), ".//img//chronoestimated.png")
    if ui.itemHovered() then ui.setTooltip("Estimated lap time") end

    if CAR.carID == 0 then
        drawItem(ac.lapTimeToString(CAR.carState.previousLapTimeMs), ".//img//chronolast.png")
        if ui.itemHovered() then ui.setTooltip("Lasp lap time") end
        drawItem(ac.lapTimeToString(CAR.carState.bestLapTimeMs), ".//img//chronobest.png")
        if ui.itemHovered() then ui.setTooltip("Best session lap time") end
        drawItem(ac.lapTimeToString(personalBest), ".//img//chronopersonal.png")
        if ui.itemHovered() then ui.setTooltip("Personal lap time") end
    end
    ui.popStyleVar()
    ui.popDWriteFont()
end
