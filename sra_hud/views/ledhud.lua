local function drawIcon(size, icon, color)
    local pos = ui.getCursor()
    ui.drawIcon(icon, pos, pos + (size * SETTING.ledHUD.scale), color)
    ui.dummy(size * SETTING.ledHUD.scale)
end
local iconFlash = false
setInterval(function() iconFlash = not iconFlash end, 0.5)

function script.ledHUD(dt)
    local iconSize = 22
    local color
    if CAR.carState.drsPresent then
        if CAR.carState.drsActive then
            color = rgbm.colors.red
        elseif CAR.carState.drsAvailable then
            color = rgbm.colors.green
        else
            color = SETTING.fontColor
        end
        drawIcon(iconSize, ".//img/drs.png", color)
        ui.sameLine()
    end
    if CAR.carState.absMode > 0 then
        if CAR.carState.absInAction then
            color = rgbm.colors.red
        else
            color = SETTING.fontColor
        end
        drawIcon(iconSize, ".//img/abs.png", color)
        ui.sameLine()
    end
    color = rgbm.colors.gray
    if CAR.carState.tractionControlMode > 0 then
        if CAR.carState.tractionControlInAction then
            color = rgbm.colors.red
        else
            color = SETTING.fontColor
        end
        drawIcon(iconSize, ".//img//tc.png", color)
        ui.sameLine()
    end
    if CAR.carState.manualPitsSpeedLimiterEnabled or CAR.carState.speedLimiterInAction then
        drawIcon(iconSize, ".//img/limiter.png", rgbm.colors.red)
        ui.sameLine()
    end
    if CAR.carState.headlightsActive then
        drawIcon(iconSize - 2, ".//img//light.png", SETTING.fontColor)
        ui.sameLine()
    end
    if CAR.carState.flashingLightsActive then
        drawIcon(iconSize, ".//img//flashlight.png", SETTING.fontColor)
        ui.sameLine()
    end
    if CAR.carState.hazardLights and iconFlash then
        drawIcon(iconSize - 2, ".//img//left.png", SETTING.fontColor)
        ui.sameLine()
        drawIcon(iconSize - 2, ".//img//hazard.png", rgbm.colors.red)
        ui.sameLine()
        drawIcon(iconSize - 2, ".//img//right.png", SETTING.fontColor)
        ui.sameLine()
    end

    if CAR.carState.turningRightOnly and iconFlash then
        drawIcon(iconSize - 2, ".//img//right.png", SETTING.fontColor)
        ui.sameLine()
    end
    if CAR.carState.turningLeftOnly and iconFlash then
        drawIcon(iconSize - 2, ".//img//left.png", SETTING.fontColor)
    end
end
