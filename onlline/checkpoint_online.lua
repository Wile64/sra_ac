-- Checkpoint online script prototype
-- Based on CSP online-script pattern:
-- Author: Wile64
-- Copyright (c) 2026 Wile64. All rights reserved.

local Config = {
  -- Master switch for the whole mode.
  enabled = true,

  -- Radius of each checkpoint circle in meters.
  radius = 2,

  -- Minimum gap between generated checkpoints along track progress (0..1 range).
  -- Higher values spread checkpoints further apart.
  minSpacing = 0.08,

  -- Safety margin from track edges in meters.
  -- Increase it to keep checkpoints farther from kerbs/grass/walls.
  edgeMargin = 0.5,

  -- Draw a soft pulsing halo around active checkpoints.
  showHalo = true,

  -- Send lap score summary to chat when a lap ends.
  sendScoreToChat = true,

  -- Penalty mode:
  -- 'none'       = no driving penalty, score only
  -- 'ballast'    = missed checkpoints add ballast in kg
  -- 'restrictor' = missed checkpoints add engine restrictor in %
  penaltyMode = 'restrictor', -- 'none', 'ballast' or 'restrictor'

  -- If true, penalty mode rotates on each new session:
  -- none -> ballast -> restrictor -> none
  rotatePenaltyModeEachSession = false,

  -- Ballast added per missed checkpoint (used only with penaltyMode = 'ballast').
  missedCheckpointBallastKg = 5,

  -- Ballast removed for a fully clean lap (used only with penaltyMode = 'ballast').
  cleanLapBallastReductionKg = 5,

  -- Restrictor added per missed checkpoint in percent
  -- (used only with penaltyMode = 'restrictor').
  missedCheckpointRestrictorPercent = 10,

  -- Restrictor removed for a fully clean lap in percent
  -- (used only with penaltyMode = 'restrictor').
  cleanLapRestrictorReductionPercent = 10,
}

local paint = ac.TrackPaint()
local checkpoints = {}
local passedCount = 0
local totalScore = 0
local lastGeneratedLap = nil
local lastLapBonusAwarded = nil
local lastBonusEarned = 0
local lastChatLapSent = nil
local lastPublishedLap = nil
local showRulesDialog = false
local hideRulesForSession = false
local totalBallastKg = 0
local totalRestrictorPercent = 0
local modeRotationOrder = { 'none', 'ballast', 'restrictor' }
local sessionStartedOnce = false
-- Local table rebuilt from online messages. Each client keeps its own copy of
-- the scoreboard, filled with states received from every player.
local leaderboard = {}

-- Online event used to exchange scoreboard snapshots between clients.
-- Important: all clients must declare exactly the same layout.
-- We only send a tiny state payload at end of lap, which fits well within
-- AC/CSP online message limits.
local scoreSyncEvent = ac.OnlineEvent({
  -- Unique key to avoid collisions with other scripts using OnlineEvent().
  key = ac.StructItem.key('checkpoint_v1'),
  sessionID = ac.StructItem.int16(),
  lap = ac.StructItem.int16(),
  totalScore = ac.StructItem.int16(),
  lastLapScore = ac.StructItem.int16(),
}, function(sender, data)
  if not sender then
    return
  end

  -- Each received message updates one entry of our local scoreboard copy.
  -- `sender` tells us who sent the state, so we can attach a visible name and
  -- car index to the raw numeric data.
  leaderboard[data.sessionID] = {
    sessionID = data.sessionID,
    carIndex = sender.index,
    name = sender:driverName(),
    lap = data.lap,
    totalScore = data.totalScore,
    lastLapScore = data.lastLapScore,
  }
end, nil, nil, { processPostponed = true })

local function getHUDScale()
  local screen = vec2(ac.getSim().windowWidth, ac.getSim().windowHeight)
  local rawScale = screen.y / 1080
  local clampedScale = math.max(0.80, math.min(1.00, rawScale))
  local hudScale = clampedScale * 0.90
  return screen, hudScale
end

