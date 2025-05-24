--
-- Created by Wile64 on may 2025
--

local AppConfig           = ac.storage {
  showAhead      = 3,
  showBehind     = 3,
  showBadge      = true,
  showNationFlag = true,
  showNumber     = true,
  showTyre       = true,
  showBestLap    = true,
  showLastLap    = true,
  scale          = 10
}

local appVisible          = true
local updateInterval      = 1 -- Intervalle de mise à jour en secondes
local timeSinceLastUpdate = 0 -- Temps écoulé depuis la dernière mise à jour
local initialized         = false

local focusedIndex        = 0 -- index dans la liste
local nickNameCache       = {}
local standings           = {}

-- 1) CONFIGURATION
local POINT_SPACING       = 10                       -- espacement entre deux points (m)
local trackLength         = ac.getSim().trackLengthM -- longueur du circuit (m)
local N_POINTS            = math.floor(trackLength / POINT_SPACING)


local themeFocused   = {
  racePosition = { background = rgbm.colors.aqua, text = rgbm.colors.black },
  text = { background = rgbm(0.6, 0.6, 0.6, 0.5), text = rgbm.colors.aqua },
  pit = { background = rgbm.colors.white, text = rgbm.colors.black },
  LapValid = { background = rgbm(0.6, 0.6, 0.6, 0.5), text = rgbm.colors.white },
  notLapValid = { background = rgbm(0.6, 0.6, 0.6, 0.5), text = rgbm.colors.red },
}
local themeStandard  = {
  racePosition = { background = rgbm.colors.white, text = rgbm.colors.black },
  text = { background = rgbm(0.0, 0.0, 0.0, 0.5), text = rgbm.colors.white },
  pit = { background = rgbm.colors.white, text = rgbm.colors.black },
  LapValid = { background = rgbm(0.0, 0.0, 0.0, 0.5), text = rgbm.colors.white },
  notLapValid = { background = rgbm(0.0, 0.0, 0.0, 0.5), text = rgbm.colors.red },
}
local themeLeader    = {
  racePosition = { background = rgbm.colors.lime, text = rgbm.colors.black },
  text = { background = rgbm(0.0, 0.0, 0.0, 0.5), text = rgbm.colors.lime },
  pit = { background = rgbm.colors.white, text = rgbm.colors.black },
  LapValid = { background = rgbm(0.0, 0.0, 0.0, 0.5), text = rgbm.colors.white },
  notLapValid = { background = rgbm(0.0, 0.0, 0.0, 0.5), text = rgbm.colors.red },
}
local themeBlueFlag  = {
  racePosition = { background = rgbm.colors.cyan, text = rgbm.colors.black },
  text = { background = rgbm(0.0, 0.5, 1, 0.5), text = rgbm.colors.white },
  pit = { background = rgbm.colors.white, text = rgbm.colors.black },
  LapValid = { background = rgbm(0.0, 0.5, 1, 0.5), text = rgbm.colors.white },
  notLapValid = { background = rgbm(0.0, 0.5, 1, 0.5), text = rgbm.colors.red },
}
local themeAheadBlue = {
  racePosition = { background = rgbm.colors.white, text = rgbm.colors.blue },
  text = { background = rgbm(0.0, 0.0, 0.0, 0.5), text = rgbm.colors.cyan },
  pit = { background = rgbm.colors.white, text = rgbm.colors.black },
  LapValid = { background = rgbm(0.0, 0.0, 0.0, 0.5), text = rgbm.colors.cyan },
  notLapValid = { background = rgbm(0.0, 0.0, 0.0, 0.5), text = rgbm.colors.red },
}

if ac.onSessionStart then
  ac.onSessionStart(function()
    initialized = false
  end)
end

--- Génère un surnom court avec initiales en majuscule et première lettre du nom en majuscule
-- @param raw string  Nom complet tel que "[teamX] jean dupont"
-- @return string     Surnom formaté, ex. "J.Dupont"
local function nickName(raw)
  -- si déjà calculé, on renvoie directement
  if nickNameCache[raw] then
    return nickNameCache[raw]
  end

  -- sinon on calcule
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

  -- on stocke dans le cache
  nickNameCache[raw] = formatted
  return formatted
end

---------------- FONCTIONS GAP

--- Renvoie la distance cumulée (m) depuis le départ
local function getTotalDist(car)
  return car.lapCount * trackLength
      + car.splinePosition * trackLength
end

--- Renvoie l’indice du point sur lequel se trouve la car (0 à N_POINTS-1)
local function getPointIndex(car)
  local dist = getTotalDist(car)
  -- floor(dist/POINT_SPACING) donne 0,1,... puis on modulo N_POINTS
  return math.floor(dist / POINT_SPACING) % N_POINTS
end

--- Calcule le temps (s) qu’il faut à une vitesse constante pour parcourir
--- deltaPoints points (wrap-around géré grâce à modulo)
local function timeBetweenPoints(From, To)
  -- nombre de points à franchir en avant jusqu’à idxTo
  local idxTo = getPointIndex(To)
  local idxFrom = getPointIndex(From)
  local dp = (idxTo - idxFrom) % N_POINTS
  local dist = dp * POINT_SPACING
  return (From.speed > 1) and (dist / From.speed) or 0
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

    -- collecte distance parcourue (m) et vitesse (m/s)
    for i = 0, nCars - 1 do
      local car = ac.getCar(i)
      if car and car.isConnected and not car.isRetired then
        standings[#standings + 1] = {
          idx            = i,
          name           = nickName(ac.getDriverName(i)), -- récupère le nom du pilote
          nationCode     = ac.getDriverNationCode(i),
          splinePosition = car.splinePosition,
          focused        = car.focused,
          speed          = car.speedMs,
          gap            = 0,
          position       = car.racePosition,
          bestLap        = car.bestLapTimeMs,
          isLastLapValid = car.isLastLapValid,
          lastLap        = car.previousLapTimeMs,
          tyre           = ac.getTyresName(i),
          isInPit        = car.isInPitlane,
          number         = ac.getDriverNumber(i),
          carName        = ac.getCarID(i),
          lapCount       = car.lapCount,
        }
      end
    end

    -- tri descendant par distance
    table.sort(standings, function(a, b) return a.splinePosition > b.splinePosition end)

    -- trouve la position du joueur
    for pos, e in ipairs(standings) do
      if e.focused then
        focusedIndex = pos
        break
      end
    end
  end
