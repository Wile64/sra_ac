--- Get current gear in string
---@return string
local function getGearToString()
    if CAR.carState.gear < 0 then
        return "R"
    elseif CAR.carState.gear == 0 then
        return "N"
    else
        return tostring(CAR.carState.gear)
    end
end

function script.speedHUD(dt)
    local fontSize = 20 * SETTING.scale
    ui.pushDWriteFont('OneSlot:/fonts;Weight=Bold')
    ui.pushStyleVar(ui.StyleVar.ItemSpacing, 0)

    ui.dwriteText(getGearToString(), fontSize * 4, SETTING.fontColor)
    ui.dwriteText(string.format("%3.0f", CAR.carState.speedKmh), fontSize * 2,  SETTING.fontColor)
    ui.sameLine()
    ui.dwriteText("kmh", fontSize,  SETTING.fontColor)
    ui.popStyleVar()
    ui.popDWriteFont()
end
