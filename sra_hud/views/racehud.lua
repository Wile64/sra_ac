local sf = string.format


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

function script.raceHUD(dt)
    ui.pushDWriteFont('OneSlot:/fonts;Weight=Bold')
    ui.pushStyleVar(ui.StyleVar.ItemSpacing, 1)
    local simState = ac.getSim()

    if SETTING.raceHUD.showRoadGrip then
        drawItem(sf("%.2f%%", simState.roadGrip * 100), "/img/road.png")
        if ui.itemHovered() then ui.setTooltip("Road Grip") end
    end
    if SETTING.raceHUD.showFuelRate then
        drawItem(sf("%.2f%%", simState.fuelConsumptionRate * 100), ui.Icons.Fuel)
        if ui.itemHovered() then ui.setTooltip("Fuel Rate") end
    end
    if SETTING.raceHUD.showDamageRate then
        drawItem(sf("%.2f%%", simState.mechanicalDamageRate * 100), ui.Icons.Repair)
        if ui.itemHovered() then ui.setTooltip("Damage Rate") end
    end
    if SETTING.raceHUD.showTyreRate then
        drawItem(sf("%.2f%%", simState.tyreConsumptionRate * 100), "/img/tyre.png")
        if ui.itemHovered() then ui.setTooltip("Tyre Rate") end
    end
    ui.popStyleVar()
    ui.popDWriteFont()
end
