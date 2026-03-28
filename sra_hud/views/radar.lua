local RadarView = {}
RadarView.__index = RadarView

function RadarView:new()
  local appConfig = ac.storage({
    voice = true,
    voiceRepeat = 5,
    volume = 1,
    showPosition = true,
    showLine = true,
    showCircle = true,
    showSonar = true,
    range = 25,
    proximityDistance = 7,
  }, 'radar.')

  local gameVolume = ac.getAudioVolume(ac.AudioChannel.Main) or 1
  local finalVolume = gameVolume * appConfig.volume

  return setmetatable({
    config = appConfig,
    leftSound = ui.MediaPlayer('sound/car-on-left.wav'):setVolume(finalVolume):setAutoPlay(false),
    rightSound = ui.MediaPlayer('sound/car-on-right.wav'):setVolume(finalVolume):setAutoPlay(false),
    windowsHeader = vec2(0, 22),
    settingsPreviewUntil = -math.huge,
    lastRightSoundTime = -math.huge,
    lastLeftSoundTime = -math.huge,
  }, self)
end

local function canPlaySound(lastPlayedTime, currentTime, repeatTime)
  return currentTime - lastPlayedTime >= repeatTime
end

local function getSideBounds(screenPos, carSize, size, side)
  local halfX = carSize.x * 0.5
  local halfY = carSize.y * 0.5
  local minX, maxX
  if side == 'right' then
    minX = screenPos.x + halfX
    maxX = screenPos.x + halfX * 2 + size
  else
    minX = screenPos.x - (halfX * 2 + size)
    maxX = screenPos.x - halfX
  end
  local minY = screenPos.y - halfY
  local maxY = screenPos.y + halfY * 2
  return minX, maxX, minY, maxY
end

local function isCarOnSide(position, screenPos, carSize, size, side)
  local minX, maxX, minY, maxY = getSideBounds(screenPos, carSize, size, side)
  return position.x >= minX and position.x <= maxX and position.y >= minY and position.y <= maxY
end

local function drawSideZone(screenPos, carSize, size, side, color)
  local minX, maxX, minY, maxY = getSideBounds(screenPos, carSize, size, side)
  ui.drawRectFilled(vec2(minX, minY), vec2(maxX, maxY), color, 2)
end

local function drawCar(screenPos, carSize, color, position, showPosition)
  local halfCarSize = carSize / 2
  ui.drawRectFilled(screenPos - halfCarSize, screenPos + halfCarSize, color, 5)
  if showPosition and position ~= nil then
    ui.dwriteDrawTextClipped(position, carSize.y / 3, screenPos - halfCarSize, screenPos + halfCarSize,
      ui.Alignment.Center, ui.Alignment.Center, false, rgbm(0.1, 0.1, 0.1, color.mult))
  end
end

local function drawArc(center, direction, radius, angle, segments, color)
  local startAngle = math.atan2(direction.y, direction.x) - angle / 2
  local angleStep = angle / segments
  local cosStep = math.cos(angleStep)
  local sinStep = math.sin(angleStep)
  local cosA = math.cos(startAngle)
  local sinA = math.sin(startAngle)

  for _ = 1, segments do
    local nextCosA = cosA * cosStep - sinA * sinStep
    local nextSinA = sinA * cosStep + cosA * sinStep
    local point1 = center + vec2(cosA, sinA) * radius
    local point2 = center + vec2(nextCosA, nextSinA) * radius
    ui.drawTriangleFilled(center, point1, point2, color)
    cosA = nextCosA
    sinA = nextSinA
  end
end

