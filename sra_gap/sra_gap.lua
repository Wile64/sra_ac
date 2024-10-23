VERSION = 1.0

local AppConfig = ac.storage {
  gapQualifFormFirst = false, -- Écart à afficher : du premier ou du pilote précédent
  scale = 2,                  -- Échelle de l'affichage
  showTyres = true,           -- Afficher les pneus
  showLaps = true,            -- Afficher le nombre de tours
  showBestLapTime = true,     -- Afficher le meilleur temps au tour
  showLastLapTime = true,     -- Afficher le dernier temps au tour
  showGap = true,             -- Afficher l'écart avec le pilote précédent
  showFirst = true,           -- Afficher le premier pilote
  showCarCount = 3            -- Nombre de voitures à afficher autour du joueur
}

local visible = true                       -- App visible ou non
local fontsize = 10 * AppConfig.scale       -- Taille de la police, ajustée à l'échelle
local updateInterval = 0.4                  -- Intervalle de mise à jour en secondes
local timeSinceLastUpdate = 0               -- Temps écoulé depuis la dernière mise à jour
local VersionCSP = ac.getPatchVersionCode() -- Version du patch CSP utilisé
local currentPosition = 1                   -- Position actuelle du joueur
local leaderboard = {}                      -- Tableau des pilotes dans le classement

--- Convertir un temps en millisecondes en une chaîne de caractères formatée
---@param lapTimeMs number
---@return string
local function lapTimeToString(lapTimeMs)
  local minutes = math.floor(lapTimeMs / 60e3)
  if minutes > 0 then
    return string.format("%02d:%02.3f", minutes, (lapTimeMs / 1000) % 60)
  else
    return string.format("%02.3f", (lapTimeMs / 1000) % 60)
  end
end
--- Convertir un écart en secondes en chaîne de caractères formatée
---@param gap number
---@return string
local function gapToString(gap)
  local minutes = math.floor(gap / 60)
  local seconds = gap - (minutes * 60)
  local centiseconds = math.floor((seconds - math.floor(seconds)) * 100)
  if minutes > 0 then
    return string.format("%d:%02d.%02d", minutes, math.floor(seconds), centiseconds)
  else
    return string.format("%d.%02d", seconds, centiseconds)
  end
end
--- Obtenir l'écart réel entre deux voitures
---@param car1 ac.StateCar
---@param car2 ac.StateCar
---@return string
local function getRealGapStr(car1, car2)
  if car1.lapCount ~= car2.lapCount then
    local lapDiff = car1.lapCount - car2.lapCount
    if lapDiff > 1 then
      return string.format("%d Laps", car1.lapCount - car2.lapCount)
    else
      return string.format("%d Lap", car1.lapCount - car2.lapCount)
    end
  else
    if car2.speedKmh < 1 then -- Si la voiture 2 est immobile, aucun écart n'est affiché
      return '--'
    end
    local car1Pos = car1.splinePosition
    local car2Pos = car2.splinePosition
    return gapToString(((car1Pos - car2Pos) / (car2.speedKmh / 3.6) * ac.getSim().trackLengthM))
  end
end

--- Fonction pour raccourcir et formater le nom d'un pilote
---@param name string
---@return string
local function nickName(name)
  local prev_token = ""
  local last = ""
  local result = ""
  -- Extraire les initiales et le dernier nom du pilote
  for token in string.gmatch(name, "[^%s._-[-(())[{}|]+") do
    if prev_token ~= "" then
      if string.match(prev_token, ".*]") then
        --print(prev_token)
        result = result
      else
        --print(prev_token)
        result = result .. string.sub(prev_token, 1, 1) .. "."
      end
    end
    prev_token = token
    last = token
  end
  return result .. last
end

--- Écrire un texte avec formatage spécifique
---@param text string
---@param lenght number
---@param colorText rgbm
---@param colorBack rgbm
---@param horizontalAligment ui.Alignment?
local function writeText(text, lenght, colorText, colorBack, horizontalAligment)
  local start = ui.getCursor()
  ui.drawRectFilled(start, start + vec2(lenght, fontsize + 10), colorBack)
  ui.dwriteTextAligned(text, fontsize, horizontalAligment, ui.Alignment.Center, vec2(lenght, fontsize + 10), false,
    colorText)
