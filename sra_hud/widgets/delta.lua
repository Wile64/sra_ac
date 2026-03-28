local DeltaWidget = {}
DeltaWidget.__index = DeltaWidget

local BASE_DELTA_HUD_SCALE = 0.90
local RESPONSE_TIME = 0.5
local POINT_EVERY_METERS = 5
local BASE_FONT_SIZE = 20
local MIN_CROSS_TIME = 1.0
local MINI_SECTOR_COUNT = 20
local DEBUG_DELTA_LOG = true

local function clamp01(x)
  if x < 0 then return 0 end
  if x > 1 then return 1 end
  return x
end

local function darkenColor(c, factor, multFactor)
  return rgbm(c.r * factor, c.g * factor, c.b * factor, c.mult * multFactor)
end

local function getDummyMidpoint(nameBase)
  local left = ac.findNodes(nameBase .. '_L')
  local right = ac.findNodes(nameBase .. '_R')
  if #left == 0 or #right == 0 then
    return 0
  end
  local midPoint = ac.worldCoordinateToTrackProgress((left:getPosition() + right:getPosition()) * 0.5)
  return midPoint
end

local function isCarInPit(car)
  return car and (
    car.isInPitlane
    or car.isInPit
  ) or false
end

local function formatLogValue(value)
  if value == nil then
    return 'nil'
  end
  if type(value) == 'boolean' then
    return value and 'true' or 'false'
  end
  if type(value) == 'number' then
    return string.format('%.6f', value)
  end
  return tostring(value)
end

function DeltaWidget:new()
  local sampleCount = math.max(1, math.floor(ac.getSim().trackLengthM / POINT_EVERY_METERS))
  local isP2PTrack = #ac.findNodes('AC_TIME_0_L') == 0
  local startPos = 0.0
  local finishPos = 1.0

  if isP2PTrack then
    startPos = getDummyMidpoint('AC_AB_START')
    finishPos = getDummyMidpoint('AC_AB_FINISH')
  else
    startPos = getDummyMidpoint('AC_TIME_0')
    finishPos = startPos
  end

  local selfRef = setmetatable({
    id = 'delta',
    title = 'Delta',
    windowId = 'windowDelta',
    lapRunning = false,
    lapStartTime = 0,
    deltaSmoothed = 0,
    currentLapTimes = {},
    referenceTimes = {},
    referenceLapTime = math.huge,
    referenceCompleted = false,
    sampleCount = sampleCount,
    samplesPerMiniSector = math.max(1, math.floor(sampleCount / MINI_SECTOR_COUNT)),
    miniSectorState = {},
    lastRecordedIndex = nil,
    lastRecordedTime = nil,
    lastStartTime = 0,
    lastFinishTime = 0,
    isP2PTrack = isP2PTrack,
    startPos = startPos,
    finishPos = finishPos,
    currentCar = nil,
    focusedCarID = 0,
    available = true,
    pitPaused = false,
    pitPauseStartedAt = 0,
    pausedDuration = 0,
  }, self)

  selfRef:registerCallbacks()
  selfRef:loadReferenceLap()
  return selfRef
end

function DeltaWidget:getFilePath()
  local layout = ac.getTrackLayout()
  if layout == nil then
    layout = ''
  end
  return ac.getFolder(ac.FolderID.ACDocuments) ..
      '/apps/sra_delta/' .. ac.getCarID(self.focusedCarID) .. '/' .. ac.getTrackID() .. '/' .. layout
end

function DeltaWidget:getFileName()
  return '/delta.csv'
end

function DeltaWidget:getLogFileName()
  return '/delta_debug.log'
end

