---comment
---@param text string
local function drawSector(text)
    local pos = ui.getCursor()
    local size = vec2(80, 25) * SETTING.scale
    local rectText = vec2(75, 25) * SETTING.scale
    local fontSize = 20 * SETTING.scale
    ui.drawRectFilled(pos, pos + size, SETTING.styleColor, 10 * SETTING.scale)
    ui.dwriteDrawTextClipped(text, fontSize, pos, pos + rectText,
        ui.Alignment.End, ui.Alignment.Center, false, SETTING.fontColor)
    ui.dummy(size)
end

function script.sectorHUD(dt)
    ui.pushDWriteFont('OneSlot:/fonts;Weight=Bold')
    ui.pushStyleVar(ui.StyleVar.ItemSpacing, 1)

    local simState = ac.getSim()
    local sectorCount = #simState.lapSplits
    for i = 1, sectorCount do
        drawSector(ac.lapTimeToString(CAR.carState.bestSplits[i - 1]))
        --ui.sameLine()
    end

    ui.popStyleVar()
    ui.popDWriteFont()
end
