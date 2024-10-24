--
-- Created by Wile64 on october 2023
--

VERSION = 1.02

local updateInterval = 0.4    -- Intervalle de mise à jour en secondes
local timeSinceLastUpdate = 0 -- Temps écoulé depuis la dernière mise à jour

local randomTimer = 5.0
local randomTimerOn = false
local timerKey = 0
local visible = false

local isSessionStarted = false
local TeleportToPits = false
local driversList = {}
local selectedDriver = 1

local cameraView = {
  { 'Cockpit (F1)',         ac.CameraMode.Cockpit },
  { 'Car (F6)',             ac.CameraMode.Car },
  { 'Drivable (F1)',        ac.CameraMode.Drivable },
  { 'Track',                ac.CameraMode.Track },
  { 'Helicopter',           ac.CameraMode.Helicopter },
  { 'OnBoardFree (F5)',     ac.CameraMode.OnBoardFree },
  { 'Free (F7)',            ac.CameraMode.Free },
  { 'Deprecated',           ac.CameraMode.Deprecated },
  { 'ImageGeneratorCamera', ac.CameraMode.ImageGeneratorCamera },
}

local cameraChase = {
  { 'Chase',  ac.DrivableCamera.Chase },
  { 'Chase2', ac.DrivableCamera.Chase2 },
  { 'Bonnet', ac.DrivableCamera.Bonnet },
  { 'Bumper', ac.DrivableCamera.Bumper },
  { 'Dash',   ac.DrivableCamera.Dash },
}

local function drawKeyValue(key, value)
  ui.text(key)
  ui.sameLine()
  ui.text(value)
end

