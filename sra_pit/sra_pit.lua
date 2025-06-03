-- Created by Wile64 - May 2025

-- Couper en replay
-- Couper si 0 non visible

DEBUG = false

-- Config & Constants
VERSION = 1.1

local AppConfig = ac.storage {
  scaleUI = 20,
  pitTimer = true,
  pitlaneTimer = true
}

-- ID de la fenêtre utilisée
local WINDOW_ID = "windowPit"

-- Chargement des paramètres depuis le fichier car.ini
-- Ces valeurs déterminent les temps standards pour les réparations et le ravitaillement
local pitstopINI =
    ac.INIConfig.load(ac.getFolder(ac.FolderID.Root) .. "\\system\\cfg\\pitstop.ini")

local carINI = ac.INIConfig.carData(0, 'car.ini')
local pitParams = {
  tyreChangeTime = carINI:get("PIT_STOP", "TYRE_CHANGE_TIME_SEC", 0),       -- Temps pour changer tous les pneus
  fuelTimePerLiter = carINI:get("PIT_STOP", "FUEL_LITER_TIME_SEC", 0),      -- Temps pour remplir 1L d'essence
  bodyRepairTime = carINI:get("PIT_STOP", "BODY_REPAIR_TIME_SEC", 0),       -- Temps pour réparer 10% de la carrosserie
  engineRepairTime = carINI:get("PIT_STOP", "ENGINE_REPAIR_TIME_SEC", 0),   -- Temps pour réparer 10% du moteur
  suspensionRepairTime = carINI:get("PIT_STOP", "SUSP_REPAIR_TIME_SEC", 0), -- Temps pour réparer 10% de la suspension
  maxFuel = carINI:get("FUEL", "MAX_FUEL", 0),                              -- Capacité maximale du réservoir
  ShowInPitlane = pitstopINI:get("SETTINGS", "AUTO_APP_ON_PITLANE", 1) == 1,
  visibilityMaxTime = pitstopINI:get("SETTINGS", "VISIBILITY_MAX_TIME", 3),
  showWindowUntil = 0 -- Temps auquel la fenêtre doit rester affichée
}

-- État de l'application, stocke les infos liées au pitstop
local state = {
  fuelToAdd = 0,           -- Quantité d'essence à ajouter
  minFuel = 0,             -- Quantité minimale
  showPitUI = false,       -- Affichage de l'UI
  pitEntryTime = 0,        -- Horodatage de l'entrée au pit
  pitExitTime = 0,         -- Horodatage de la sortie du pit
  isTimingPit = false,     -- Est-ce que le chrono est actif ?
  lastPitDuration = 0,     -- Dernier temps de pit enregistré
  wasInPit = false,        -- État précédent dans le pit
  pitFinished = false,     -- Pit terminé ?
  pitlaneEntryTime = 0,    -- Horodatage d'entrée dans la voie des stands
  lastPitlaneDuration = 0, -- Dernier temps passé dans la voie
  wasInPitlane = false,    -- État précédent dans la voie des stands
  showSetupWindow = false
}


if ac.onSessionStart then
  ac.onSessionStart(function()
    state.pitlaneEntryTime = os.clock()
    if DEBUG then
      ac.log('New session start')
      physics.setCarBodyDamage(0, vec4(100, 100, 0, 0))
      -- vec4(0, 0, 0, 100) = 20 sec
      -- vec4(0, 0, 100, 100) = 42 sec
      --vec4(100, 100, 0, 0) = 40,5 sec
      -- vec4(100, 100, 100, 100) = 83 sec
      --vec4(10, 0, 0, 0) = 4 sec
      --vec4(10, 0, 0, 10) = 8 sec
      --vec4(40, 0, 0, 10) = 13 sec
      --vec4(100, 0, 0, 10) = 25 sec
      --vec4(100, 80, 30, 10) = 50 sec
      --vec4(80, 80, 80, 80) = 68 sec
      --vec4(4, 0, 0, 0) = 3,5 sec
      --vec4(1, 0, 0, 0) = 3 sec
      --vec4(1, 1,1, 1) = 11 sec
      --vec4(1, 1,1, 0) = 9 sec
      --vec4(1, 1, 0, 0) = 6 sec
      physics.setCarEngineLife(0, 200)
    end
  end)
end

