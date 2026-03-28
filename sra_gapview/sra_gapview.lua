-- ============================================================
-- SRA GapView
-- Created by Wile64 on May 2025
--
-- App features summary:
-- - Displays a live list of cars around the focused driver:
--   configurable count ahead and behind.
-- - Shows on-track time gap for each car versus the focused car.
-- - Gap sign convention:
--   +X.XXs = car ahead on track
--   -X.XXs = car behind on track
-- - Uses visual states for quick reading:
--   focused driver, leader, blue-flag context, pit status.
-- - Can highlight a lapped car physically ahead in blue.
-- - Optional columns:
--   car badge, nation flag, tyre compound,
--   lap count, best lap, last lap (with invalid lap coloring).
-- - Personal best flash:
--   if a new valid lap equals best lap, best/last are purple
--   for BEST_LAP_FLASH_TIME_MS.
-- - Includes a settings panel for layout scale and visible items.
-- - Persists user settings with `ac.storage`.
-- ============================================================
local AppConfig           = ac.storage {
  showAhead      = 3,
  showBehind     = 3,
  showBadge      = true,
  showNationFlag = true,
  showLapCount   = true,
  showTyre       = true,
  showBestLap    = true,
  showLastLap    = true,
  scale          = 10
}

local appVisible          = true
local updateInterval      = 0.1 -- Standings refresh interval (seconds)
local timeSinceLastUpdate = 0
local initialized         = false

local focusedIndex        = 0 -- index in standings for the focused driver
local nickNameCache       = {}
local standings           = {}
local driverLapSnapshot   = {}
local bestLapFlashUntil   = {}
local nationFlagPathCache = {}
local badgePathCache      = {}
local rootFolder          = ac.getFolder(ac.FolderID.Root)
local contentCarsFolder   = ac.getFolder(ac.FolderID.ContentCars)

local trackLength         = ac.getSim().trackLengthM -- track length in meters
local MAX_GAP_DISPLAY     = 99.99


local palette = {
  -- backgrounds
  bg_standard    = rgbm(0.0, 0.0, 0.0, 0.5),
  bg_selected    = rgbm(0.6, 0.6, 0.6, 0.5),
  bg_selectedPos = rgbm.colors.aqua,
  bg_leader      = rgbm.colors.lime,
  bg_blueflag    = rgbm(0.0, 0.5, 1.0, 0.5),
  bg_pit         = rgbm.colors.white,
  bg_invalidLap  = rgbm.colors.red,

  -- text colors
  fg_standard    = rgbm.colors.white,
  fg_selected    = rgbm.colors.aqua,
  fg_selectedPos = rgbm.colors.black,
  fg_leader      = rgbm.colors.lime,
  fg_leaderPos   = rgbm.colors.black,
  fg_blueflag    = rgbm.colors.white,
  fg_pit         = rgbm.colors.black,
  fg_invalidLap  = rgbm.colors.red,
  fg_aheadBlue   = rgbm(0, 0.6, 1, 1),
  fg_pbFlash     = rgbm(0.7, 0.0, 1.0, 1),
}

local State   = { Standard = 1, Leader = 2, BlueFlag = 3, Focused = 4, AheadBlue = 5, LeaderFocused = 6, LeaderBlue = 7 }

local themes  = {
  [State.Standard] = {
    position   = { bg = palette.bg_standard, fg = palette.fg_standard },
    text       = { bg = palette.bg_standard, fg = palette.fg_standard },
    pit        = { bg = palette.bg_pit, fg = palette.fg_pit },
    lapInvalid = { bg = palette.bg_standard, fg = palette.fg_invalidLap },
  },
  [State.Leader] = {
    position = { bg = palette.bg_leader, fg = palette.fg_leaderPos },
    text     = { bg = palette.bg_standard, fg = palette.fg_leader },
  },
  [State.BlueFlag] = {
    position   = { bg = palette.bg_blueflag, fg = palette.fg_blueflag },
    text       = { bg = palette.bg_blueflag, fg = palette.fg_blueflag },
    lapInvalid = { bg = palette.bg_blueflag, fg = palette.fg_invalidLap },
  },
  [State.AheadBlue] = {
    text = { bg = palette.bg_standard, fg = palette.fg_aheadBlue },
  },
  [State.Focused] = {
    position   = { bg = palette.bg_selectedPos, fg = palette.fg_selectedPos },
    text       = { bg = palette.bg_selected, fg = palette.fg_selected },
    lapInvalid = { bg = palette.bg_selected, fg = palette.fg_invalidLap },
  },
  [State.LeaderFocused] = {
    position   = { bg = palette.bg_leader, fg = palette.fg_leaderPos },
    text       = { bg = palette.bg_selected, fg = palette.fg_leader },
    lapInvalid = { bg = palette.bg_selected, fg = palette.fg_invalidLap },
  },
  [State.LeaderBlue] = {
    position   = { bg = palette.bg_leader, fg = palette.fg_leaderPos },
    text       = { bg = palette.bg_blueflag, fg = palette.fg_leader },
    lapInvalid = { bg = palette.bg_blueflag, fg = palette.fg_invalidLap },
  },
}