local COLOR_PENDING = rgbm(1.00, 0.55, 0.08, 0.98)
local COLOR_PENDING_FILL = rgbm(1.00, 0.55, 0.08, 0.14)
local COLOR_PASSED = rgbm(0.20, 1.00, 0.35, 0.98)
local COLOR_PASSED_FILL = rgbm(0.20, 1.00, 0.35, 0.18)
local COLOR_HALO = rgbm(1.00, 0.95, 0.80, 0.22)
local HUD_BG = rgbm(0.06, 0.07, 0.09, 0.84)
local HUD_BORDER = rgbm(1.00, 1.00, 1.00, 0.08)
local HUD_TITLE = rgbm(0.88, 0.90, 0.93, 1.00)
local HUD_SCORE = rgbm(0.96, 0.97, 0.98, 1.00)
local HUD_MUTED = rgbm(0.63, 0.67, 0.71, 1.00)
local HUD_ACCENT = rgbm(0.90, 0.72, 0.32, 1.00)
local HUD_GOOD = rgbm(0.42, 0.90, 0.58, 1.00)
local HUD_INFO = rgbm(0.74, 0.80, 0.86, 1.00)

-- Store our own current state in the same local scoreboard table used for
-- remote players. That way the UI works the same for everyone.
local function updateLocalLeaderboard(lapScore)
  local sim = ac.getSim()
  if sim.focusedCar ~= 0 then
    return
  end
  local car = ac.getCar(0)

  leaderboard[car.sessionID] = {
    sessionID = car.sessionID,
    carIndex = car.index,
    name = car:driverName(),
    lap = car.lapCount,
    totalScore = totalScore,
    lastLapScore = lapScore or 0,
  }
end

-- Publish our current score snapshot to other clients.
-- `repeatForNewConnections = true` asks CSP to replay latest state for players
-- who join later, which is useful for a live scoreboard.
local function publishLeaderboardScore(lapScore)
  local sim = ac.getSim()
  if sim.focusedCar ~= 0 or not (sim.isOnlineRace and sim.raceSessionType == ac.SessionType.Race) then
    return
  end
  local car = ac.getCar(0)

  updateLocalLeaderboard(lapScore)
  scoreSyncEvent({
    sessionID = car.sessionID,
    lap = car.lapCount,
    totalScore = totalScore,
    lastLapScore = lapScore or 0,
  }, true)
end