function DeltaWidget:logEvent(eventName, values)
  if not DEBUG_DELTA_LOG then
    return
  end

  local filePath = self:getFilePath()
  if not io.dirExists(filePath) then
    io.createDir(filePath)
  end

  local f = io.open(filePath .. self:getLogFileName(), 'a')
  if not f then
    return
  end

  local parts = { os.date('%Y-%m-%d %H:%M:%S'), eventName }
  if values then
    for key, value in pairs(values) do
      parts[#parts + 1] = string.format('%s=%s', key, formatLogValue(value))
    end
  end
  f:write(table.concat(parts, ' | ') .. '\n')
  f:close()
end

function DeltaWidget:canStoreReference()
  return self.currentCar ~= nil and (self.currentCar.isUserControlled or self.focusedCarID == 0)
end

function DeltaWidget:saveReference()
  if not self:canStoreReference() then
    return
  end

  local filePath = self:getFilePath()
  if not io.dirExists(filePath) then
    io.createDir(filePath)
  end

  local f = io.open(filePath .. self:getFileName(), 'w')
  if not f then
    return
  end

  f:write(string.format('%.3f\n', self.referenceLapTime))
  for i = 1, self.sampleCount do
    local v = self.referenceTimes[i]
    if v then
      f:write(string.format('%d,%.3f\n', i, v))
    end
  end
  f:close()
  self:logEvent('save_reference', {
    referenceLapTime = self.referenceLapTime,
    sampleCount = self.sampleCount,
    focusedCarID = self.focusedCarID,
  })
end

function DeltaWidget:loadReferenceLap()
  local f = io.open(self:getFilePath() .. self:getFileName(), 'r')
  if not f then
    return false
  end

  self.referenceTimes = {}
  local lineIndex = 0
  for line in f:lines() do
    if lineIndex == 0 then
      self.referenceLapTime = tonumber(line) or math.huge
    else
      local index, value = line:match('(%d+),([%d%.]+)')
      if index and value then
        self.referenceTimes[tonumber(index)] = tonumber(value)
      end
    end
    lineIndex = lineIndex + 1
  end
  f:close()
  self.referenceCompleted = true
  self:logEvent('load_reference', {
    referenceLapTime = self.referenceLapTime,
    loadedSamples = lineIndex - 1,
    focusedCarID = self.focusedCarID,
  })
  return true
end

function DeltaWidget:resetReference()
  self.referenceTimes = {}
  self.referenceCompleted = false
  self.referenceLapTime = math.huge
  self.currentLapTimes = {}
  self.deltaSmoothed = 0
  self.miniSectorState = {}
  self.lapRunning = false
  self.lapStartTime = 0
  self.lastStartTime = -math.huge
  self.lastFinishTime = -math.huge
  self.lastRecordedIndex = nil
  self.lastRecordedTime = nil
  self.pitPaused = false
  self.pitPauseStartedAt = 0
  self.pausedDuration = 0
  os.remove(self:getFilePath() .. self:getFileName())
  self:logEvent('reset_reference', {
    focusedCarID = self.focusedCarID,
  })
end

function DeltaWidget:setFocusedCar(car)
  local focusedCarID = car and car.index or 0
  if self.focusedCarID == focusedCarID then
    self.currentCar = car
    return
  end

  self.focusedCarID = focusedCarID
  self.currentCar = car
  self.currentLapTimes = {}
  self.deltaSmoothed = 0
  self.miniSectorState = {}
  self.lapRunning = false
  self.lapStartTime = 0
  self.lastStartTime = -math.huge
  self.lastFinishTime = -math.huge
  self.lastRecordedIndex = nil
  self.lastRecordedTime = nil
  self.pitPaused = false
  self.pitPauseStartedAt = 0
  self.pausedDuration = 0
  self.referenceTimes = {}
  self.referenceCompleted = false
  self.referenceLapTime = math.huge
  self:logEvent('set_focused_car', {
    previousFocusedCarID = self.focusedCarID,
    newFocusedCarID = focusedCarID,
    carID = car and ac.getCarID(car.index) or 'nil',
  })
  self:loadReferenceLap()
end

function DeltaWidget:getRunProgress(spline)
  spline = clamp01(spline)

  if not self.isP2PTrack then
    local rel = spline - self.startPos
    if rel < 0 then
      rel = rel + 1.0
    end
    return clamp01(rel)
  end

  local runLength = self.finishPos - self.startPos
  if runLength < 0 then
    runLength = runLength + 1.0
  end
  if runLength <= 1e-6 then
    return 0
  end

  local rel = spline - self.startPos
  if rel < 0 then
    rel = rel + 1.0
  end
  return clamp01(rel / runLength)
end

function DeltaWidget:progressToIndex(progress)
  return math.floor(clamp01(progress) * (self.sampleCount - 1)) + 1
end

function DeltaWidget:getSeriesTimeAt(values, index)
  local exact = values[index]
  if exact ~= nil then
    return exact
  end

  local prevIndex = nil
  for i = index - 1, 1, -1 do
    if values[i] ~= nil then
      prevIndex = i
      break
    end
  end

  local nextIndex = nil
  for i = index + 1, self.sampleCount do
    if values[i] ~= nil then
      nextIndex = i
      break
    end
  end

  if prevIndex and nextIndex then
    local span = nextIndex - prevIndex
    local t = span > 0 and ((index - prevIndex) / span) or 0
    return values[prevIndex] + (values[nextIndex] - values[prevIndex]) * t
  end

  if prevIndex then
    return values[prevIndex]
  end

  if nextIndex then
    return values[nextIndex]
  end

  return nil
end

function DeltaWidget:effectiveNow(now)
  if self.pitPaused then
    return self.pitPauseStartedAt - self.pausedDuration
  end
  return now - self.pausedDuration
end

function DeltaWidget:onCrossedStartLine(carID, timer)
  if carID ~= self.focusedCarID then
    return
  end
  if timer - self.lastStartTime < MIN_CROSS_TIME then
    self:logEvent('start_ignored', {
      carID = carID,
      timer = timer,
      lastStartTime = self.lastStartTime,
      delta = timer - self.lastStartTime,
    })
    return
  end

  self.lastStartTime = timer
  self.lapRunning = true
  self.lapStartTime = timer
  self.deltaSmoothed = 0
  self.currentLapTimes = {}
  self.miniSectorState = {}
  self.lastRecordedIndex = nil
  self.lastRecordedTime = nil
  self.pitPaused = false
  self.pitPauseStartedAt = 0
  self.pausedDuration = 0
  self:logEvent('cross_start', {
    carID = carID,
    timer = timer,
    lapRunning = self.lapRunning,
    spline = self.currentCar and self.currentCar.splinePosition or nil,
    lapCount = self.currentCar and self.currentCar.lapCount or nil,
  })
end

function DeltaWidget:onCrossedFinishLine(carID, timer)
  if carID ~= self.focusedCarID or not self.lapRunning then
    self:logEvent('finish_ignored', {
      carID = carID,
      timer = timer,
      lapRunning = self.lapRunning,
      focusedCarID = self.focusedCarID,
    })
    return
  end
  if timer - self.lastFinishTime < MIN_CROSS_TIME then
    self:logEvent('finish_ignored', {
      carID = carID,
      timer = timer,
      lastFinishTime = self.lastFinishTime,
      delta = timer - self.lastFinishTime,
    })
    return
  end

  self.lastFinishTime = timer
  self.lapRunning = false
  self.pitPaused = false
  local lapDuration = self:effectiveNow(timer) - self.lapStartTime
  self:logEvent('cross_finish', {
    carID = carID,
    timer = timer,
    lapDuration = lapDuration,
    lapStartTime = self.lapStartTime,
    previousLapTimeMs = self.currentCar and self.currentCar.previousLapTimeMs or nil,
    lapCount = self.currentCar and self.currentCar.lapCount or nil,
    spline = self.currentCar and self.currentCar.splinePosition or nil,
  })
  if self:canStoreReference() and lapDuration < self.referenceLapTime then
    self.referenceLapTime = lapDuration
    self.referenceTimes = self.currentLapTimes
    self.referenceCompleted = true
    self:saveReference()
  end
end

function DeltaWidget:onCrossedLoopStartFinish(carID, timer)
  if carID ~= self.focusedCarID then
    return
  end
  self:logEvent('cross_loop', {
    carID = carID,
    timer = timer,
    lapRunning = self.lapRunning,
    spline = self.currentCar and self.currentCar.splinePosition or nil,
    lapCount = self.currentCar and self.currentCar.lapCount or nil,
    previousLapTimeMs = self.currentCar and self.currentCar.previousLapTimeMs or nil,
  })
  if self.lapRunning then
    self:onCrossedFinishLine(carID, timer)
  end
  self:onCrossedStartLine(carID, timer)
end

function DeltaWidget:registerCallbacks()
  if self.isP2PTrack then
    ac.onTrackPointCrossed(0, self.finishPos, function(carID, timer)
      self:onCrossedFinishLine(carID, timer)
    end)
    ac.onTrackPointCrossed(0, self.startPos, function(carID, timer)
      self:onCrossedStartLine(carID, timer)
    end)
  else
    ac.onTrackPointCrossed(0, self.startPos, function(carID, timer)
      self:onCrossedLoopStartFinish(carID, timer)
    end)
  end
end

function DeltaWidget:update(dt, context)
  local car = context.car
  local sim = context.sim
  self:setFocusedCar(car)
  self.available = self:canStoreReference()
  if not self.available then
    self.deltaSmoothed = 0
    self.lapRunning = false
    self.pitPaused = false
    self:logEvent('unavailable', {
      focusedCarID = self.focusedCarID,
      currentCarIndex = car and car.index or nil,
    })
    return
  end
  if not car or not sim then
    return
  end

  local now = sim.time
  local inPit = isCarInPit(car)
  if not self.lapRunning then
    return
  end
  if inPit then
    if not self.pitPaused then
      self.pitPaused = false
      self.pitPauseStartedAt = 0
      self.pausedDuration = 0
      self.lapRunning = false
      self.deltaSmoothed = 0
      self.currentLapTimes = {}
      self.miniSectorState = {}
      self.lastRecordedIndex = nil
      self.lastRecordedTime = nil
      self:logEvent('pit_invalidate_lap', {
        simTime = now,
        lapStartTime = self.lapStartTime,
        spline = car.splinePosition,
      })
    end
    return
  end

  local spline = car.splinePosition
  local lapTimeNow = self:effectiveNow(now) - self.lapStartTime
  local runProgress = self:getRunProgress(spline)
  local index = self:progressToIndex(runProgress)

  if self.lastRecordedIndex ~= nil and index > self.lastRecordedIndex then
    local fromIndex = self.lastRecordedIndex
    local fromTime = self.lastRecordedTime or lapTimeNow
    local span = index - fromIndex
    for i = fromIndex + 1, index do
      if not self.currentLapTimes[i] then
        local t = span > 0 and ((i - fromIndex) / span) or 1
        self.currentLapTimes[i] = fromTime + (lapTimeNow - fromTime) * t
      end
    end
  elseif not self.currentLapTimes[index] then
    self.currentLapTimes[index] = lapTimeNow
  end

  self.lastRecordedIndex = index
  self.lastRecordedTime = lapTimeNow

  if self.referenceCompleted then
    local x = clamp01(runProgress) * (self.sampleCount - 1)
    local i1 = math.floor(x) + 1
    local i2 = math.min(i1 + 1, self.sampleCount)
    local f = x - math.floor(x)
    local t1 = self:getSeriesTimeAt(self.referenceTimes, i1)
    local t2 = self:getSeriesTimeAt(self.referenceTimes, i2)

    local refTime = nil
    if t1 and t2 then
      refTime = t1 + (t2 - t1) * f
    else
      refTime = t1 or t2
    end

    if refTime then
      local rawDelta = lapTimeNow - refTime
      local alpha = dt / (RESPONSE_TIME + dt)
      self.deltaSmoothed = self.deltaSmoothed * (1 - alpha) + rawDelta * alpha
    end
  end

  if context.deltaShowSectorBar and self.referenceCompleted then
    local currentMini = math.floor((index - 1) / self.samplesPerMiniSector) + 1
    currentMini = math.min(currentMini, MINI_SECTOR_COUNT)

    for miniIndex = 1, currentMini do
      local endIdx = math.min(miniIndex * self.samplesPerMiniSector, self.sampleCount)
      if endIdx > index then
        break
      end

      local startIdx = math.max(endIdx - self.samplesPerMiniSector + 1, 1)
      local currentStartTime = startIdx == 1 and 0 or self:getSeriesTimeAt(self.currentLapTimes, startIdx)
      local referenceStartTime = startIdx == 1 and 0 or self:getSeriesTimeAt(self.referenceTimes, startIdx)
      local currentEndTime = self:getSeriesTimeAt(self.currentLapTimes, endIdx)
      local referenceEndTime = self:getSeriesTimeAt(self.referenceTimes, endIdx)

      if self.miniSectorState[miniIndex] == nil
          and currentEndTime ~= nil
          and referenceEndTime ~= nil
          and currentStartTime ~= nil
          and referenceStartTime ~= nil then
        local curDelta = currentEndTime - currentStartTime
        local refDelta = referenceEndTime - referenceStartTime
        local diff = curDelta - refDelta
        local threshold = context.deltaSectorThresholdMs or 30

        if diff < -threshold then
          self.miniSectorState[miniIndex] = 1
        elseif diff > threshold then
          self.miniSectorState[miniIndex] = -1
        else
          self.miniSectorState[miniIndex] = 0
        end
      end
    end
  end
end

function DeltaWidget:getCurrentMiniSector(index)
  local miniIndex = math.floor((index - 1) / self.samplesPerMiniSector) + 1
  return math.min(miniIndex, MINI_SECTOR_COUNT)
end

function DeltaWidget:drawMiniSectors(index, scale, pos, width, borderColor, colors)
  local spacing = 3 * scale
  local squareWidth = 13 * scale
  local squareHeight = 13 * scale
  local rowWidth = MINI_SECTOR_COUNT * squareWidth + (MINI_SECTOR_COUNT - 1) * spacing
  if rowWidth > width then
    squareWidth = (width - (MINI_SECTOR_COUNT - 1) * spacing) / MINI_SECTOR_COUNT
    squareHeight = squareWidth
    rowWidth = width
  end

  local startX = pos.x + (width - rowWidth) * 0.5
  local cursorMini = self:getCurrentMiniSector(index)
  local car = self.currentCar or ac.getCar(self.focusedCarID)
  local runProgress = car and self:getRunProgress(car.splinePosition) or 0
  local miniProgress = runProgress * MINI_SECTOR_COUNT
  local intraProgress = miniProgress - math.floor(miniProgress)

  local progressH = 5 * scale
  local progressBgA = vec2(startX, pos.y)
  local progressBgB = vec2(startX + rowWidth, pos.y + progressH)
  ui.drawRectFilled(progressBgA, progressBgB, colors.backgroundAlt, 3 * scale)
  ui.drawRect(progressBgA, progressBgB, borderColor, 3 * scale)
  ui.drawRectFilled(progressBgA, vec2(startX + rowWidth * intraProgress, pos.y + progressH), colors.valueNeutral, 3 * scale)

  local cursorPos = pos + vec2(0, progressH + 4 * scale)
  for i = 1, MINI_SECTOR_COUNT do
    local color = self.style.delta.off
    if self.miniSectorState[i] == 1 then
      color = self.style.delta.purple
    elseif self.miniSectorState[i] == 0 then
      color = self.style.delta.green
    elseif self.miniSectorState[i] == -1 then
      color = self.style.delta.red
    end

    local x = startX + (i - 1) * (squareWidth + spacing)
    local p1 = vec2(x, cursorPos.y)
    local p2 = p1 + vec2(squareWidth, squareHeight)
    ui.drawRectFilled(p1, p2, colors.backgroundAlt, 2 * scale)
    if self.miniSectorState[i] ~= nil then
      ui.drawRectFilled(p1 - vec2(1, 1) * scale, p2 + vec2(1, 1) * scale, rgbm(color.r, color.g, color.b, 0.14), 3 * scale)
      ui.drawRectFilled(p1, p2, color, 2 * scale)
      ui.drawRect(p1, p2, rgbm(color.r, color.g, color.b, 0.95), 2 * scale)
    else
      ui.drawRect(p1, p2, rgbm(colors.border.r, colors.border.g, colors.border.b, 0.16), 2 * scale)
    end
    if i == cursorMini then
      ui.drawRect(p1 - vec2(1, 1), p2 + vec2(1, 1), colors.border, 2 * scale)
    end
  end

  return progressH + 4 * scale + squareHeight
end

function DeltaWidget:drawDeltaBar(deltaMs, scale, barPosition, deltaBarWidth, borderColor, colors)
  local deltaBarHeight = 10 * scale
  local maxDelta = 2000
  local clamped = math.max(-maxDelta, math.min(maxDelta, deltaMs))
  local normalized = clamped / maxDelta
  local absWidth = math.abs(normalized) * (deltaBarWidth * 0.5)
  local center = barPosition + vec2(deltaBarWidth * 0.5, 0)
  local bg = darkenColor(colors.border, 0.18, 0.60)

  local barColor = colors.valueEdit
  if deltaMs < -10 then
    barColor = self.style.delta.green
  elseif deltaMs > 10 then
    barColor = self.style.delta.red
  end

  local barEnd = center + vec2(absWidth * (deltaMs < 0 and -1 or 1), 0)
  ui.drawRectFilled(barPosition, barPosition + vec2(deltaBarWidth, deltaBarHeight), bg, 4 * scale)
  if absWidth > 0 then
    local fillA = deltaMs < 0 and barEnd or center
    local fillB = deltaMs < 0 and center or barEnd
    ui.drawRectFilled(fillA - vec2(1, 1) * scale, fillB + vec2(0, deltaBarHeight) + vec2(1, 1) * scale,
      rgbm(barColor.r, barColor.g, barColor.b, 0.14), 4 * scale)
    ui.drawRectFilled(fillA, fillB + vec2(0, deltaBarHeight), barColor, 2 * scale)
  end
  ui.drawRect(barPosition, barPosition + vec2(deltaBarWidth, deltaBarHeight), borderColor)
  ui.drawRect(center, center + vec2(1, deltaBarHeight), borderColor)
  return deltaBarHeight
end

function DeltaWidget:draw(dt, drawContext)
  if not self.available then
    return
  end

  local scale = (drawContext.scale or 1) * (drawContext.deltaScale or 1) * BASE_DELTA_HUD_SCALE
  local colors = drawContext.colors
  self.style = drawContext.style
  local font = drawContext.font
  local showSectorBar = drawContext.deltaShowSectorBar ~= false
  local showDeltaBar = drawContext.deltaShowDeltaBar ~= false
  local showRefLap = drawContext.deltaShowRefLap ~= false

  local panelPos = ui.getCursor()
  local panelWidth = 320 * scale
  local panelHeight = 38 * scale
  if showSectorBar then panelHeight = panelHeight + 20 * scale end
  if showDeltaBar then panelHeight = panelHeight + 23 * scale end
  if showRefLap then panelHeight = panelHeight + 16 * scale end
  local panelSize = vec2(panelWidth, panelHeight)

  local contentPos = panelPos + vec2(8, 5) * scale
  local contentWidth = panelWidth - 16 * scale
  local y = contentPos.y

  ui.pushDWriteFont(font.police)
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(0, 0))

  ui.drawRectFilled(panelPos, panelPos + panelSize, colors.background, 8 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)
  ui.drawRect(panelPos, panelPos + panelSize - 1, colors.border, 8 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)

  local deltaMs = self.deltaSmoothed
  local textColor = deltaMs < 0 and self.style.delta.green or self.style.delta.red
  local deltaText = string.format('%+0.3fs', deltaMs * 0.001)
  if math.abs(deltaMs) < 0.0005 then
    textColor = colors.valueNeutral
  end
  if isCarInPit(self.currentCar) then
    deltaText = 'IN PIT'
    textColor = colors.valueEdit
  end

  if showSectorBar then
    local sectorIndex = 1
    if self.lapRunning and self.currentCar then
      sectorIndex = self:progressToIndex(self:getRunProgress(self.currentCar.splinePosition))
    end
    y = y + self:drawMiniSectors(sectorIndex, scale, vec2(contentPos.x, y), contentWidth, colors.border, colors)
    y = y + 6 * scale
  end

  if showDeltaBar then
    y = y + 1 * scale
    y = y + self:drawDeltaBar(deltaMs, scale, vec2(contentPos.x, y), contentWidth, colors.border, colors)
    y = y + 6 * scale
  end

  ui.dwriteDrawTextClipped(deltaText, (BASE_FONT_SIZE + 4) * scale,
    vec2(contentPos.x, y), vec2(contentPos.x + contentWidth, y + 20 * scale),
    ui.Alignment.Center, ui.Alignment.Center, false, textColor)
  y = y + 24 * scale

  if showRefLap then
    local refText = self.referenceCompleted and ('Reference lap: ' .. ac.lapTimeToString(self.referenceLapTime))
        or 'Reference lap: loading...'
    local buttonWidth = 42 * scale
    local buttonHeight = 14 * scale
    local buttonPos = vec2(contentPos.x + contentWidth - buttonWidth, y)
    ui.dwriteDrawTextClipped(refText, (BASE_FONT_SIZE - 4) * scale, vec2(contentPos.x, y),
      vec2(buttonPos.x - 6 * scale, y + 14 * scale), ui.Alignment.Center, ui.Alignment.Center, false, colors.label)
    ui.setCursor(buttonPos)
    if ui.button('Reset', vec2(buttonWidth, buttonHeight)) then
      self:resetReference()
    end
  end

  ui.dummy(panelSize)
  ui.popStyleVar()
  ui.popDWriteFont()
end

return DeltaWidget