--- Returns text and background colors for a given visual state and component.
-- @param state integer one of `State.*`
-- @param comp string "position" | "text" | "pit" | "lapInvalid"
-- @return fg rgbm, bg rgbm
local function getColors(state, comp)
  local c = themes[state][comp] or themes[State.Standard][comp]
  return c.fg, c.bg
end

if ac.onSessionStart then
  ac.onSessionStart(function()
    initialized = false
  end)
end

--- Builds a short display name from a full driver name.
-- @param raw string full name, for example "[teamX] jean dupont"
-- @return string short name, for example "J.Dupont"
local function nickName(raw)
  -- Fast path: cached value.
  if nickNameCache[raw] then
    return nickNameCache[raw]
  end

  -- Strip team tags and split tokens.
  local onlyBrackets = raw:match("^%s*%[([^%]]+)%]%s*$")
  local s = onlyBrackets
      or raw:gsub("%b[]", ""):gsub("%b()", "")
  s = s:match("^%s*(.-)%s*$")

  local tokens = {}
  for tok in s:gmatch("[^%s._%-%(%)[%]{}|]+") do
    tokens[#tokens + 1] = tok
  end

  local formatted
  if #tokens <= 1 then
    local t = tokens[1] or ""
    formatted = (#t > 0)
        and t:sub(1, 1):upper() .. t:sub(2)
        or ""
  else
    local parts = {}
    for i = 1, #tokens - 1 do
      parts[#parts + 1] = tokens[i]:sub(1, 1):upper() .. "."
    end
    local last = tokens[#tokens]
    parts[#parts + 1] = last:sub(1, 1):upper() .. last:sub(2)
    formatted = table.concat(parts)
  end

  -- Cache computed nickname.
  nickNameCache[raw] = formatted
  return formatted
end

---------------- FONCTIONS GAP

local MIN_SPEED_FOR_GAP = 5         -- m/s, avoids unstable deltas at very low speeds
local BEST_LAP_FLASH_TIME_MS = 5000 -- ms

-- Gap signe et relation ahead/behind bases sur la distance reelle autour de la piste,
-- avec gestion propre du wrap start/finish.
local function getRelativeGapSeconds(focused, player)
  if not focused or not player or focused.idx == player.idx then
    return 0, false
  end
  if trackLength <= 0 then
    return 0, false
  end
  if player.isInPit then
    return 0, false
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
  return isAhead and gap or -gap, isAhead
end

--------------------------

function script.update(dt)
  if not appVisible then return end
  timeSinceLastUpdate = timeSinceLastUpdate + dt
  if timeSinceLastUpdate >= updateInterval or not initialized then
    timeSinceLastUpdate = 0
    initialized         = true
    local sim           = ac.getSim()
    local nCars         = sim.carsCount
    standings           = {}

    -- Collect a snapshot for connected and active cars.
    for i = 0, nCars - 1 do
      local car = ac.getCar(i)
      if car then
        if car.isConnected and not car.isRetired then
          local currentBestLap = car.bestLapTimeMs
          local currentLastLap = car.previousLapTimeMs
          local currentLastValid = car.isLastLapValid
          local currentLapCount = car.lapCount
          local prevLapCount = driverLapSnapshot[i]
          local flashUntil = bestLapFlashUntil[i] or 0

          local lastLapIsBest = math.abs(currentLastLap - currentBestLap) <= 1
          if prevLapCount
              and currentLapCount > prevLapCount
              and currentLastValid
              and currentBestLap > 0
              and currentLastLap > 0
              and lastLapIsBest
          then
            flashUntil = sim.time + BEST_LAP_FLASH_TIME_MS
          end
          bestLapFlashUntil[i] = flashUntil

          driverLapSnapshot[i] = currentLapCount

          standings[#standings + 1] = {
            idx               = i,
            name              = nickName(ac.getDriverName(i)),
            nationCode        = ac.getDriverNationCode(i),
            splinePosition    = car.splinePosition,
            focused           = car.focused,
            speed             = car.speedMs,
            trackPosM         = car.splinePosition * trackLength,
            gap               = 0,
            position          = car.racePosition,
            bestLap           = car.bestLapTimeMs,
            isLastLapValid    = car.isLastLapValid,
            lastLap           = car.previousLapTimeMs,
            tyre              = ac.getTyresName(i),
            isInPit           = car.isInPitlane,
            carName           = ac.getCarID(i),
            lapCount          = currentLapCount,
            bestLapFlashUntil = flashUntil,
          }
        end
      end
    end


    -- Sort by physical position on track, not race position.
    table.sort(standings, function(a, b) return a.splinePosition > b.splinePosition end)

    -- Find focused driver index in sorted standings.
    for pos, e in ipairs(standings) do
      if e.focused then
        focusedIndex = pos
        break
      end
    end
    if #standings > 0 and (focusedIndex < 1 or focusedIndex > #standings) then
      focusedIndex = 1
    end
  end
end

local function drawNationFlag(nationCode)
  local flagFilePath = nationFlagPathCache[nationCode]
  if not flagFilePath then
    flagFilePath = rootFolder .. string.format("/content/gui/NationFlags/%s.png", nationCode)
    nationFlagPathCache[nationCode] = flagFilePath
  end
  ui.image(flagFilePath, AppConfig.scale)
end

local function drawBadge(carName)
  local badgeFilePath = badgePathCache[carName]
  if not badgeFilePath then
    badgeFilePath = contentCarsFolder .. string.format("/%s/ui/badge.png", carName)
    badgePathCache[carName] = badgeFilePath
  end
  ui.image(badgeFilePath, AppConfig.scale)
end

--- Draws a cell with background and aligned text.
---@param text string
---@param lenght number
---@param colorText rgbm
---@param colorBack rgbm
---@param horizontalAligment ui.Alignment?
local function writeText(text, lenght, colorText, colorBack, horizontalAligment)
  local start = ui.getCursor()
  ui.drawRectFilled(start, start + vec2(lenght, AppConfig.scale + 2), colorBack)
  ui.dwriteTextAligned(text, AppConfig.scale, horizontalAligment, ui.Alignment.Center, vec2(lenght, AppConfig.scale + 2),
    false,
    colorText)
end

local function getState(player, ahead)
  -- Leader and focused.
  if player.position == 1 and player.focused then
    return State.LeaderFocused
  end

  -- Leader, not focused, but physically behind the focused driver.
  if player.position == 1 and not player.focused and not ahead then
    return State.LeaderBlue
  end

  -- Leader only.
  if player.position == 1 then
    return State.Leader
  end

  -- Focused non-leader.
  if player.focused then
    return State.Focused
  end
  if standings[focusedIndex] then
    -- BlueFlag: car behind on track but ahead in race position.
    if not ahead and player.position < standings[focusedIndex].position then
      return State.BlueFlag
    end

    -- AheadBlue: car ahead on track but behind in race position.
    if ahead and player.position > standings[focusedIndex].position then
      return State.AheadBlue
    end
  end
  return State.Standard
end

local function drawPlayerLine(player, ahead)
  local playerGap = 0
  local playerAhead = ahead
  local focused = standings[focusedIndex]

  if not player.focused and focused then
    playerGap, playerAhead = getRelativeGapSeconds(focused, player)
  end

  -- Resolve color state after ahead/behind is recomputed from live gap.
  local state = getState(player, playerAhead)

  writeText(string.format("%.2d", player.position), AppConfig.scale * 1.3, getColors(state, "position"))

  if AppConfig.showBadge then
    ui.sameLine()
    drawBadge(player.carName)
  end
  if AppConfig.showNationFlag then
    ui.sameLine()
    drawNationFlag(player.nationCode)
  end
  ui.sameLine()
  local fg, bg = getColors(state, "text")
  writeText(player.name, AppConfig.scale * 10, fg, bg, ui.Alignment.Start)
  if AppConfig.showTyre then
    ui.sameLine()
    writeText(player.tyre, AppConfig.scale * 1.7, getColors(state, "text"))
  end
  if AppConfig.showLapCount then
    ui.sameLine()
    writeText(string.format("%.2d", player.lapCount), AppConfig.scale * 2.0, getColors(state, "text"))
  end
  ui.sameLine()
  if player.focused then
    writeText("", AppConfig.scale * 4, getColors(state, "text"))
  else
    player.gap = playerGap
    if player.gap > MAX_GAP_DISPLAY then
      player.gap = MAX_GAP_DISPLAY
    elseif player.gap < -MAX_GAP_DISPLAY then
      player.gap = -MAX_GAP_DISPLAY
    end
    fg, bg = getColors(state, "text")
    writeText(string.format("%.2fs", player.gap), AppConfig.scale * 4, fg, bg, ui.Alignment.End)
  end

  if AppConfig.showBestLap then
    ui.sameLine()
    fg, bg = getColors(state, "text")
    if player.bestLapFlashUntil > ac.getSim().time then
      fg = palette.fg_pbFlash
    end
    writeText(ac.lapTimeToString(player.bestLap), AppConfig.scale * 4, fg, bg, ui.Alignment.End)
  end
  if AppConfig.showLastLap then
    ui.sameLine()
    if player.bestLapFlashUntil > ac.getSim().time then
      _, bg = getColors(state, "text")
      writeText(ac.lapTimeToString(player.lastLap), AppConfig.scale * 4, palette.fg_pbFlash, bg, ui.Alignment.End)
    elseif player.isLastLapValid then
      fg, bg = getColors(state, "text")
      writeText(ac.lapTimeToString(player.lastLap), AppConfig.scale * 4, fg, bg, ui.Alignment.End)
    else
      fg, bg = getColors(state, "lapInvalid")
      writeText(ac.lapTimeToString(player.lastLap), AppConfig.scale * 4, fg, bg, ui.Alignment.End)
    end
  end
  if player.isInPit then
    ui.sameLine()
    writeText("P", AppConfig.scale, getColors(state, "text"))
  end
end

function script.windowMain(dt)
  if not appVisible then return end

  local n = #standings
  if n == 0 then
    return
  end

  ui.pushDWriteFont('OneSlot:/fonts;Weight=Bold;Stretch=Condensed')
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(2, 3))

  if focusedIndex < 1 or focusedIndex > n then
    focusedIndex = 1
  end

  local drawn = {}
  local function drawOffset(offset)
    local idx = ((focusedIndex + offset - 1) % n) + 1
    if drawn[idx] then return end
    drawn[idx] = true
    drawPlayerLine(standings[idx], offset < 0)
  end

  local maxOthers = math.max(0, n - 1)
  local ahead = math.min(AppConfig.showAhead, maxOthers)
  local behind = math.min(AppConfig.showBehind, maxOthers)

  for d = -ahead, -1 do
    drawOffset(d)
  end
  drawOffset(0)
  for d = 1, behind do
    drawOffset(d)
  end

  ui.popStyleVar()
  ui.popDWriteFont()
end

function script.windowSettings(dt)
  AppConfig.scale = ui.slider('##scale', AppConfig.scale, 10.0, 50.0, 'Scale: %1.0f')
  AppConfig.showAhead = ui.slider('##showBefore', AppConfig.showAhead, 1.0, 10.0, 'Show car ahead: %1.0f')
  AppConfig.showBehind = ui.slider('##showAfter', AppConfig.showBehind, 1.0, 10.0, 'Show car behind: %1.0f')
  if ui.checkbox("Show car badge logo", AppConfig.showBadge) then
    AppConfig.showBadge = not AppConfig.showBadge
  end
  if ui.checkbox("Show nation flag", AppConfig.showNationFlag) then
    AppConfig.showNationFlag = not AppConfig.showNationFlag
  end
  if ui.checkbox("Show lap count", AppConfig.showLapCount) then
    AppConfig.showLapCount = not AppConfig.showLapCount
  end
  if ui.checkbox("Show tyre", AppConfig.showTyre) then
    AppConfig.showTyre = not AppConfig.showTyre
  end
  if ui.checkbox("Show last lap", AppConfig.showLastLap) then
    AppConfig.showLastLap = not AppConfig.showLastLap
  end
  if ui.checkbox("Show best lap", AppConfig.showBestLap) then
    AppConfig.showBestLap = not AppConfig.showBestLap
  end
end

function script.onShowWindowMain() appVisible = true end

function script.onHideWindowMain() appVisible = false end

if ac.getPatchVersionCode() < 3116 then
  script.windowMain = function(dt)
    ui.text('CSP v0.2.4 or above is required.')
  end
end