local function randomCamera()
  local viewList = {
    { 0, { ac.CameraMode.Cockpit, -1 } },
    { 1, { ac.CameraMode.Drivable, -1 } },
    { 2, { ac.CameraMode.Helicopter, -1 } },
    { 3, { ac.CameraMode.OnBoardFree, -1 } }
  }

  for i = 0, ac.getSim().trackCamerasSetsCount - 1 do
    table.insert(viewList, { #viewList, { ac.CameraMode.Track, i } })
  end
  for i = 0, ac.getCar(ac.getSim().focusedCar).carCamerasCount - 1 do
    table.insert(viewList, { #viewList, { ac.CameraMode.Car, i } })
  end
  math.randomseed(os.time())
  local camera = math.random(1, #viewList)

  if viewList[camera][2][2] == -1 then
    ac.setCurrentCamera(viewList[camera][2][1])
  else
    ac.setCurrentCamera(viewList[camera][2][1])
    ac.setCurrentCarCamera(viewList[camera][2][2])
  end
end

local function setTimer()
  clearInterval(timerKey)
  timerKey = setInterval(function() if randomTimerOn then randomCamera() end end, randomTimer, '#timer')
end

function script.update(dt)
  if not visible then return end
  if isSessionStarted ~= ac.getSim().isSessionStarted then
    isSessionStarted = ac.getSim().isSessionStarted
    if not ac.getCar(0).isInPit and TeleportToPits then
      ac.tryToTeleportToPits()
    end
  end
  timeSinceLastUpdate = timeSinceLastUpdate + dt
  if timeSinceLastUpdate >= updateInterval then
    local sim = ac.getSim()
    local session = ac.getSession(sim.currentSessionIndex)
    if session then
      table.clear(driversList)
      for i = 0, #session.leaderboard - 1 do
        if session.leaderboard[i].car.isActive then
          local carData = {}
          carData.racePosition = tostring(ac.getCar(carData.index).racePosition)
          carData.driverName = ac.getDriverName(session.leaderboard[i].car.index) or "unknown" 
          carData.index = session.leaderboard[i].car.index
          carData.driverNumber = tostring(ac.getDriverNumber(carData.index))
          carData.driverNationality = ac.getDriverNationality(carData.index)
          carData.driverTeam = ac.getDriverTeam(carData.index)
          carData.racePosition = tostring(ac.getCar(carData.index).racePosition)
          carData.carName = ac.getCarName(carData.index)
          carData.carBrand = ac.getCarBrand(carData.index)
          carData.carCountry = ac.getCarCountry(carData.index)
          carData.mass = tostring(session.leaderboard[i].car.mass) .. "kg"
          carData.year = tostring(session.leaderboard[i].car.year)
          table.insert(driversList, carData)
        end
      end
      table.sort(driversList, function(a, b) return a.driverName < b.driverName end)
    end
    timeSinceLastUpdate = 0
  end
end

function script.windowMain(dt)
  ui.beginGroup()
  ui.header('Drivers:')

  ui.childWindow('##drivers', vec2(150, 200), function()
    for i = 1, #driversList do
      if ac.getSim().focusedCar == driversList[i].index then selectedDriver = i end
      if ui.selectable(driversList[i].driverName, ac.getSim().focusedCar == driversList[i].index) then
        ac.focusCar(driversList[i].index)
        selectedDriver = i
      end
    end
  end)
  ui.endGroup()
  ui.sameLine(0, 20)
  ui.beginGroup()
  ui.header('Focused:')
  if #driversList > 0 then
    drawKeyValue("- Driver Name: ", driversList[selectedDriver].driverName)
    drawKeyValue("- Driver Number: ", driversList[selectedDriver].driverNumber)
    drawKeyValue("- Driver country: ", driversList[selectedDriver].driverNationality)
    drawKeyValue("- Driver Team: ", driversList[selectedDriver].driverTeam)
    drawKeyValue("- Driver Position: ", driversList[selectedDriver].racePosition)
    drawKeyValue("- Car Name: ", driversList[selectedDriver].carName)
    drawKeyValue("- Car Brand: ", driversList[selectedDriver].carBrand)
    drawKeyValue("- Car Country: ", driversList[selectedDriver].carCountry)
    drawKeyValue("- Car mass: ", driversList[selectedDriver].mass)
    drawKeyValue("- Car year: ", driversList[selectedDriver].year)
    ui.newLine()
  end

  ui.endGroup()
  ui.sameLine(0, 20)
  ui.beginGroup()

  ui.header('Camera:')
  ui.combo('##Camera', cameraView[ac.getSim().cameraMode + 1][1], ui.ComboFlags.HeightChubby, function()
    for i, v in ipairs(cameraView) do
      if ui.selectable(v[1]) then
        ac.setCurrentCamera(v[2])
      end
    end
  end)
  ui.header('Camera Chase:')
  ui.combo('##Chase', cameraChase[ac.getSim().driveableCameraMode + 1][1], ui.ComboFlags.HeightChubby, function()
    for i, v in ipairs(cameraChase) do
      if ui.selectable(v[1]) then
        ac.setCurrentCamera(ac.CameraMode.Drivable)
        ac.setCurrentDrivableCamera(v[2])
      end
    end
  end)
  ui.header('Camera Car:')
  ui.combo('##Car', string.format("Camera %d", ac.getSim().carCameraIndex), ui.ComboFlags.HeightChubby, function()
    for i = 0, ac.getCar(ac.getSim().focusedCar).carCamerasCount - 1 do
      if ui.selectable(string.format("Camera %d", i)) then
        ac.setCurrentCamera(ac.CameraMode.Car)
        ac.setCurrentCarCamera(i)
      end
    end
  end)
  ui.header('Camera Track:')
  ui.combo('##Track', string.format("Camera %d", ac.getSim().trackCamerasSet), ui.ComboFlags.HeightLargest, function()
    for i = 0, ac.getSim().trackCamerasSetsCount - 1 do
      if ui.selectable(string.format("Camera %d", i)) then
        ac.setCurrentCamera(ac.CameraMode.Track)
        ac.setCurrentTrackCamera(i)
      end
    end
  end)
  ui.newLine()
  ui.separator()
  local btntext = 'Random Camera Off'
  if randomTimerOn then
    btntext = 'Random Camera On'
  end
  if ui.button(btntext, ui.ButtonFlags.Active) then
    randomTimerOn = not randomTimerOn
    if randomTimerOn then
      randomCamera()
      setTimer()
    else
      clearInterval(timerKey)
    end
  end
  local newScale = ui.slider('##TimerSlider', randomTimer, 10, 120, 'Timer: %1.0f%')
  if ui.itemEdited() then
    randomTimer = newScale
    setTimer()
  end
  if ac.getSim().cameraMode == ac.CameraMode.OnBoardFree then
    local orbit = ac.getSim().orbitOnboardCamera
    local str = 'Orbit'
    if orbit then str = 'Face' end
    if ui.button(str, ui.ButtonFlags.Active) then
      ac.setOrbitOnboardCamera(not orbit)
    end
    ui.header('You can control camera:')
    ui.text(' -  Left click and move')

    if orbit then
      ui.text(' -  middle for change FOV')
    else
      ui.text(' -  Right click center car view')
      ui.text(' -  Arrow key change angle')
    end
  end

  if ac.getSim().cameraMode == ac.CameraMode.Free then
    ui.header('You can control camera:')
    ui.text(' -  Right click change angle')
    ui.text(' -  Page Up/Down move Up/Down')
    ui.text(' -  Arrow Keys move Camera')
    ui.text(' *  Shift and arrow for slow move')
    ui.text(' *  Control and arrow for fast move')
  end
  ui.endGroup()

  ui.newLine(1)
  ui.separator()
  ui.header("Options for spectators, your car is teleported\ninto the pits at the start of the session")
  if ui.checkbox("Auto Teleport To Pits on start session", TeleportToPits) then
    TeleportToPits = not TeleportToPits
  end
end

function script.onShowWindowMain(dt)
  visible = true
end

function script.onHideWindowMain(dt)
  visible = false
end
