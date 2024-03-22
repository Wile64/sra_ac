--
-- Created by Wile64 on october 2023
--

-- https://github.com/ac-custom-shaders-patch/acc-lua-sdk/blob/main/.definitions/ac_common.txt

local randomTimer = 5.0
local randomTimerOn = false
local timerKey = 0
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
  ac.log(string.format("current %d max %d", camera, #viewList))
  ac.log(string.format("cam %d vue %d", viewList[camera][2][1], viewList[camera][2][2]))

  if viewList[camera][2][2] == -1 then
    ac.setCurrentCamera(viewList[camera][2][1])
  else
    ac.setCurrentCamera(viewList[camera][2][1])
    ac.setCurrentCarCamera(viewList[camera][2][2])
  end
end

local function setimer()
  clearInterval(timerKey)
  timerKey = setInterval(function() if randomTimerOn then randomCamera() end end, randomTimer, '#timer')
end
function script.windowMain(dt)
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

  local car = ac.getCar(ac.getSim().focusedCar)
  ui.columns(2, false, '#col')

  ui.header('Drivers:')
  ui.combo('##Drivers', ac.getDriverName(ac.getSim().focusedCar), ui.ComboFlags.HeightChubby, function()
    for i = 0, ac.getSim().carsCount - 1 do
      if ui.selectable(ac.getDriverName(i)) then
        ac.focusCar(i)
      end
    end
  end)
  ui.header('Focused:')
  drawKeyValue("- Driver Name: ", ac.getDriverName(ac.getSim().focusedCar))
  drawKeyValue("- Driver Number: ", string.format("%d", ac.getDriverNumber(ac.getSim().focusedCar)))
  drawKeyValue("- Driver country: ", string.format("%s", ac.getDriverNationality(ac.getSim().focusedCar)))
  drawKeyValue("- Driver Team: ", string.format("%s", ac.getDriverTeam(ac.getSim().focusedCar)))
  drawKeyValue("- Driver Position: ", string.format("%d", car.racePosition))
  drawKeyValue("- Car Name: ", string.format("%s", ac.getCarName(ac.getSim().focusedCar)))
  drawKeyValue("- Car Brand: ", string.format("%s", ac.getCarBrand(ac.getSim().focusedCar)))
  drawKeyValue("- Car Country: ", string.format("%s", ac.getCarCountry(ac.getSim().focusedCar)))
  ui.newLine()
  local btntext = 'Random Camera Off'
  if randomTimerOn then
    btntext = 'Random Camera On'
  end
  if ui.button(btntext, ui.ButtonFlags.Active) then
    randomTimerOn = not randomTimerOn
    if randomTimerOn then
      randomCamera()
      setimer()
    else
      clearInterval(timerKey)
    end
  end
  local newScale = ui.slider('##TimerSlider', randomTimer, 2.0, 60.0, 'Timer: %1.1f%')
  if ui.itemEdited() then
    randomTimer = newScale
    setimer()
  end
  ui.nextColumn()

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
end

function script.onShowWindowMain(dt)
  visible = true
end

function script.onHideWindowMain(dt)
  visible = false
end