function RadarView:draw(dt)
  local sim = ac.getSim()
  local settingsPreview = sim.gameTime <= self.settingsPreviewUntil
  if sim.focusedCar ~= 0 then
    return
  end
  if sim.isReplayActive and not settingsPreview then
    return
  end

  local fullWindowSize = ui.windowSize()
  local windowSize = fullWindowSize - self.windowsHeader
  local radarCenter = windowSize / 2 + self.windowsHeader
  local radarSize = math.min(windowSize.x, windowSize.y)
  local playerCar = ac.getCar(0)
  if not playerCar then
    return
  end
  if (playerCar.isInPit or playerCar.isInPitlane) and not settingsPreview then
    return
  end

  local showPosition = self.config.showPosition
  local showLine = self.config.showLine
  local showCircle = self.config.showCircle
  local showSonar = self.config.showSonar
  local voiceEnabled = self.config.voice
  local range = self.config.range
  local rangeSq = range * range
  local pixelsPerMeter = (radarSize * 0.5) / range
  local proximityDistance = self.config.proximityDistance
  local playerPos = playerCar.position
  local playerSize = vec2(playerCar.aabbSize.x * pixelsPerMeter, playerCar.aabbSize.z * pixelsPerMeter)
  local playerLook = playerCar.look
  local playerAngle = math.atan2(playerLook.z, playerLook.x)
  local colorAlpha = 0
  local showRadar = false
  local isCarRight = false
  local isCarLeft = false
  local currentTime = sim.gameTime

  local forward = vec2(playerLook.x, playerLook.z)
  local right = vec2(-forward.y, forward.x)
  local rightX, rightY = right.x, right.y
  local forwardX, forwardY = forward.x, forward.y
  local proximityOffset = 2 * pixelsPerMeter
  local arcRadius = proximityDistance * pixelsPerMeter
  local arcAngle = math.rad(40)
  local minDistanceFound = math.huge

  for i = 1, sim.carsCount do
    local otherCar = ac.getCar(i)
    if otherCar then
      local zOffset = math.abs(playerPos.y - otherCar.position.y)
      if otherCar.isActive and not (otherCar.isInPit or otherCar.isInPitlane) and zOffset < 2.8 then
        local otherPos = otherCar.position
        local otherLook = otherCar.look
        local otherAngle = math.atan2(otherLook.z, otherLook.x)
        local otherSize = vec2(otherCar.aabbSize.x * pixelsPerMeter, otherCar.aabbSize.z * pixelsPerMeter)
        local dx = otherPos.x - playerPos.x
        local dz = otherPos.z - playerPos.z
        local distanceSq = dx * dx + dz * dz

        if distanceSq <= rangeSq then
          local distance = math.sqrt(distanceSq)
          local carRadius = (otherCar.aabbSize.x + otherCar.aabbSize.z) / 4
          local effectiveDistance = math.max(0, distance - carRadius)
          if effectiveDistance < minDistanceFound then
            minDistanceFound = effectiveDistance
          end

          local xOffset = dx * rightX + dz * rightY
          local yOffset = dx * forwardX + dz * forwardY
          local otherScreenPos = vec2(radarCenter.x + xOffset * pixelsPerMeter, radarCenter.y - yOffset * pixelsPerMeter)
          local alpha = math.max(0, 1 - distance / range)
          if colorAlpha < alpha then
            colorAlpha = alpha
          end

          local otherColor = rgbm(0.9, 0.9, 0.9, colorAlpha)
          if otherCar.racePosition < playerCar.racePosition then
            otherColor = rgbm(0, 0.4, 1, colorAlpha)
          end

          ui.beginRotation()
          drawCar(otherScreenPos, otherSize, otherColor, showPosition and tostring(otherCar.racePosition) or nil, showPosition)
          ui.endRotation(math.deg(playerAngle - otherAngle) + 90)

          if distance < proximityDistance then
            if voiceEnabled then
              if not isCarRight then
                isCarRight = isCarOnSide(otherScreenPos, radarCenter, playerSize, proximityOffset, 'right')
              end
              if not isCarLeft then
                isCarLeft = isCarOnSide(otherScreenPos, radarCenter, playerSize, proximityOffset, 'left')
              end
            end

            if showSonar then
              local invLen = 1 / math.max(1e-12, math.sqrt(xOffset * xOffset + yOffset * yOffset))
              local direction = vec2(xOffset * invLen, -yOffset * invLen)
              drawArc(radarCenter, direction, arcRadius, arcAngle, 10, rgbm(1, 0.2, 0.2, 0.5))
            end
          end

          showRadar = true
        end
      end
    end
  end

  if showRadar or settingsPreview then
    if settingsPreview and colorAlpha < 0.8 then
      colorAlpha = 0.8
    end

    if voiceEnabled then
      if isCarLeft and canPlaySound(self.lastLeftSoundTime, currentTime, self.config.voiceRepeat) then
        self.leftSound:play()
        self.lastLeftSoundTime = currentTime
      end
      if isCarRight and canPlaySound(self.lastRightSoundTime, currentTime, self.config.voiceRepeat) then
        self.rightSound:play()
        self.lastRightSoundTime = currentTime
      end
    end

    if showLine then
      ui.drawLine(vec2(radarCenter.x, 22), vec2(radarCenter.x, fullWindowSize.y), rgbm(0.8, 0.8, 0.8, colorAlpha))
      ui.drawLine(vec2(0, radarCenter.y), vec2(windowSize.x, radarCenter.y), rgbm(0.8, 0.8, 0.8, colorAlpha))
    end

    if showCircle then
      local colorInner = rgbm(0.8, 0.8, 0.8, colorAlpha)
      local colorMiddle = rgbm(0.8, 0.8, 0.8, colorAlpha)
      local colorOuter = rgbm(0.8, 0.8, 0.8, colorAlpha)
      local offsetDistance = proximityDistance / 2

      if minDistanceFound <= proximityDistance + offsetDistance then
        colorOuter = rgbm(1, 0.6, 0.2, 0.5)
      end
      if minDistanceFound <= proximityDistance then
        colorMiddle = rgbm(1, 0.5, 0, colorAlpha)
        colorOuter = rgbm(1, 0.5, 0, colorAlpha)
      end

      local pulse = 1
      if minDistanceFound <= proximityDistance - offsetDistance then
        colorInner = rgbm(1, 0, 0, colorAlpha)
        pulse = 1 + math.sin(currentTime * 6) * 0.1
      end

      ui.drawCircle(radarCenter, (proximityDistance - offsetDistance) * pixelsPerMeter * pulse, colorInner, 30)
      ui.drawCircle(radarCenter, proximityDistance * pixelsPerMeter, colorMiddle, 40)
      ui.drawCircle(radarCenter, (proximityDistance + offsetDistance) * pixelsPerMeter, colorOuter, 50)
    end

    if settingsPreview then
      drawSideZone(radarCenter, playerSize, proximityOffset, 'left', rgbm(1, 1, 0, 0.30))
      drawSideZone(radarCenter, playerSize, proximityOffset, 'right', rgbm(1, 1, 0, 0.30))
    end

    drawCar(radarCenter, playerSize, rgbm(0.3, 0.6, 0.5, colorAlpha),
      showPosition and tostring(playerCar.racePosition) or nil, showPosition)
  end