-- Ouvre la fenêtre manuellement pour une durée donnée (en secondes)
local function showPitWindowFor()
  pitParams.showWindowUntil = ac.getSim().gameTime + pitParams.visibilityMaxTime
end

-- Conditions pour désactiver complètement l'affichage
local function shouldBlockPitWindow()
  return ac.getSim().isReplayActive or ac.getSim().focusedCar ~= 0
end

-- Détermine si la fenêtre doit être visible (dans les stands ou affichage temporaire)
local function shouldShowPitWindow()
  if shouldBlockPitWindow() then return false end
  local now = ac.getSim().gameTime
  return ac.getCar(0).isInPitlane or now < pitParams.showWindowUntil
end

-- Gère l'affichage ou non de la fenêtre, à appeler dans script.update()
local function updatePitWindow()
  local isOpen = ac.isWindowOpen(WINDOW_ID)
  local shouldShow = shouldShowPitWindow()

  if shouldShow and not isOpen then
    ac.setWindowOpen(WINDOW_ID, true)
  elseif not shouldShow and isOpen then
    ac.setWindowOpen(WINDOW_ID, false)
  end
end

-- Fonctions d'affichage texte formaté pour l'UI
local function inline(title, value)
  ui.dwriteText(title, AppConfig.scaleUI, rgbm.colors.white)
  ui.sameLine(0, AppConfig.scaleUI)
  ui.dwriteText(value, AppConfig.scaleUI, rgbm.colors.lime)
end

local function warning(title)
  ui.dwriteText(title, AppConfig.scaleUI - 2, rgbm.colors.orange)
end

local function separator()
  local pos = ui.getCursor()
  pos.y = pos.y + 2
  local lenght = ui.windowWidth()
  ui.drawLine(pos, vec2(lenght, pos.y + 2), rgbm.colors.maroon, 2)
  ui.dummy(4)
end

-- Fonction pour calculer le temps de réparation carrosserie selon les 4 zones
local function calculateBodyRepairTime(car, baseTime)
  local totalTime = 0
  local lowZones = {}
  local highZones = 0

  for i = 0, 3 do
    local d = car.damage[i] or 0
    if d > 0 then
      if d <= 3 then
        table.insert(lowZones, d)
      else
        totalTime = totalTime + math.max((d / 100) * baseTime, 3.0) + 1.0
        highZones = highZones + 1
      end
    end
  end

  local n = #lowZones
  if n > 0 then
    if n == 4 then
      totalTime = totalTime + 11
    else
      totalTime = totalTime + (3 * n)
    end
  end

  return totalTime
end

-- Calcule le temps pour réparer la suspension (moyenne des 4 roues)
local function calculateSuspensionTime(car, baseTime)
  local damage = 0
  for i = 0, 3 do
    damage = damage + (car.wheels[i].suspensionDamage or 0)
  end
  return damage * baseTime
end

-- Calcule le temps de réparation moteur basé sur la vie restante
local function calculateEngineTime(car, baseTime)
  local life = math.min(car.engineLifeLeft or 1000, 1000)
  local damage = 1 - life / 1000
  return damage * 100 * baseTime
end

-- Calcule le temps estimé pour ajouter l'essence
local function calculateFuelTime(fuelToAdd, timePerLiter)
  local fuelTime = fuelToAdd * timePerLiter
  if fuelToAdd <= 10 and fuelToAdd > 0 then
    fuelTime = fuelTime + 0.20
  end
  return fuelTime
end

-- Estimation automatique du carburant nécessaire pour terminer la course
-- Renvoie aussi l'excès si trop d'essence est prévu
local function calculateAutoFuel(car)
  if car then
    local sim = ac.getSim()
    if sim.raceSessionType ~= ac.SessionType.Race then return nil, nil end
    if (car.fuelPerLap or 0) <= 0 then return nil, nil end
    local session = ac.getSession(sim.currentSessionIndex)
    if session ~= nil then
      local fuelPerLap = car.fuelPerLap
      local currentFuel = car.fuel or 0
      local lapsToGo = 0

      if session.isTimedRace then
        local lapTime = car.bestLapTimeMs
        if lapTime > 0 and sim.sessionTimeLeft > 0 then
          lapsToGo = math.ceil(sim.sessionTimeLeft / lapTime)
        end
      else
        lapsToGo = math.max(0, session.laps - car.lapCount)
      end

      if session.hasAdditionalLap then
        lapsToGo = lapsToGo + 1
      end
      local fuelNeeded = fuelPerLap * lapsToGo
      local toAdd = fuelNeeded - currentFuel
      local maxAdd = math.max(0, math.min(toAdd, pitParams.maxFuel - currentFuel))
      local excess = math.max(0, (currentFuel + state.fuelToAdd) - fuelNeeded)

      return maxAdd, excess
    end
  end

  return nil, nil