end

--- Afficher une ligne représentant une voiture dans le classement
---@param car table Données de la voiture
local function drawLine(car)
  local colorBack = rgbm.colors.black
  if car.index == car.focusedCar then -- Mettre en surbrillance la voiture du joueur sélectionné
    colorBack = rgbm.colors.cyan
  end
  writeText(car.racePosition, fontsize + 5, colorBack, rgbm.colors.white)
  ui.sameLine()
  writeText(car.driverName, fontsize * 8, rgbm.colors.white, colorBack, ui.Alignment.Start)
  ui.sameLine()
  if AppConfig.showLaps then
    writeText(car.laps, fontsize + 5, rgbm.colors.white, colorBack)
    ui.sameLine()
  end
  if AppConfig.showBestLapTime then
    writeText(car.bestLapTimeMs, fontsize * 4, rgbm.colors.white, colorBack, ui.Alignment.End)
    ui.sameLine()
  end
  if AppConfig.showLastLapTime then
    local validLapColor = rgbm.colors.white
    if not car.isLastLapValid then -- Couleur rouge si le dernier tour est invalide
      validLapColor = rgbm.colors.red
    end
    writeText(car.previousLapTimeMs, fontsize * 4, validLapColor, colorBack, ui.Alignment.End)
    ui.sameLine()
  end
  if AppConfig.showGap then
    if car.gap == '' then
      writeText(car.gap, fontsize * 4, rgbm.colors.black, rgbm.colors.black, ui.Alignment.End)
    else
      if car.gap < '1' then
        writeText(car.gap, fontsize * 4, rgbm.colors.white, rgbm(0.6, 0, 0, 1), ui.Alignment.End)
      else
        writeText(car.gap, fontsize * 4, rgbm.colors.white, rgbm(0.1, 0.3, 0.6, 1), ui.Alignment.End)
      end
    end
  end
  if AppConfig.showTyres then
    ui.sameLine()
    writeText(car.tyresName, fontsize * 2, rgbm.colors.black, rgbm.colors.gray)
  end
  if car.isInPit then
    ui.sameLine()
    writeText("P", fontsize, rgbm.colors.black, rgbm.colors.white)
  end
end