end

function RadarView:drawSetup(sectionColor)
  local sim = ac.getSim()
  self.settingsPreviewUntil = sim.gameTime + 0.25
  ui.dwriteText('Voice', 16, sectionColor)
  ui.separator()

  if ui.checkbox('Voice', self.config.voice) then
    self.config.voice = not self.config.voice
  end
  self.config.voiceRepeat = ui.slider('##voiceRepeat', self.config.voiceRepeat, 1.0, 10.0, 'Voice Repeat Time: %1.0f')
  self.config.volume = ui.slider('##volume', self.config.volume * 100, 0.1, 100, 'Voice volume: %.1f') / 100
  if ui.itemEdited() then
    local finalVolume = (ac.getAudioVolume(ac.AudioChannel.Main) or 1) * self.config.volume
    self.leftSound:setVolume(finalVolume)
    self.rightSound:setVolume(finalVolume)
  end
  ui.dwriteText('Car', 16, sectionColor)
  ui.separator()

  if ui.checkbox('Show position on car', self.config.showPosition) then
    self.config.showPosition = not self.config.showPosition
  end
  if ui.checkbox('Show line', self.config.showLine) then
    self.config.showLine = not self.config.showLine
  end
  if ui.checkbox('Show circle', self.config.showCircle) then
    self.config.showCircle = not self.config.showCircle
  end
  if ui.checkbox('Show Sonar', self.config.showSonar) then
    self.config.showSonar = not self.config.showSonar
  end
  ui.dwriteText('Range', 16, sectionColor)
  ui.separator()
  self.config.range = ui.slider('##range', self.config.range, 10, 100, 'Radar Range: %.0fm')
  if ui.itemHovered() then
    ui.setTooltip('Distance to show cars on radar.')
  end

  self.config.proximityDistance = ui.slider('##Proximity', self.config.proximityDistance, 5, 20, 'Radar Proximity: %.0fm')
  if ui.itemHovered() then
    ui.setTooltip('Distance to show red proximity cone.')
  end

  local offsetDistance = self.config.proximityDistance / 2
  ui.text(string.format('Circles in meters: Inner %.1f / Middle %.1f / Outer %.1f',
    self.config.proximityDistance - offsetDistance,
    self.config.proximityDistance,
    self.config.proximityDistance + offsetDistance))
end

return RadarView