end


-- Display Sections
local function drawPitTimer()
  if AppConfig.pitTimer then
    if state.isTimingPit then
      local t = os.clock() - state.pitEntryTime
      inline("⏱ Pit Time:", string.format("%.2f sec", t))
    elseif state.lastPitDuration > 0 then
      inline("🏁 Last Pit Duration:", string.format("%.2f sec", state.lastPitDuration))
    else
      inline("🅿 Waiting to enter pits...", "")
    end
  end
  if AppConfig.pitlaneTimer then
    if state.wasInPitlane then
      local t = os.clock() - state.pitlaneEntryTime
      inline("📏 Pitlane Time:", string.format("%.2f sec", t))
    elseif state.lastPitlaneDuration > 0 then
      inline("📏 Last Pitlane Duration:", string.format("%.2f sec", state.lastPitlaneDuration))
    else
      inline("📏 Waiting to enter pitLane...", "")
    end
  end
end

local function drawFuelSection(car)
  --section("Fuel:")
  separator()

  if ac.getSim().raceSessionType ~= ac.SessionType.Race then
    if ui.iconButton("⛽", AppConfig.scaleUI + 6, 0, true, ui.ButtonFlags.Confirm) then
      state.fuelToAdd = pitParams.maxFuel
    end
    ui.sameLine()
    inline("ADD LITERS:", "")
    ui.sameLine()
    if ui.iconButton("➖", AppConfig.scaleUI + 6, 0, true, ui.ButtonFlags.Repeat) then
      state.fuelToAdd = math.max(0, state.fuelToAdd - 1)
    end
    ui.sameLine()
    if ui.iconButton("➕", AppConfig.scaleUI + 6, 0, true, ui.ButtonFlags.Repeat) then
      state.fuelToAdd = math.min(state.fuelToAdd + 1, pitParams.maxFuel)
    end
    ui.sameLine(0, 20)
    ui.dwriteText(string.format("%.1f", state.fuelToAdd), AppConfig.scaleUI + 2, rgbm.colors.lime)
  else
    local autoFuel, fuelExcess = calculateAutoFuel(car)
    if autoFuel then
      inline("Auto fuel needed:", string.format("%.1f L", autoFuel))
      state.fuelToAdd = autoFuel
      if fuelExcess > 0 then
        ui.sameLine()
        inline("Excess:", string.format("%.1f L", fuelExcess))
      end
    end
  end
  local fuelTime = calculateFuelTime(state.fuelToAdd, pitParams.fuelTimePerLiter)
  inline("Estimated Fuel Time:", string.format("%.1f sec", fuelTime))
end

local function drawTyreSection()
  separator()
  inline("Estimated Tyres Time:", string.format("%.0f sec", pitParams.tyreChangeTime))
end

local function drawRepairSection(car)
  separator()

  local bodyTime = calculateBodyRepairTime(car, pitParams.bodyRepairTime)
  inline("Estimated Body Time:", string.format("%.0f sec", bodyTime))
  separator()
  local suspTime = calculateSuspensionTime(car, pitParams.suspensionRepairTime)
  warning("*Repairing suspension also repairs BODY!")
  inline("Estimated Suspension Time:", string.format("%.0f sec", suspTime))

  separator()
  local engineTime = calculateEngineTime(car, pitParams.engineRepairTime)
  inline("Estimated Engine Time:", string.format("%.0f sec", engineTime))
end