function script.windowMain(dt)
  if VersionCSP < 3116 then -- Vérifier la version du patch CSP 0.2.4
    ui.textAligned('CSP v0.2.4 or above is required.', 0.5, -0.1)
    return
  end
  ui.pushDWriteFont('OneSlot:\\fonts\\.')
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, 2)

  -- Calcul des indices pour afficher les voitures autour du joueur
  local min = math.max(currentPosition - AppConfig.showCarCount, 1)
  local max = math.min(currentPosition + AppConfig.showCarCount, #leaderboard)

  -- Affichage du premier pilote si configuré
  if #leaderboard > 1 and AppConfig.showFirst and min > 1 then
    drawLine(leaderboard[1])
    ui.separator()
  end
  -- Boucle d'affichage des voitures dans la plage définie
  for i = min, max do
    drawLine(leaderboard[i])
  end
  ui.popStyleVar()
  ui.popDWriteFont()
end

function script.windowSetting(dt)
  local scale, changed = ui.slider('##Scale', AppConfig.scale, 1.0, 3.0, 'Zoom scale: %1.1f')
  if changed then
    AppConfig.scale = scale
    fontsize = 10 * scale
  end
  AppConfig.showCarCount = ui.slider('##CarCount', AppConfig.showCarCount, 1.0, 5.0, 'Show cars: %1.0f')
  if ui.itemHovered() then
    ui.tooltip(function()
      ui.text("Number of cars to display in front and behind")
    end)
  end
  if ui.checkbox("Show Tyres", AppConfig.showTyres) then
    AppConfig.showTyres = not AppConfig.showTyres
  end
  if ui.itemHovered() then
    ui.tooltip(function()
      ui.text("Show or hide the tyres")
    end)
  end
  if ui.checkbox("Show best lap time", AppConfig.showBestLapTime) then
    AppConfig.showBestLapTime = not AppConfig.showBestLapTime
  end
  if ui.itemHovered() then
    ui.tooltip(function()
      ui.text("Show or hide best lap time")
    end)
  end
  if ui.checkbox("Show last lap time", AppConfig.showLastLapTime) then
    AppConfig.showLastLapTime = not AppConfig.showLastLapTime
  end
  if ui.itemHovered() then
    ui.tooltip(function()
      ui.text("Show or hide previous lap time")
    end)
  end
  if ui.checkbox("Show gap", AppConfig.showGap) then
    AppConfig.showGap = not AppConfig.showGap
  end
  if ui.itemHovered() then
    ui.tooltip(function()
      ui.text("Show or hide the gap")
    end)
  end
  if ui.checkbox("Gap from first in qualifying", AppConfig.gapQualifFormFirst) then
    AppConfig.gapQualifFormFirst = not AppConfig.gapQualifFormFirst
  end
  if ui.itemHovered() then
    ui.tooltip(function()
      ui.text("Gap from the first or the driver in front?")
    end)
  end
  if ui.checkbox("Show lap count", AppConfig.showLaps) then
    AppConfig.showLaps = not AppConfig.showLaps
  end
  if ui.itemHovered() then
    ui.tooltip(function()
      ui.text("Show or hide lap count")
    end)
  end
  if ui.checkbox("Show first", AppConfig.showFirst) then
    AppConfig.showFirst = not AppConfig.showFirst
  end
  if ui.itemHovered() then
    ui.tooltip(function()
      ui.text("Show or hide the first driver")
    end)
  end
end

function script.update(dt)
  if not visible then
    return
  end
  if VersionCSP < 3116 then
    return
  end
  timeSinceLastUpdate = timeSinceLastUpdate + dt
  if timeSinceLastUpdate >= updateInterval then
    local sim = ac.getSim()
    local session = ac.getSession(sim.currentSessionIndex)

    if session then
      local racePosition = 0
      leaderboard = {}
      for i = 0, #session.leaderboard - 1 do
        if session.leaderboard[i].car.isActive then
          local carData = {}
          racePosition = racePosition + 1
          if session.leaderboard[i].car.index == sim.focusedCar then
            currentPosition = racePosition
          end
          carData.focusedCar = sim.focusedCar
          carData.racePosition = string.format("%02d", racePosition)
          carData.driverName = nickName(ac.getDriverName(session.leaderboard[i].car.index) or "unknown")
          carData.laps = string.format("%02d", session.leaderboard[i].laps)
          carData.bestLapTimeMs = ac.lapTimeToString(session.leaderboard[i].car.bestLapTimeMs)
          carData.previousLapTimeMs = ac.lapTimeToString(session.leaderboard[i].car.previousLapTimeMs)
          carData.tyresName = ac.getTyresName(session.leaderboard[i].car.index, session.leaderboard[i].car.compoundIndex) or
              "??"
          carData.isInPit = session.leaderboard[i].car.isInPit or session.leaderboard[i].car.isInPitlane
          carData.isLastLapValid = session.leaderboard[i].car.isLastLapValid
          carData.index = session.leaderboard[i].car.index
          carData.gap = ""
          if AppConfig.showGap and sim.isSessionStarted then
            if sim.raceSessionType == ac.SessionType.Race then
              if i > 0 then
                if not carData.isInPit then
                  carData.gap = getRealGapStr(session.leaderboard[i - 1].car, session.leaderboard[i].car)
                end
              end
            else
              if i > 0 and session.leaderboard[i].car.bestLapTimeMs ~= 0 then
                local previous = i - 1
                if AppConfig.gapQualifFormFirst then
                  previous = 0
                end
                carData.gap = lapTimeToString(
                  session.leaderboard[i].car.bestLapTimeMs -
                  session.leaderboard[previous].car.bestLapTimeMs
                )
              end
            end
          end
          table.insert(leaderboard, carData)
        end
      end
    end
    -- Réinitialise le temps écoulé
    timeSinceLastUpdate = 0
  end
end

function script.onShowWindowMain(dt)
  visible = true
end

function script.onHideWindowMain(dt)
  visible = false
end
