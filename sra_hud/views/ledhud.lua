local function drawIcon(pos, size, icon, color)
    ui.drawIcon(icon, pos, pos + (size * SETTING.scale), color)
end
local iconFlash = false
setInterval(function() iconFlash = not iconFlash end, 0.5)

function script.ledHUD(dt)
    local size = vec2(128, 100) * SETTING.scale
    ui.drawImage(".//img//led.png", 0, 0 + size, SETTING.styleColor)
    ui.dummy(size)
    local color
    if CAR.carState.absMode > 0 then
        if CAR.carState.absInAction then
            color = rgbm.colors.red
        else
            color = SETTING.fontColor
        end
        drawIcon(vec2(10 * SETTING.scale, 10 * SETTING.scale), 22, ".//img/abs.png", color)
        ui.dwriteDrawText(string.format("ABS %02d", CAR.carState.absMode), 20 * SETTING.scale,
            vec2(15 * SETTING.scale, 180 * SETTING.scale), color)
    end
    if CAR.carState.drsPresent then
        if CAR.carState.drsActive then
            color = rgbm.colors.red
        elseif CAR.carState.drsAvailable then
            color = rgbm.colors.green
        else
            color = SETTING.fontColor
        end
        drawIcon(vec2(96 * SETTING.scale, 10 * SETTING.scale), 22, ".//img/drs.png", color)
    end
    if CAR.carState.manualPitsSpeedLimiterEnabled or CAR.carState.speedLimiterInAction then
        drawIcon(vec2(67 * SETTING.scale, 10 * SETTING.scale), 22, ".//img/limiter.png", rgbm.colors.red)
    end
    if CAR.carState.headlightsActive then
        drawIcon(vec2(30 * SETTING.scale, 38 * SETTING.scale), 20, ".//img//light.png", SETTING.fontColor)
    end
    if CAR.carState.flashingLightsActive and CAR.carSate.hasFlashingLights then
        drawIcon(vec2(76 * SETTING.scale, 37 * SETTING.scale), 22, ".//img//flashlight.png", SETTING.fontColor)
    end
    if CAR.carState.hazardLights and iconFlash then
        drawIcon(vec2(21 * SETTING.scale, 67 * SETTING.scale), 20, ".//img//left.png", SETTING.fontColor)
        drawIcon(vec2(54 * SETTING.scale, 67 * SETTING.scale), 20, ".//img//hazard.png", rgbm.colors.red)
        drawIcon(vec2(87 * SETTING.scale, 67 * SETTING.scale), 20, ".//img//right.png", SETTING.fontColor)
    end

    if CAR.carState.turningRightOnly and iconFlash then
        drawIcon(vec2(87 * SETTING.scale, 67 * SETTING.scale), 20, ".//img//right.png", SETTING.fontColor)
    end
    if CAR.carState.turningLeftOnly and iconFlash then
        drawIcon(vec2(21 * SETTING.scale, 67 * SETTING.scale), 20, ".//img//left.png", SETTING.fontColor)
    end
    color = rgbm.colors.gray
    if CAR.carState.tractionControlMode > 0 then
        if CAR.carState.tractionControlInAction then
            color = rgbm.colors.red
        else color = SETTING.fontColor
        end
        drawIcon(vec2(39 * SETTING.scale, 10 * SETTING.scale), 22, ".//img//tc.png", color)
    end
end
