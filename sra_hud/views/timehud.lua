function script.timeHUD(dt)
    local pos = ui.getCursor()
    local pos2 = ui.getCursor()
    local size = vec2(210, 25) * SETTING.scale
    local rectText = vec2(110, 25) * SETTING.scale
    local bckImage = ".//img//timerbg.png"
    local iconSize = 18 * SETTING.scale
    local fontSize = 20 * SETTING.scale

    ui.pushDWriteFont('OneSlot:\\fonts\\.')
    ui.pushStyleVar(ui.StyleVar.ItemSpacing, 0)
    ui.drawImage(bckImage, pos, pos + size, SETTING.styleColor)
    ui.dwriteDrawTextClipped(string.format("%s|", os.date("%X")), fontSize, pos, pos + rectText,
        ui.Alignment.End, ui.Alignment.Center, false, SETTING.fontColor)

    pos.x = pos.x + (10 * SETTING.scale)
    pos.y = pos.y + (4 * SETTING.scale)
    ui.drawIcon(ui.Icons.Clock, pos, pos + iconSize, SETTING.fontColor)
    pos2.x = pos2.x + 90 * SETTING.scale
    ui.dwriteDrawTextClipped(string.format("%s", os.date("!%X", ac.getSim().timestamp)), fontSize, pos2, pos2 + rectText,
        ui.Alignment.End, ui.Alignment.Center, false, SETTING.fontColor)
    pos2.x = pos2.x + (20 * SETTING.scale)
    pos2.y = pos2.y + (4 * SETTING.scale)
    ui.drawIcon(".//img//servertime.png", pos2, pos2 + iconSize, SETTING.fontColor)
    ui.dummy(size)
    if ui.itemHovered() then ui.setTooltip("Local time | Serveur time") end

    ui.popStyleVar()
    ui.popDWriteFont()
end
