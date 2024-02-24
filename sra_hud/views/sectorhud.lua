---comment
---@param text string
local function drawSector(text, color)
    local pos = ui.getCursor()
    local size = vec2(80, 25) * SETTING.scale
    local rectText = vec2(75, 25) * SETTING.scale
    local fontSize = 20 * SETTING.scale
    local bckImage = ".//img//timerbg.png"

    ui.drawImage(bckImage, pos, pos + size, SETTING.styleColor)
--    ui.drawRectFilled(pos, pos + size, color, 5)
    ui.dwriteDrawTextClipped(text, fontSize, pos, pos + rectText,
        ui.Alignment.End, ui.Alignment.Center, false, SETTING.fontColor)
    ui.dummy(size)
end

function script.sectorHUD(dt)
    ui.pushDWriteFont('OneSlot:\\fonts\\.')
    ui.pushStyleVar(ui.StyleVar.ItemSpacing, 0)

    local simState = ac.getSim()
    local sectorCount = #simState.lapSplits
    --CAR.carState.currentSector
    local color = rgbm.colors.gray
    for i = 1, sectorCount do
        if CAR.carState.currentSector + 1 == i then
            color = SETTING.styleColor
        else
            color = rgbm.colors.gray
        end
        drawSector(ac.lapTimeToString(CAR.carState.bestSplits[i - 1]), color)
        --ui.sameLine()
    end

    ui.popStyleVar()
    ui.popDWriteFont()
end
