local LedWidget = {}
LedWidget.__index = LedWidget

local ICON_SIZE = 30
local ICON_PATH = 'img\\'
local ICON_SPACING = 5

local iconFlash = false
setInterval(function()
  iconFlash = not iconFlash
end, 0.5)

local function drawIcon(size, path, color, scale)
  local pos = ui.getCursor()
  local iconSize = vec2(size, size) * scale
  ui.drawImage(path, pos, pos + iconSize, color)
  ui.dummy(iconSize)
end

local function appendIcon(size, path, color, scale, noSameLine)
  drawIcon(size, path, color, scale)
  if not noSameLine then
    ui.sameLine()
  end
end

function LedWidget:new()
  return setmetatable({
    id = 'led',
    title = 'LED',
    windowId = 'windowLed',
    car = nil,
  }, self)
end

function LedWidget:update(dt, context)
  self.car = context.car
end

function LedWidget:draw(dt, drawContext)
  local car = self.car
  if not car then
    return
  end

  local scale = (drawContext.scale or 1) * (drawContext.ledScale or 1)
  local colors = drawContext.colors
  local ledColors = drawContext.style.led
  local blinkOffColor = ledColors.off
  local fontColor = colors.valueNeutral
  local color

  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(ICON_SPACING * scale, 0))

  if drawContext.ledShowDRS then
    if car.drsPresent then
      if car.drsActive then
        color = ledColors.alert
      elseif car.drsAvailable then
        color = ledColors.available
      else
        color = fontColor
      end
      appendIcon(ICON_SIZE, ICON_PATH .. 'drs.png', color, scale)
    end
  end

  if drawContext.ledShowABS then
    if (car.absMode or 0) > 0 then
      color = car.absInAction and ledColors.alert or fontColor
      appendIcon(ICON_SIZE, ICON_PATH .. 'abs.png', color, scale)
    end
  end

  if drawContext.ledShowTC then
    if (car.tractionControlMode or 0) > 0 then
      color = car.tractionControlInAction and ledColors.alert or fontColor
      appendIcon(ICON_SIZE, ICON_PATH .. 'tc.png', color, scale)
    end
  end

  if drawContext.ledShowSpeedLimiter then
    if (car.speedLimiter or 0) > 0 then
      local limiterActive = car.manualPitsSpeedLimiterEnabled or car.speedLimiterInAction
      appendIcon(ICON_SIZE, ICON_PATH .. 'limiter.png', limiterActive and ledColors.alert or blinkOffColor, scale)
    end
  end

  if drawContext.ledShowLight then
    if car.headlightsActive then
      appendIcon(ICON_SIZE - 2, ICON_PATH .. 'light.png', fontColor, scale)
    end
  end

  if drawContext.ledShowFlashingLight then
    if car.flashingLightsActive then
      appendIcon(ICON_SIZE, ICON_PATH .. 'flashlight.png', fontColor, scale)
    end
  end

  if drawContext.ledShowHazard then
    if car.hazardLights then
      color = iconFlash and ledColors.alert or blinkOffColor
      appendIcon(ICON_SIZE - 2, ICON_PATH .. 'hazard.png', color, scale)
    end
  end

  if drawContext.ledShowTurningLight then
    if car.turningRightOnly then
      color = iconFlash and fontColor or blinkOffColor
      appendIcon(ICON_SIZE - 2, ICON_PATH .. 'right.png', color, scale)
    end
    if car.turningLeftOnly then
      color = iconFlash and fontColor or blinkOffColor
      appendIcon(ICON_SIZE - 2, ICON_PATH .. 'left.png', color, scale, true)
    end
  end

  ui.popStyleVar()
end

return LedWidget
