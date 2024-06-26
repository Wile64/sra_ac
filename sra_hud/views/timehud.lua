function DrawTextAt(text, fontSize, pos, size, horizontalAligment, color)
    size = size * SETTING.scale
    ui.drawRectFilled(pos - 4, pos + size + 8, rgbm(0.2, 0.2, 0.2, 1), 10)
    ui.dwriteDrawTextClipped(text, fontSize, pos, pos + size, horizontalAligment, ui.Alignment.Center, false, color)
    ui.dummy(pos + size + 8)
end

local function drawItem(text, icon)
    local pos = ui.getCursor()
    local size = vec2(120, 25) * SETTING.scale
    local rectText = vec2(110, 25) * SETTING.scale
    local iconPosX = 10 * SETTING.scale
    local iconPosY = 4 * SETTING.scale
    local iconSize = 18 * SETTING.scale
    local fontSize = 20 * SETTING.scale

    ui.drawRectFilled(pos, pos + size, SETTING.styleColor, 10 * SETTING.scale)
    ui.dwriteDrawTextClipped(text, fontSize, pos, pos + rectText,
        ui.Alignment.End, ui.Alignment.Center, false, SETTING.fontColor)
    pos.x = pos.x + iconPosX
    pos.y = pos.y + iconPosY
    ui.drawIcon(icon, pos, pos + iconSize, SETTING.fontColor)
    ui.dummy(size)
end

function script.timeHUD(dt)
    ui.pushDWriteFont('OneSlot:/fonts;Weight=Bold')
    ui.pushStyleVar(ui.StyleVar.ItemSpacing, 2)
    local str = string.format("%s", os.date("%X"))
    drawItem(str, ui.Icons.Clock)
    if ui.itemHovered() then ui.setTooltip("Local time") end
    ui.sameLine()
    str = string.format("%s", os.date("!%X", ac.getSim().timestamp))
    drawItem(str, "/img/servertime.png")
    if ui.itemHovered() then ui.setTooltip("Server time") end
    ui.popStyleVar()
    ui.popDWriteFont()
end
