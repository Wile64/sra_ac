local LeaderboardWidget = {}
LeaderboardWidget.__index = LeaderboardWidget

local MIN_SPEED_FOR_GAP = 5
local MAX_GAP_DISPLAY = 99.99
local POSITION_CHANGE_HOLD = 4.0
local LAST_LAP_HOLD = 5.0
local DEBUG_LEADERBOARD_BOUNDS = false
local nationFlagPathCache = {}
local badgePathCache = {}
local rootFolder = ac.getFolder(ac.FolderID.Root)
local contentCarsFolder = ac.getFolder(ac.FolderID.ContentCars)

local function shortenName(name)
  if not name or name == '' then
    return 'Unknown'
  end

  local parts = {}
  for part in string.gmatch(name, '%S+') do
    parts[#parts + 1] = part
  end

  if #parts >= 2 then
    local compact = parts[1]:sub(1, 1):lower() .. '.' .. parts[#parts]:lower()
    if #compact <= 16 then
      return compact
    end
    return compact:sub(1, 13) .. '...'
  end

  if #name <= 16 then
    return name
  end
  return name:sub(1, 13) .. '...'
end

local function compactLapTime(ms)
  if not ms or ms <= 0 then
    return '--:--'
  end
  return ac.lapTimeToString(ms)
end

local function getNationFlagPath(nationCode)
  if not nationCode or nationCode == '' then
    return nil
  end
  local cached = nationFlagPathCache[nationCode]
  if cached ~= nil then
    return cached or nil
  end
  local filePath = rootFolder .. string.format('/content/gui/NationFlags/%s.png', nationCode)
  nationFlagPathCache[nationCode] = io.fileExists(filePath) and filePath or false
  return nationFlagPathCache[nationCode] or nil
end

local function getBadgePath(carId)
  if not carId or carId == '' then
    return nil
  end
  local cached = badgePathCache[carId]
  if cached ~= nil then
    return cached or nil
  end
  local filePath = contentCarsFolder .. string.format('/%s/ui/badge.png', carId)
  badgePathCache[carId] = io.fileExists(filePath) and filePath or false
  return badgePathCache[carId] or nil
end

local function buildVisibleIndexes(entries, focusedIndex, visibleRows, mode)
  if mode == 1 then
    local result = {}
    for i = 1, math.min(#entries, visibleRows) do
      result[#result + 1] = i
    end
    return result
  end

  if mode == 3 and visibleRows >= 2 then
    local result = { 1 }
    local remainingRows = visibleRows - 1
    local startIndex = math.max(1, focusedIndex - math.floor(remainingRows / 2))
    local endIndex = math.min(#entries, startIndex + remainingRows - 1)
    startIndex = math.max(1, endIndex - remainingRows + 1)
    for i = startIndex, endIndex do
      if i ~= 1 then
        result[#result + 1] = i
      end
    end
    return result
  end

  local result = {}
  local startIndex = math.max(1, focusedIndex - math.floor(visibleRows / 2))
  local endIndex = math.min(#entries, startIndex + visibleRows - 1)
  startIndex = math.max(1, endIndex - visibleRows + 1)
  for i = startIndex, endIndex do
    result[#result + 1] = i
  end
  return result
end

local function isLeaderboardCar(car)
  if not car then
    return false
  end
  if (car.racePosition or 0) <= 0 then
    return false
  end
  return car.isActive == nil or car.isActive or car.isRetired
end

local function getRelativeGapSeconds(trackLength, focused, player)
  if not focused or not player or focused.index == player.index then
    return 0
  end
  if trackLength <= 0 then
    return 0
  end
  if player.isInPit then
    return 0
  end

  local focusedPosM = focused.trackPosM or (focused.splinePosition * trackLength)
  local playerPosM = player.trackPosM or (player.splinePosition * trackLength)

  local forwardDist = (playerPosM - focusedPosM) % trackLength
  local backwardDist = trackLength - forwardDist
  local isAhead = forwardDist <= backwardDist
  local dist = isAhead and forwardDist or backwardDist

  local speed = (focused.speed + player.speed) * 0.5
  if speed < MIN_SPEED_FOR_GAP then
    speed = math.max(focused.speed, player.speed, MIN_SPEED_FOR_GAP)
  end

  local gap = dist / speed
  gap = isAhead and gap or -gap
  if gap > MAX_GAP_DISPLAY then
    return MAX_GAP_DISPLAY
  end
  if gap < -MAX_GAP_DISPLAY then
    return -MAX_GAP_DISPLAY
  end
  return gap
end

local function formatGap(entry, referenceEntry, gapSeconds, colors)
  if entry.isRetired then
    return 'DNF', colors.valueNegative
  end

  if not entry.isActive then
    return 'OUT', colors.valueNegative
  end

  if entry.isInPit then
    return 'PIT', colors.valueEdit
  end

  if entry.lapDisplayText then
    return entry.lapDisplayText, entry.lapDisplayColor
  end

  if entry.isFocused then
    return 'FOCUS', colors.valueNeutral
  end

  if referenceEntry and entry.index == referenceEntry.index then
    if entry.position == 1 then
      return 'LEAD', colors.valueStatic
    end
    return '--', colors.valueNeutral
  end

  local lapDelta = (entry.lapCount or 0) - (referenceEntry.lapCount or 0)
  if lapDelta ~= 0 then
    return string.format('%+dL', lapDelta), lapDelta > 0 and colors.valueNegative or colors.valuePositive
  end

  return string.format('%+.2fs', gapSeconds), gapSeconds <= 0 and colors.valuePositive or colors.valueNegative
end

function LeaderboardWidget:new()
  return setmetatable({
    id = 'leaderboard',
    title = 'Leaderboard',
    windowId = 'windowLeaderboard',
    entries = {},
    focusedPosition = 1,
    focusedCarIndex = 0,
    trackLength = ac.getSim().trackLengthM or 0,
    previousPositions = {},
    previousLapCounts = {},
    positionChangeState = {},
    lapDisplayState = {},
  }, self)
end

function LeaderboardWidget:update(dt, context)
  local sim = context.sim
  local focusedCarIndex = context.car and context.car.index or 0
  if not sim then
    return
  end

  local entries = {}
  local focusedPosition = 1
  for i = 0, (sim.carsCount or 0) - 1 do
    local car = ac.getCar(i)
    if isLeaderboardCar(car) then
      local previousPosition = self.previousPositions[i]
      local rawPositionDelta = previousPosition and (previousPosition - car.racePosition) or 0
      local persistedChange = self.positionChangeState[i]
      if rawPositionDelta ~= 0 then
        persistedChange = {
          delta = rawPositionDelta,
          timer = POSITION_CHANGE_HOLD,
        }
      elseif persistedChange then
        persistedChange.timer = math.max(0, (persistedChange.timer or 0) - dt)
        if persistedChange.timer <= 0 then
          persistedChange = nil
        end
      end

      self.positionChangeState[i] = persistedChange
      local currentLapCount = car.lapCount or 0
      local previousLapCount = self.previousLapCounts[i]
      local lapDisplay = self.lapDisplayState[i]
      if previousLapCount and currentLapCount > previousLapCount and (car.previousLapTimeMs or 0) > 0 then
        local isBestLap = car.isLastLapValid ~= false
            and math.abs((car.previousLapTimeMs or 0) - (car.bestLapTimeMs or 0)) <= 1
        lapDisplay = {
          timer = LAST_LAP_HOLD,
          text = compactLapTime(car.previousLapTimeMs or 0),
          color = isBestLap and context.colors.valueBestTime or context.colors.valueStatic,
          isBest = isBestLap,
        }
      elseif lapDisplay then
        lapDisplay.timer = math.max(0, (lapDisplay.timer or 0) - dt)
        if lapDisplay.timer <= 0 then
          lapDisplay = nil
        end
      end
      self.lapDisplayState[i] = lapDisplay
      local entry = {
        index = i,
        position = car.racePosition,
        positionDelta = persistedChange and persistedChange.delta or 0,
        name = shortenName(ac.getDriverName(i) or ('Car ' .. tostring(i + 1))),
        lapCount = car.lapCount or 0,
        lastLapTimeMs = car.previousLapTimeMs or 0,
        bestLapTimeMs = car.bestLapTimeMs or 0,
        compound = ac.getTyresName(i, car.compoundIndex or 0) or '--',
        nationCode = ac.getDriverNationCode(i),
        carId = ac.getCarID(i),
        isFocused = i == focusedCarIndex,
        splinePosition = car.splinePosition or 0,
        trackPosM = (car.splinePosition or 0) * self.trackLength,
        speed = car.speedMs or 0,
        isActive = car.isActive == nil or car.isActive,
        isRetired = car.isRetired or false,
        isInPit = car.isInPitlane or car.isInPit or false,
        lapDisplayText = lapDisplay and lapDisplay.text or nil,
        lapDisplayColor = lapDisplay and lapDisplay.color or nil,
        isDisplayedBestLap = lapDisplay and lapDisplay.isBest or false,
        gap = 0,
      }
      entries[#entries + 1] = entry
      if entry.isFocused then
        focusedPosition = entry.position
      end
    end
  end

  table.sort(entries, function(a, b)
    return a.position < b.position
  end)

  local focused = nil
  for i = 1, #entries do
    if entries[i].isFocused then
      focused = entries[i]
      break
    end
  end

  if focused then
    for i = 1, #entries do
      if not entries[i].isFocused then
        entries[i].gap = getRelativeGapSeconds(self.trackLength, focused, entries[i])
      end
    end
  end

  self.previousPositions = {}
  self.previousLapCounts = {}
  local activeIndexes = {}
  for i = 1, #entries do
    self.previousPositions[entries[i].index] = entries[i].position
    self.previousLapCounts[entries[i].index] = entries[i].lapCount
    activeIndexes[entries[i].index] = true
  end

  for index, persistedChange in pairs(self.positionChangeState) do
    if not activeIndexes[index] then
      persistedChange.timer = math.max(0, (persistedChange.timer or 0) - dt)
      if persistedChange.timer <= 0 then
        self.positionChangeState[index] = nil
      end
    end
  end

  for index, lapDisplay in pairs(self.lapDisplayState) do
    if not activeIndexes[index] then
      lapDisplay.timer = math.max(0, (lapDisplay.timer or 0) - dt)
      if lapDisplay.timer <= 0 then
        self.lapDisplayState[index] = nil
      end
    end
  end

  self.entries = entries
  self.focusedPosition = focusedPosition
  self.focusedCarIndex = focusedCarIndex
end

function LeaderboardWidget:draw(dt, drawContext)
  local scale = (drawContext.scale or 1) * (drawContext.leaderboardScale or 1)
  local colors = drawContext.colors
  local font = drawContext.font
  local visibleRows = math.max(3, math.floor(drawContext.leaderboardRows or 7))
  local mode = math.max(1, math.min(3, drawContext.leaderboardMode or 2))
  local showPositionChange = drawContext.leaderboardShowPositionChange ~= false
  local showLap = drawContext.leaderboardShowLap == true
  local showCompoundColumn = drawContext.leaderboardShowCompoundColumn == true
  local showNationFlag = drawContext.leaderboardShowNationFlag == true
  local showCarLogo = drawContext.leaderboardShowCarLogo == true

  if #self.entries == 0 then
    return
  end

  local focusedIndex = 1
  for i = 1, #self.entries do
    if self.entries[i].isFocused then
      focusedIndex = i
      break
    end
  end

  local visibleIndexes = buildVisibleIndexes(self.entries, focusedIndex, visibleRows, mode)

  local panelPos = ui.getCursor()
  local baseWidth = 336 * scale
  local flagWidth = showNationFlag and (22 * scale) or 0
  local logoWidth = showCarLogo and (24 * scale) or 0
  local compoundWidth = showCompoundColumn and (34 * scale) or 0
  local lapWidth = showLap and (36 * scale) or 0
  local width = baseWidth + flagWidth + logoWidth + compoundWidth + lapWidth
  local rowHeight = 30 * scale
  local headerHeight = 24 * scale
  local height = headerHeight + #visibleIndexes * rowHeight
  local panelSize = vec2(width, height)

  ui.pushDWriteFont(font.police)
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(0, 0))

  ui.drawRectFilled(panelPos, panelPos + panelSize, colors.background, 8 * scale,
    ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)
  ui.drawRect(panelPos, panelPos + panelSize, colors.border, 8 * scale,
    ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)

  local headerTextA = panelPos + vec2(8 * scale, 0)
  local headerTextB = panelPos + vec2(width - 8 * scale, headerHeight)
  ui.dwriteDrawTextClipped('LEADERBOARD', font.size * 0.82 * scale, headerTextA,
    headerTextB, ui.Alignment.Center, ui.Alignment.Center, false, colors.label)
  if DEBUG_LEADERBOARD_BOUNDS then
    ui.drawRect(headerTextA, headerTextB, rgbm(1, 0, 0, 1), 0, nil, 1)
  end

  local y = panelPos.y + headerHeight
  local focused = self.entries[focusedIndex]
  local gapReference = mode == 1 and self.entries[1] or focused
  local posBoxWidth = 32 * scale
  local changeWidth = showPositionChange and (26 * scale) or 0
  local nameWidth = 152 * scale
  local gapWidth = 76 * scale
  local mediaGap = 4 * scale
  local compoundGap = 4 * scale
  local posLeft = 10 * scale
  local changeLeft = posLeft + posBoxWidth + 4 * scale
  local flagLeft = changeLeft + changeWidth + (showPositionChange and 4 * scale or 0)
  local logoLeft = flagLeft + flagWidth + (showNationFlag and mediaGap or 0)
  local nameLeftOffset = logoLeft + logoWidth + ((showNationFlag or showCarLogo) and 6 * scale or 0)
  for visibleIndex = 1, #visibleIndexes do
    local i = visibleIndexes[visibleIndex]
    local entry = self.entries[i]
    local rowA = vec2(panelPos.x, y)
    local rowB = vec2(panelPos.x + width, y + rowHeight)
    local isLeader = entry.position == 1 and not entry.isFocused
    local rowColor = entry.isFocused and colors.selection
        or (isLeader and rgbm(colors.valueStatic.r, colors.valueStatic.g, colors.valueStatic.b, 0.16))
        or ((visibleIndex - 1) % 2 == 1 and colors.rowStripe or colors.transparent)
    local textColor = entry.isFocused and colors.valueEdit or colors.valueNeutral
    if entry.isDisplayedBestLap then
      textColor = colors.valueBestTime
    end

    if rowColor.mult > 0 then
      ui.drawRectFilled(rowA + vec2(4 * scale, 1 * scale), rowB - vec2(4 * scale, 1 * scale), rowColor, 5 * scale)
    end
    if entry.isFocused then
      ui.drawRectFilled(rowA + vec2(4 * scale, 1 * scale), rowA + vec2(8 * scale, rowHeight - 1 * scale),
        colors.valueEdit, 4 * scale)
      ui.drawRect(rowA + vec2(4 * scale, 1 * scale), rowB - vec2(4 * scale, 1 * scale),
        rgbm(colors.valueEdit.r, colors.valueEdit.g, colors.valueEdit.b, 0.55), 5 * scale)
    elseif isLeader then
      ui.drawRectFilled(rowA + vec2(4 * scale, 1 * scale), rowA + vec2(8 * scale, rowHeight - 1 * scale), colors
      .valueStatic, 4 * scale)
      ui.drawRect(rowA + vec2(4 * scale, 1 * scale), rowB - vec2(4 * scale, 1 * scale),
        rgbm(colors.valueStatic.r, colors.valueStatic.g, colors.valueStatic.b, 0.35), 5 * scale)
    end

    local posBoxA = rowA + vec2(posLeft, 4 * scale)
    local posBoxB = posBoxA + vec2(posBoxWidth, rowHeight - 8 * scale)
    ui.drawRectFilled(posBoxA, posBoxB,
      rgbm(colors.backgroundAlt.r, colors.backgroundAlt.g, colors.backgroundAlt.b, 0.95), 4 * scale)
    ui.drawRect(posBoxA, posBoxB, rgbm(colors.border.r, colors.border.g, colors.border.b, 0.22), 4 * scale)
    ui.dwriteDrawTextClipped(string.format('%02d', entry.position), font.size * scale,
      posBoxA, posBoxB, ui.Alignment.Center, ui.Alignment.Center, false, textColor)
    if DEBUG_LEADERBOARD_BOUNDS then
      ui.drawRect(posBoxA, posBoxB, rgbm(1, 0, 0, 1), 0, nil, 1)
    end

    local changeText = ''
    local changeColor = colors.valueStatic
    if entry.positionDelta > 0 then
      changeText = string.format('+%d', entry.positionDelta)
      changeColor = colors.valuePositive
    elseif entry.positionDelta < 0 then
      changeText = string.format('-%d', math.abs(entry.positionDelta))
      changeColor = colors.valueNegative
    end

    if showPositionChange then
      local changeA = rowA + vec2(changeLeft, 0)
      local changeB = changeA + vec2(changeWidth, rowHeight)
      ui.dwriteDrawTextClipped(changeText, font.size * scale,
        changeA, changeB,
        ui.Alignment.Center, ui.Alignment.Center, false, changeColor)
      if DEBUG_LEADERBOARD_BOUNDS then
        ui.drawRect(changeA, changeB, rgbm(1, 0, 0, 1), 0, nil, 1)
      end
    end

    if showNationFlag then
      local flagPath = getNationFlagPath(entry.nationCode)
      local imageSize = vec2(18 * scale, 18 * scale)
      local flagColumnLeft = rowA.x + flagLeft
      local imageA = vec2(flagColumnLeft + 2 * scale, rowA.y + (rowHeight - imageSize.y) * 0.5)
      local imageB = imageA + imageSize
      if flagPath then
        ui.drawImage(flagPath, imageA, imageB)
      end
      if DEBUG_LEADERBOARD_BOUNDS then
        ui.drawRect(vec2(flagColumnLeft, rowA.y), vec2(flagColumnLeft + flagWidth, rowA.y + rowHeight), rgbm(1, 0, 0, 1), 0, nil, 1)
      end
    end

    if showCarLogo then
      local badgePath = getBadgePath(entry.carId)
      local imageSize = vec2(18 * scale, 18 * scale)
      local logoColumnLeft = rowA.x + logoLeft
      local imageA = vec2(logoColumnLeft + 2 * scale, rowA.y + (rowHeight - imageSize.y) * 0.5)
      local imageB = imageA + imageSize
      if badgePath then
        ui.drawImage(badgePath, imageA, imageB)
      end
      if DEBUG_LEADERBOARD_BOUNDS then
        ui.drawRect(vec2(logoColumnLeft, rowA.y), vec2(logoColumnLeft + logoWidth, rowA.y + rowHeight), rgbm(1, 0, 0, 1), 0, nil, 1)
      end
    end

    local nameLeft = rowA.x + nameLeftOffset
    local gapLeft = nameLeft + nameWidth + 6 * scale
    local compoundLeft = gapLeft + gapWidth + compoundGap
    local compoundRight = compoundLeft + compoundWidth
    local lapLeft = compoundRight + (showCompoundColumn and compoundGap or 0)
    local lapRight = lapLeft + lapWidth

    local nameA = vec2(nameLeft, rowA.y + 2 * scale)
    local nameB = vec2(nameLeft + nameWidth, rowA.y + rowHeight - 2 * scale)
    ui.dwriteDrawTextClipped(entry.name, font.size * scale,
      nameA, nameB,
      ui.Alignment.Start, ui.Alignment.Center, false, textColor)
    if DEBUG_LEADERBOARD_BOUNDS then
      ui.drawRect(nameA, nameB, rgbm(1, 0, 0, 1), 0, nil, 1)
    end

    if showCompoundColumn then
      local compoundA = vec2(compoundLeft, rowA.y)
      local compoundB = vec2(compoundRight, rowA.y + rowHeight)
      ui.dwriteDrawTextClipped(entry.compound or '--', font.size * scale,
        compoundA, compoundB,
        ui.Alignment.Center, ui.Alignment.Center, false, colors.valueStatic)
      if DEBUG_LEADERBOARD_BOUNDS then
        ui.drawRect(compoundA, compoundB, rgbm(1, 0, 0, 1), 0, nil, 1)
      end
    end

    local gapSeconds = 0
    if gapReference and not entry.isFocused and entry.index ~= gapReference.index then
      gapSeconds = getRelativeGapSeconds(self.trackLength, gapReference, entry)
    end
    local gapText, gapColor = formatGap(entry, gapReference or focused, gapSeconds, colors)
    local rightRowFont = font.size * scale
    local gapA = vec2(gapLeft, rowA.y)
    local gapB = vec2(gapLeft + gapWidth, rowA.y + rowHeight)
    ui.dwriteDrawTextClipped(gapText, rightRowFont,
      gapA, gapB,
      ui.Alignment.End, ui.Alignment.Center, false, gapColor)
    if DEBUG_LEADERBOARD_BOUNDS then
      ui.drawRect(gapA, gapB, rgbm(1, 0, 0, 1), 0, nil, 1)
    end

    if showLap then
      local lapA = vec2(lapLeft, rowA.y)
      local lapB = vec2(lapRight, rowA.y + rowHeight)
      ui.dwriteDrawTextClipped(string.format('L%d', entry.lapCount), rightRowFont,
        lapA, lapB,
        ui.Alignment.Center, ui.Alignment.Center, false, colors.valueNeutral)
      if DEBUG_LEADERBOARD_BOUNDS then
        ui.drawRect(lapA, lapB, rgbm(1, 0, 0, 1), 0, nil, 1)
      end
    end

    y = y + rowHeight
  end

  ui.dummy(panelSize)
  ui.popStyleVar()
  ui.popDWriteFont()
end

return LeaderboardWidget
