-- Checkpoint online script prototype
-- Based on CSP online-script pattern:
-- - script.update(dt)
-- - script.drawUI()
-- - ac.onSessionStart()
-- - ac.onOnlineWelcome()

local Config = {
  enabled = true,
  radius = 2,
  minSpacing = 0.08,
  edgeMargin = 1.5,
  showHalo = true,
  sendScoreToChat = true,
}

local paint = ac.TrackPaint()
local checkpoints = {}
local passedCount = 0
local totalScore = 0
local lastPassTime = -math.huge
local lastGeneratedLap = nil
local lastLapBonusAwarded = nil
local lastBonusEarned = 0
local lastChatLapSent = nil

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
  lastPassTime = -math.huge
  lastGeneratedLap = nil
  lastLapBonusAwarded = nil
  lastBonusEarned = 0
  lastChatLapSent = nil
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
  lastPassTime = -math.huge
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
    if passedCount == #checkpoints and #checkpoints > 0 and lastLapBonusAwarded ~= lastGeneratedLap then
      totalScore = totalScore + 2
      lastLapBonusAwarded = lastGeneratedLap
      lastBonusEarned = 2
      lapBonus = 2
      ui.toast(ui.Icons.Star, string.format('Lap completed: bonus +2 | total %d', totalScore))
    end

    sendLapScoreToChat(lastGeneratedLap, passedCount + lapBonus, lapBonus)
  end

  if lastGeneratedLap == car.lapCount and #checkpoints > 0 then
    return
  end

  regenerateForLap()
  lastGeneratedLap = car.lapCount
end

local function detectPassages(car, simTime)
  for i = 1, #checkpoints do
    local cp = checkpoints[i]
    if not cp.passed and car.position:distance(cp.position) <= Config.radius then
      cp.passed = true
      passedCount = passedCount + 1
      totalScore = totalScore + 1
      lastPassTime = simTime
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
  local winSize = vec2(250 * scale, 150 * scale)
  local pos = vec2(screen.x - winSize.x - 24 * scale, 24 * scale)
  local complete = #checkpoints > 0 and passedCount == #checkpoints
  local progressColor = complete and HUD_GOOD or HUD_ACCENT
  local scoreColor = HUD_SCORE
  local muted = HUD_MUTED
  local lapIndex = playerCar() and playerCar().lapCount or 0

  ui.beginTransparentWindow('checkpointScoreHUD', pos, winSize)
  ui.drawRectFilled(vec2(), winSize, HUD_BG, 8 * scale)
  ui.drawRect(vec2(), winSize, HUD_BORDER, 8 * scale, 1.25 * scale)
  ui.dwriteDrawTextClipped('CHECKPOINT', titleSize, vec2(12 * scale, 8 * scale), vec2(winSize.x - 12 * scale, 28 * scale), ui.Alignment.Start,
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
  ui.dwriteDrawTextClipped('checkpoints', smallSize, vec2(122 * scale, 76 * scale), vec2(winSize.x - 12 * scale, 94 * scale),
    ui.Alignment.End, ui.Alignment.Center, false, muted)

  local bonusText = complete and 'Bonus +2 ready' or 'Bonus +2 for full lap'
  local bonusColor = complete and HUD_GOOD or HUD_ACCENT
  ui.drawLine(vec2(12 * scale, 108 * scale), vec2(winSize.x - 12 * scale, 108 * scale), HUD_BORDER, 2)
  ui.dwriteDrawTextClipped(bonusText, smallSize, vec2(12 * scale, 114 * scale), vec2(winSize.x - 12 * scale, 138 * scale),
    ui.Alignment.Start, ui.Alignment.Center, false, bonusColor)

  if lastBonusEarned > 0 then
    ui.dwriteDrawTextClipped(string.format('Last bonus +%d', lastBonusEarned), smallSize, vec2(12 * scale, 128 * scale),
      vec2(winSize.x - 12 * scale, 144 * scale), ui.Alignment.Start, ui.Alignment.Center, false, HUD_INFO)
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

  local sim = ac.getSim()
  detectPassages(car, sim.gameTime)
  drawTrackCheckpoints(sim.gameTime)
end

function script.drawUI()
  if not Config.enabled or not isActiveRace() then
    return
  end

  drawScoreHUD()
end

if ac.onSessionStart then
  ac.onSessionStart(function()
    resetState()
  end)
end

if ac.onOnlineWelcome then
  ac.onOnlineWelcome(function()
    resetState()
  end)
end
