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

function script.weatherHUD(dt)
    ui.pushDWriteFont('OneSlot:/fonts;Weight=Bold')
    ui.pushStyleVar(ui.StyleVar.ItemSpacing, 1)
    local simState = ac.getSim()

    drawItem(sf("%.0f°", simState.ambientTemperature), ui.Icons.Thermometer)
    if ui.itemHovered() then ui.setTooltip("Ambient Temperature") end
    drawItem(sf("%.0f°", simState.roadTemperature), ui.Icons.Road)
    if ui.itemHovered() then ui.setTooltip("Road Temperature") end
    drawItem(sf("%.0f Km/h", simState.windSpeedKmh), ui.weatherIcon(simState.weatherType))
    if ui.itemHovered() then ui.setTooltip("Wind Speed in Km/h") end

    ui.popStyleVar()
    ui.popDWriteFont()
end