end

local function drawNationFlag(nationCode)
  local flagFilePath = ac.getFolder(ac.FolderID.Root) .. string.format("/content/gui/NationFlags/%s.png", nationCode)
  ui.image(flagFilePath, AppConfig.scale)
end

local function drawBadge(carName)
  local badgeFilePath = ac.getFolder(ac.FolderID.ContentCars) .. string.format("/%s/ui/badge.png", carName)
  ui.image(badgeFilePath, AppConfig.scale)
end

--- Écrire un texte avec formatage spécifique
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

local function drawPlayerLine(player, ahead)
  local theme = themeStandard

  if player.position == 1 then
    theme = themeLeader
  end
  if player.focused then
    theme = themeFocused
  elseif not ahead and player.position < standings[focusedIndex].position then
    theme = themeBlueFlag
  elseif ahead and player.position > standings[focusedIndex].position then
    theme = themeAheadBlue
  end

  writeText(string.format("%.2d", player.position), AppConfig.scale * 1.3, theme.racePosition.text, theme.racePosition
    .background)

  if AppConfig.showBadge then
    ui.sameLine()
    drawBadge(player.carName)
  end
  if AppConfig.showNationFlag then
    ui.sameLine()
    drawNationFlag(player.nationCode)
  end

  if AppConfig.showNumber then
    ui.sameLine()
    writeText(string.format("%d", player.number), AppConfig.scale * 1.7, theme.text.text, theme.text.background)
  end
  ui.sameLine()
  writeText(player.name, AppConfig.scale * 10, theme.text.text, theme.text.background, ui.Alignment.Start)
  if AppConfig.showTyre then
    ui.sameLine()
    writeText(player.tyre, AppConfig.scale * 1.7, theme.text.text, theme.text.background)
  end
  ui.sameLine()
  if player.focused then
    writeText("", AppConfig.scale * 4, theme.text.text, theme.text.background)
  else
    if not player.isInPit then
      if ahead then
        player.gap = timeBetweenPoints(standings[focusedIndex], player)
      else
        player.gap = -timeBetweenPoints(player, standings[focusedIndex])
      end
    else
      player.gap = 0
      ac.debug('pit')
    end

    writeText(string.format("%.2fs", player.gap), AppConfig.scale * 4, theme.text.text, theme.text.background,
      ui.Alignment.End)
  end

  if AppConfig.showBestLap then
    ui.sameLine()
    writeText(ac.lapTimeToString(player.bestLap), AppConfig.scale * 4, theme.text.text, theme.text.background,
      ui.Alignment.End)
  end
  if AppConfig.showLastLap then
    ui.sameLine()
    if player.isLastLapValid then
      writeText(ac.lapTimeToString(player.lastLap), AppConfig.scale * 4, theme.LapValid.text, theme.LapValid.background,
        ui.Alignment.End)
    else
      writeText(ac.lapTimeToString(player.lastLap), AppConfig.scale * 4, theme.notLapValid.text,
        theme.notLapValid.background, ui.Alignment.End)
    end
  end
  if player.isInPit then
    ui.sameLine()
    writeText("P", AppConfig.scale, theme.pit.text, theme.pit.background)
  end
end


function script.windowMain(dt)
  if not appVisible then return end

  ui.pushDWriteFont('OneSlot:\\fonts\\.')
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(2, 3))

  local n = #standings

  local function drawRange(startOffset, count, isAhead)
    for d = startOffset, startOffset + count - 1 do
      local idx = ((focusedIndex + d - 1) % n) + 1
      drawPlayerLine(standings[idx], isAhead)
    end
  end

  drawRange(-AppConfig.showAhead, AppConfig.showAhead, true)
  drawPlayerLine(standings[focusedIndex], false)
  drawRange(1, AppConfig.showBehind, false)

  ui.popStyleVar()
  ui.popDWriteFont()
end

function script.windowSettings(dt)
  AppConfig.scale = ui.slider('##scale', AppConfig.scale, 10.0, 30.0, 'Scale: %1.0f')
  AppConfig.showAhead = ui.slider('##showBefore', AppConfig.showAhead, 1.0, 10.0, 'Show car ahead: %1.0f')
  AppConfig.showBehind = ui.slider('##showAfter', AppConfig.showBehind, 1.0, 10.0, 'Show car behind: %1.0f')
  if ui.checkbox("Show car badge logo", AppConfig.showBadge) then
    AppConfig.showBadge = not AppConfig.showBadge
  end
  if ui.checkbox("Show nation flag", AppConfig.showNationFlag) then
    AppConfig.showNationFlag = not AppConfig.showNationFlag
  end
  if ui.checkbox("Show car number", AppConfig.showNumber) then
    AppConfig.showNumber = not AppConfig.showNumber
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