local function showSetup(size)
  ui.beginChild("showPitSetup", size, true, ui.WindowFlags.None)
  if ui.iconButton(ui.Icons.Minus, 22, 0, true, ui.ButtonFlags.Repeat) then
    AppConfig.scaleUI = math.max(5, AppConfig.scaleUI - 1)
  end
  ui.sameLine()
  AppConfig.scaleUI = ui.slider('##scaleSlider', AppConfig.scaleUI, 5, 100, 'Scale: %1.1f%')
  ui.sameLine()
  if ui.iconButton(ui.Icons.Plus, 22, 0, true, ui.ButtonFlags.Repeat) then
    AppConfig.scaleUI = math.min(100, AppConfig.scaleUI + 1)
  end
  if ui.checkbox("Show pit timer", AppConfig.pitTimer) then
    AppConfig.pitTimer = not AppConfig.pitTimer
  end
  if ui.checkbox("Show pitlane timer", AppConfig.pitlaneTimer) then
    AppConfig.pitlaneTimer = not AppConfig.pitlaneTimer
    state.pitlaneEntryTime = os.clock()
  end
  ui.endChild()
end

-- Main UI Window
function script.windowPit(dt)
  if ui.iconButton(ui.Icons.Settings, AppConfig.scaleUI + 6, 0, true, ui.ButtonFlags.Repeat) then
    state.showSetupWindow = not state.showSetupWindow
  end
  if state.showSetupWindow then
    showSetup(vec2(250, 100))
  end
  local car = ac.getCar(0)
  if car then
    if car.isInPitlane then
      --ui.sameLine()
      inline("IN PIT:", string.format("%s", car.isInPit))
    end
    drawPitTimer()
    drawFuelSection(car)
    drawTyreSection()
    drawRepairSection(car)
  end
end

-- Setting UI Window
function script.windowSetting(dt)
  if ui.iconButton(ui.Icons.Minus, 22, 0, true, ui.ButtonFlags.Repeat) then
    AppConfig.scaleUI = math.max(5, AppConfig.scaleUI - 1)
    showPitWindowFor()
  end
  ui.sameLine()
  AppConfig.scaleUI = ui.slider('##scaleSlider', AppConfig.scaleUI, 5, 100, 'Scale: %1.1f%')
  ui.sameLine()
  if ui.iconButton(ui.Icons.Plus, 22, 0, true, ui.ButtonFlags.Repeat) then
    AppConfig.scaleUI = math.min(100, AppConfig.scaleUI + 1)
    showPitWindowFor()
  end
  if ui.checkbox("Show pit timer", AppConfig.pitTimer) then
    AppConfig.pitTimer = not AppConfig.pitTimer
  end
  if ui.checkbox("Show pitlane timer", AppConfig.pitlaneTimer) then
    AppConfig.pitlaneTimer = not AppConfig.pitlaneTimer
    state.pitlaneEntryTime = os.clock()
  end
end

-- Timer logic
local function updatePitTimer()
  local car = ac.getCar(0)
  if car then
    local inPitlane = car.isInPitlane
    local speed = car.speedKmh
    local brake = car.brake or 0

    if AppConfig.pitlaneTimer then
      -- Chrono pitlane
      if inPitlane and not state.wasInPitlane then
        state.pitlaneEntryTime = os.clock()
        state.wasInPitlane = true
      elseif not inPitlane and state.wasInPitlane then
        state.lastPitlaneDuration = os.clock() - state.pitlaneEntryTime
        state.wasInPitlane = false
      end
    end
    if AppConfig.pitTimer then
      -- Détection de l'arret aux stands
      -- isInPit n'est pas forcement vrai quand le ravitaillement est fait :(
      -- je pars qur le principe suivvant pour valider l'arret aux stands
        -- dans la PitLane 
        -- le frein est bloqué (AC bloque le frein pendant l'arret)
        -- la vitesse est de zero
      if inPitlane and not state.wasInPit and brake == 1 and speed <= 1 then
        state.pitEntryTime = os.clock()
        state.isTimingPit = true
        state.wasInPit = true
        state.pitFinished = false
      end

      -- Si frein relâché, on considère la réparation comme terminée
      if state.wasInPit and not state.pitFinished and brake == 0 then
        state.pitExitTime = os.clock()
        state.lastPitDuration = state.pitExitTime - state.pitEntryTime
        state.isTimingPit = false
        state.pitFinished = true
      end

      -- Réinitialisation après mouvement (sortie effective)
      if state.wasInPit and state.pitFinished and speed >= 1 then
        state.wasInPit = false
        state.pitFinished = false
      end
    end
  end
end

function script.update(dt)
  if ac.isKeyReleased(ui.KeyIndex.Down) then
    showPitWindowFor()
  end
  updatePitWindow()
  updatePitTimer()
end