-- Turn the dictionary-style table into a sorted array for HUD rendering.
-- Primary sort: total score, secondary sort: lap, final fallback: name.
local function sortedLeaderboardEntries()
  local entries = {}
  for _, entry in pairs(leaderboard) do
    entries[#entries + 1] = entry
  end

  table.sort(entries, function(a, b)
    if a.totalScore ~= b.totalScore then
      return a.totalScore > b.totalScore
    end
    if a.lap ~= b.lap then
      return a.lap > b.lap
    end
    return a.name < b.name
  end)

  return entries
end

local function rulesText()
  local penaltyLine
  local rewardLine
  if Config.penaltyMode == 'none' then
    penaltyLine = '- No driving penalty is applied.'
    rewardLine = '- Clean laps keep the same car performance.'
  elseif Config.penaltyMode == 'restrictor' then
    penaltyLine = string.format('- Each missed checkpoint adds +%d%% restrictor on the next lap.',
      Config.missedCheckpointRestrictorPercent)
    rewardLine = string.format('- A clean lap removes %d%% restrictor on the next lap.',
      Config.cleanLapRestrictorReductionPercent)
  else
    penaltyLine = string.format('- Each missed checkpoint adds +%d kg ballast on the next lap.',
      Config.missedCheckpointBallastKg)
    rewardLine = string.format('- A clean lap removes %d kg ballast on the next lap.', Config.cleanLapBallastReductionKg)
  end
  return table.concat({
    'Welcome to Checkpoint Mode.',
    '',
    '- Drive through random checkpoints each lap.',
    '- Each checkpoint gives 1 point.',
    '- A full lap gives a +2 bonus.',
    penaltyLine,
    rewardLine,
    '- Lap score is sent to chat automatically.',
    '- Race session only.',
  }, '\n')
end

local function advancePenaltyMode()
  local currentIndex = 1
  for i = 1, #modeRotationOrder do
    if modeRotationOrder[i] == Config.penaltyMode then
      currentIndex = i
      break
    end
  end

  currentIndex = currentIndex + 1
  if currentIndex > #modeRotationOrder then
    currentIndex = 1
  end
  Config.penaltyMode = modeRotationOrder[currentIndex]
end

local function penaltyValueLabel()
  if Config.penaltyMode == 'none' then
    return 'Penalty disabled'
  end
  if Config.penaltyMode == 'restrictor' then
    return string.format('Restrictor %d%%', totalRestrictorPercent)
  end
  return string.format('Ballast %d kg', totalBallastKg)
end

local function playerCar()
  if ac.getSim().focusedCar ~= 0 then
    return nil
  end
  return ac.getCar(0)
end

local function isActiveRace()
  local sim = ac.getSim()
  return sim.isOnlineRace and sim.raceSessionType == ac.SessionType.Race
end

local function wrap01(v)
  if v < 0 then
    return v + 1
  end
  if v >= 1 then
    return v - 1
  end
  return v
end

local function progressDistance(a, b)
  local d = math.abs(a - b)
  return math.min(d, 1 - d)
end

local function resetState()
  checkpoints = {}
  passedCount = 0
  totalScore = 0
  lastGeneratedLap = nil
  lastLapBonusAwarded = nil
  lastBonusEarned = 0
  lastChatLapSent = nil
  lastPublishedLap = nil
  hideRulesForSession = false
  totalBallastKg = 0
  totalRestrictorPercent = 0
  leaderboard = {}
  physics.setCarBallast(0, 0)
  physics.setCarRestrictor(0, 0)
  paint:reset()
end

local function sendLapScoreToChat(lapIndex, lapScore, lapBonus)
  if not Config.sendScoreToChat or lapIndex == nil or lapIndex < 0 then
    return
  end
  if lastChatLapSent == lapIndex then
    return
  end

  local msg = string.format('[Checkpoint] Lap %d: %d pts', lapIndex + 1, lapScore)
  if lapBonus > 0 then
    msg = msg .. string.format(' (bonus +%d)', lapBonus)
  end
  msg = msg .. string.format(' | total %d', totalScore)

  if ac.sendChatMessage(msg) then
    lastChatLapSent = lapIndex
  end
end

local function suggestedCheckpointCount()
  local trackLengthM = ac.getSim().trackLengthM or 0
  if trackLengthM <= 0 then
    return 6
  end

  local count = math.floor(trackLengthM / 650 + 0.5)
  return math.min(20, math.max(6, count))
end

local function makeCheckpoint(progress)
  local prevPos = ac.trackProgressToWorldCoordinate(wrap01(progress - 0.002), true)
  local nextPos = ac.trackProgressToWorldCoordinate(wrap01(progress + 0.002), true)
  local centerPos = ac.trackProgressToWorldCoordinate(progress, true)
  local tangent = nextPos - prevPos
  tangent.y = 0

  local tangentLen = math.sqrt(tangent.x * tangent.x + tangent.z * tangent.z)
  if tangentLen < 0.001 then
    tangent = vec3(0, 0, 1)
  else
    tangent = tangent / tangentLen
  end

  local right = vec3(-tangent.z, 0, tangent.x)
  local sides = ac.getTrackAISplineSides(progress)
  local leftWidth = sides.x
  local rightWidth = sides.y
  local maxLeft = math.max(0, leftWidth - Config.edgeMargin - Config.radius)
  local maxRight = math.max(0, rightWidth - Config.edgeMargin - Config.radius)
  local offset = 0

  if maxLeft > 0 or maxRight > 0 then
    offset = (math.random() * (maxLeft + maxRight)) - maxLeft
  end

  return {
    progress = progress,
    offset = offset,
    position = centerPos + right * offset,
    passed = false,
  }
end

local function regenerateForLap()
  checkpoints = {}
  passedCount = 0
  lastBonusEarned = 0

  local targetCount = suggestedCheckpointCount()
  local attempts = 0
  while #checkpoints < targetCount and attempts < 800 do
    attempts = attempts + 1
    local candidate = math.random()
    local valid = true

    for i = 1, #checkpoints do
      if progressDistance(candidate, checkpoints[i].progress) < Config.minSpacing then
        valid = false
        break
      end
    end

    if valid then
      checkpoints[#checkpoints + 1] = makeCheckpoint(candidate)
    end
  end

  table.sort(checkpoints, function(a, b)
    return a.progress < b.progress
  end)
end

local function refreshCheckpointPositions()
  for i = 1, #checkpoints do
    local cp = checkpoints[i]
    local prevPos = ac.trackProgressToWorldCoordinate(wrap01(cp.progress - 0.002), true)
    local nextPos = ac.trackProgressToWorldCoordinate(wrap01(cp.progress + 0.002), true)
    local centerPos = ac.trackProgressToWorldCoordinate(cp.progress, true)
    local tangent = nextPos - prevPos
    tangent.y = 0

    local tangentLen = math.sqrt(tangent.x * tangent.x + tangent.z * tangent.z)
    if tangentLen < 0.001 then
      tangent = vec3(0, 0, 1)
    else
      tangent = tangent / tangentLen
    end

    local right = vec3(-tangent.z, 0, tangent.x)
    cp.position = centerPos + right * cp.offset
  end
end

local function ensureLapState(car)
  if lastGeneratedLap ~= nil and car.lapCount ~= lastGeneratedLap then
    local lapBonus = 0
    local missedCount = math.max(0, #checkpoints - passedCount)
    local cleanLap = passedCount == #checkpoints and #checkpoints > 0
    local lapScore = passedCount
    if passedCount == #checkpoints and #checkpoints > 0 and lastLapBonusAwarded ~= lastGeneratedLap then
      totalScore = totalScore + 2
      lastLapBonusAwarded = lastGeneratedLap
      lastBonusEarned = 2
      lapBonus = 2
      ui.toast(ui.Icons.Star, string.format('Lap completed: bonus +2 | total %d', totalScore))
    end

    if Config.penaltyMode == 'none' then
      -- No driving penalty for missed checkpoints.
    elseif Config.penaltyMode == 'restrictor' then
      if missedCount > 0 then
        local restrictorToAdd = missedCount * Config.missedCheckpointRestrictorPercent
        totalRestrictorPercent = totalRestrictorPercent + restrictorToAdd
        physics.setCarRestrictor(0, totalRestrictorPercent)
        ui.toast(ui.Icons.Warning,
          string.format('+%d%% restrictor | total %d%%', restrictorToAdd, totalRestrictorPercent))
      elseif cleanLap and totalRestrictorPercent > 0 then
        totalRestrictorPercent = math.max(0, totalRestrictorPercent - Config.cleanLapRestrictorReductionPercent)
        physics.setCarRestrictor(0, totalRestrictorPercent)
        ui.toast(ui.Icons.Warning,
          string.format('Clean lap: -%d%% restrictor | total %d%%', Config.cleanLapRestrictorReductionPercent,
            totalRestrictorPercent))
      end
    else
      if missedCount > 0 then
        local ballastToAdd = missedCount * Config.missedCheckpointBallastKg
        totalBallastKg = totalBallastKg + ballastToAdd
        physics.setCarBallast(0, totalBallastKg)
        ui.toast(ui.Icons.Ballast, string.format('+%d kg ballast | total %d kg', ballastToAdd, totalBallastKg))
      elseif cleanLap and totalBallastKg > 0 then
        totalBallastKg = math.max(0, totalBallastKg - Config.cleanLapBallastReductionKg)
        physics.setCarBallast(0, totalBallastKg)
        ui.toast(ui.Icons.Ballast,
          string.format('Clean lap: -%d kg ballast | total %d kg', Config.cleanLapBallastReductionKg, totalBallastKg))
      end
    end

    lapScore = lapScore + lapBonus
    sendLapScoreToChat(lastGeneratedLap, lapScore, lapBonus)
    -- Send one compact network update when a lap ends. This is the right
    -- frequency for OnlineEvent(): informative, but not spammy.
    publishLeaderboardScore(lapScore)
    lastPublishedLap = lastGeneratedLap
  end

  if lastGeneratedLap == car.lapCount and #checkpoints > 0 then
    return
  end

  regenerateForLap()
  lastGeneratedLap = car.lapCount
  if lastPublishedLap == nil then
    -- Publish an initial zero-state once so the player appears in the
    -- scoreboard before completing the first lap.
    publishLeaderboardScore(0)
    lastPublishedLap = car.lapCount
  end
end

local function detectPassages(car)
  for i = 1, #checkpoints do
    local cp = checkpoints[i]
    if not cp.passed and car.position:distance(cp.position) <= Config.radius then
      cp.passed = true
      passedCount = passedCount + 1
      totalScore = totalScore + 1
      ui.toast(ui.Icons.Confirm, string.format('Checkpoint %d/%d | total %d', passedCount, #checkpoints, totalScore))
    end
  end
end

local function drawTrackCheckpoints(simTime)
  paint:reset()
  paint:age(0)
  paint:padding(0.1)

  for i = 1, #checkpoints do
    local cp = checkpoints[i]
    local baseColor = cp.passed and COLOR_PASSED or COLOR_PENDING
    local fillColor = cp.passed and COLOR_PASSED_FILL or COLOR_PENDING_FILL

    paint:circle(cp.position, Config.radius, false, fillColor, 40)
    paint:circle(cp.position, Config.radius, 0.35, baseColor, 56)

    if Config.showHalo and not cp.passed then
      local pulse = 0.5 + 0.5 * math.sin(simTime * 2.5 + i)
      local halo = rgbm(COLOR_HALO.r, COLOR_HALO.g, COLOR_HALO.b, COLOR_HALO.mult + pulse * 0.10)
      paint:circle(cp.position + vec3(0, 0.01, 0), Config.radius * (1.05 + 0.2 * pulse), 0.10, halo, 56)
    end
  end
end

local function drawScoreHUD()
  local screen, scale = getHUDScale()
  local titleSize = 22 * scale
  local bigSize = 42 * scale
  local textSize = 20 * scale
  local smallSize = 15 * scale
  local winSize = vec2(250 * scale, 170 * scale)
  local pos = vec2(24 * scale, 24 * scale)
  local complete = #checkpoints > 0 and passedCount == #checkpoints
  local progressColor = complete and HUD_GOOD or HUD_ACCENT
  local scoreColor = HUD_SCORE
  local muted = HUD_MUTED
  local lapIndex = playerCar() and playerCar().lapCount or 0

  ui.beginTransparentWindow('checkpointScoreHUD', pos, winSize)
  ui.drawRectFilled(vec2(), winSize, HUD_BG, 8 * scale)
  ui.drawRect(vec2(), winSize, HUD_BORDER, 8 * scale, 1.25 * scale)
  ui.dwriteDrawTextClipped('CHECKPOINT', titleSize, vec2(12 * scale, 8 * scale), vec2(winSize.x - 12 * scale, 28 * scale),
    ui.Alignment.Start,
    ui.Alignment.Center, false, HUD_TITLE)
  ui.dwriteDrawTextClipped(string.format('Lap %d', lapIndex), smallSize, vec2(12 * scale, 10 * scale),
    vec2(winSize.x - 12 * scale, 28 * scale), ui.Alignment.End, ui.Alignment.Center, false, muted)
  ui.drawLine(vec2(12 * scale, 34 * scale), vec2(winSize.x - 12 * scale, 34 * scale), HUD_BORDER, 2)

  ui.dwriteDrawTextClipped(tostring(totalScore), bigSize, vec2(12 * scale, 38 * scale), vec2(112 * scale, 88 * scale),
    ui.Alignment.Start, ui.Alignment.Center, false, scoreColor)
  ui.dwriteDrawTextClipped('score', smallSize, vec2(12 * scale, 84 * scale), vec2(112 * scale, 102 * scale),
    ui.Alignment.Start, ui.Alignment.Center, false, muted)

  ui.dwriteDrawTextClipped(string.format('%d / %d', passedCount, #checkpoints), textSize, vec2(122 * scale, 48 * scale),
    vec2(winSize.x - 12 * scale, 76 * scale), ui.Alignment.End, ui.Alignment.Center, false, progressColor)
  ui.dwriteDrawTextClipped('checkpoints', smallSize, vec2(122 * scale, 76 * scale),
    vec2(winSize.x - 12 * scale, 94 * scale),
    ui.Alignment.End, ui.Alignment.Center, false, muted)

  local bonusText = complete and 'Bonus +2 ready' or 'Bonus +2 for full lap'
  local bonusColor = complete and HUD_GOOD or HUD_ACCENT
  ui.drawLine(vec2(12 * scale, 108 * scale), vec2(winSize.x - 12 * scale, 108 * scale), HUD_BORDER, 2)
  ui.dwriteDrawTextClipped(bonusText, smallSize, vec2(12 * scale, 114 * scale), vec2(winSize.x - 12 * scale, 138 * scale),
    ui.Alignment.Start, ui.Alignment.Center, false, bonusColor)

  ui.dwriteDrawTextClipped(penaltyValueLabel(), smallSize, vec2(12 * scale, 136 * scale),
    vec2(winSize.x - 12 * scale, 154 * scale), ui.Alignment.Start, ui.Alignment.Center, false, HUD_INFO)

  if lastBonusEarned > 0 then
    ui.dwriteDrawTextClipped(string.format('Last bonus +%d', lastBonusEarned), smallSize, vec2(12 * scale, 152 * scale),
      vec2(winSize.x - 12 * scale, 166 * scale), ui.Alignment.Start, ui.Alignment.Center, false, HUD_INFO)
  end
  ui.endTransparentWindow()
end

-- Small secondary HUD showing the shared scoreboard rebuilt from OnlineEvent()
-- messages. It is intentionally compact to validate the networking concept
-- before polishing the final presentation.
local function drawLeaderboardHUD()
  local _, scale = getHUDScale()
  local entries = sortedLeaderboardEntries()
  if #entries == 0 then
    return
  end

  local visibleEntries = math.min(#entries, 8)
  local rowHeight = 20 * scale
  local winSize = vec2(250 * scale, (44 + visibleEntries * 22) * scale)
  local pos = vec2(24 * scale, 204 * scale)

  ui.beginTransparentWindow('checkpointLeaderboardHUD', pos, winSize)
  ui.drawRectFilled(vec2(), winSize, HUD_BG, 8 * scale)
  ui.drawRect(vec2(), winSize, HUD_BORDER, 8 * scale, 1.25 * scale)
  ui.dwriteDrawTextClipped('LIVE SCOREBOARD', 18 * scale, vec2(12 * scale, 8 * scale),
    vec2(winSize.x - 12 * scale, 28 * scale), ui.Alignment.Start, ui.Alignment.Center, false, HUD_TITLE)
  ui.drawLine(vec2(12 * scale, 32 * scale), vec2(winSize.x - 12 * scale, 32 * scale), HUD_BORDER, 2)

  for i = 1, visibleEntries do
    local entry = entries[i]
    local y = (36 + (i - 1) * 22) * scale
    local rowColor = entry.carIndex == 0 and HUD_GOOD or HUD_SCORE
    local name = string.format('%d. %s', i, entry.name or 'Unknown')
    local scoreText = string.format('%d pts', entry.totalScore or 0)
    ui.dwriteDrawTextClipped(name, 16 * scale, vec2(12 * scale, y), vec2(176 * scale, y + rowHeight),
      ui.Alignment.Start, ui.Alignment.Center, false, rowColor)
    ui.dwriteDrawTextClipped(scoreText, 16 * scale, vec2(178 * scale, y), vec2(winSize.x - 12 * scale, y + rowHeight),
      ui.Alignment.End, ui.Alignment.Center, false, HUD_ACCENT)
  end
  ui.endTransparentWindow()
end

local function drawRulesDialog()
  local _, scale = getHUDScale()
  local uiState = ac.getUI()
  local uiScreen = vec2(ac.getSim().windowWidth, ac.getSim().windowHeight) / math.max(uiState.uiScale, 0.001)
  local winSize = vec2(620 * scale, 380 * scale)
  local pos = (uiScreen - winSize) * 0.5

  ui.beginTransparentWindow('checkpointRulesDialog', pos, winSize, false, true)
  ui.drawRectFilled(vec2(), winSize, HUD_BG, 10 * scale)
  ui.drawRect(vec2(), winSize, HUD_BORDER, 10 * scale, 1.5 * scale)
  ui.drawRectFilled(vec2(), vec2(winSize.x, 8 * scale), HUD_ACCENT, 10 * scale)
  ui.dwriteDrawTextClipped('CHECKPOINT RULES', 24 * scale, vec2(18 * scale, 14 * scale),
    vec2(winSize.x - 18 * scale, 42 * scale), ui.Alignment.Start,
    ui.Alignment.Center, false, HUD_TITLE)
  ui.drawLine(vec2(18 * scale, 50 * scale), vec2(winSize.x - 18 * scale, 50 * scale), HUD_ACCENT, 2)
  ui.dwriteDrawTextClipped(rulesText(), 18 * scale, vec2(18 * scale, 66 * scale),
    vec2(winSize.x - 18 * scale, 270 * scale), ui.Alignment.Start,
    ui.Alignment.Start, false, HUD_SCORE)

  ui.setCursor(vec2(18 * scale, winSize.y - 88 * scale))
  if ui.checkbox("Don't show again this session", hideRulesForSession) then
    hideRulesForSession = not hideRulesForSession
  end

  local buttonSize = vec2(110 * scale, 34 * scale)
  local buttonPos = vec2((winSize.x - buttonSize.x) * 0.5, winSize.y - buttonSize.y - 20 * scale)
  ui.setCursor(buttonPos)
  if ui.button('OK', buttonSize) then
    showRulesDialog = false
  end
  ui.endTransparentWindow()
end

function script.update(dt)
  local car = playerCar()
  if not Config.enabled or car == nil or not isActiveRace() then
    paint:reset()
    return
  end

  ensureLapState(car)
  refreshCheckpointPositions()

  detectPassages(car)
  drawTrackCheckpoints(ac.getSim().gameTime)
end

function script.drawUI()
  if not Config.enabled or not isActiveRace() then
    return
  end

  drawScoreHUD()
  drawLeaderboardHUD()
  if showRulesDialog then
    drawRulesDialog()
  end
end

if ac.onSessionStart then
  ac.onSessionStart(function()
    if Config.rotatePenaltyModeEachSession then
      if sessionStartedOnce then
        advancePenaltyMode()
      else
        sessionStartedOnce = true
      end
    end
    resetState()
    ui.toast(ui.Icons.Info, string.format('Penalty mode: %s', Config.penaltyMode))
  end)
end

ac.onOnlineWelcome(function(message, config) --Reads the script config from the extra options
  resetState()
  showRulesDialog = not hideRulesForSession
  Config.enabled = config:get("CHECKPOINT", "ENEBLED", 1)
  Config.radius = config:get("CHECKPOINT", "RADIUS", 2)
  Config.minSpacing = config:get("CHECKPOINT", "MINSPACING", 0.08)
  Config.edgeMargin = config:get("CHECKPOINT", "EDGEMARGIN", 0.5)
  Config.showHalo = config:get("CHECKPOINT", "SHOWHALO", 1)
  Config.sendScoreToChat = config:get("CHECKPOINT", "SENDSCORETOCHAT", 1)
  Config.penaltyMode = config:get("CHECKPOINT", "PENALITYMODE", "none")
  Config.rotatePenaltyModeEachSession = config:get("CHECKPOINT", "ROTATEPENALTYMODEEACHSESSION", 0)
  Config.missedCheckpointBallastKg = config:get("CHECKPOINT", "MISSEDCHECKPOINTBALLASTKG", 5)
  Config.cleanLapBallastReductionKg = config:get("CHECKPOINT", "CLEANLAPBALLASTREDUCTIONKG", 5)
  Config.missedCheckpointRestrictorPercent = config:get("CHECKPOINT", "MISSEDCHECKPOINTRESTRICTORPERCENT", 10)
  Config.cleanLapRestrictorReductionPercent = config:get("CHECKPOINT", "CLEANLAPRESTRICTORREDUCTIONPERCENT", 10)
end)
