--
-- Created by Wile64 on may 2025
--

local AppConfig = ac.storage {
  size = 200,
  gamma = 1,
  whitePoint = 1.5
}

local showDialog = false

local function mirrorSettings(i)
  local p, c = ac.getRealMirrorParams(i - 1), true

  if ac.getPatchVersionCode() >= 3359 and p.notDrivenByUser then
    ui.pushFont(ui.Font.Main)
    ui.text('This mirror is controlled by something else and can’t be edited.')
    ui.popFont()
    return
  end
  ui.beginGroup()
  ui.setNextItemWidth(ui.availableSpaceX())
  p.rotation.x = ui.slider('##rotationX', p.rotation.x * 100, -60, 60, 'Rotation X: %.1f%%') / 100
  ui.setNextItemWidth(ui.availableSpaceX())
  p.rotation.y = ui.slider('##rotationY', p.rotation.y * 100, -60, 60, 'Rotation Y: %.1f%%') / 100
  ui.setNextItemWidth(ui.availableSpaceX())
  p.fov = ui.slider('##fov', p.fov, 2, 60, 'FOV: %.2f°', 2)
  ui.endGroup()
  if c or ui.itemEdited() then
    ac.setRealMirrorParams(i - 1, p)
  end
end

local function mouseInWindow()
  return ui.mousePos() > ui.windowPos() and ui.mousePos() < ui.windowPos() + ui.windowSize()
end

function script.windowMain(dt)
  local cameraValide = ac.getSim().cameraMode == 2 or ac.getSim().cameraMode == 0
  if cameraValide then
    local sizeX = AppConfig.size
    local cur = ui.getCursor()
    local size = vec2(sizeX, sizeX * 0.25)

    ui.beginTonemapping()
    if not ui.drawVirtualMirror(cur, cur + size, rgbm(1, 1, 1, 1)) then
      ui.text("No virtual mirror currently available.")
    else
      ui.dummy(size)
    end
    ui.endTonemapping(AppConfig.gamma, AppConfig.whitePoint, true)
  end
  ui.sameLine()

  if ac.getRealMirrorCount() < 1 then
    return
  end

  if ui.mouseClicked(ui.MouseButton.Middle) and mouseInWindow() then
    showDialog = not showDialog
  end
  if showDialog then
    ui.beginTransparentWindow("test", ui.windowPos() + vec2(ui.windowSize().x, 0), vec2(200, 160), true,
      ui.WindowFlags.AlwaysAutoResize)
    local contentSize = ui.windowSize()
    ui.drawRectFilled(ui.getCursor(), ui.getCursor() + contentSize, rgbm(0.2, 0.2, 0.2, 1), 15,
      ui.CornerFlags.TopRight + ui.CornerFlags.BottomRight)
    ui.pushFont(ui.Font.Title)
    ui.textColored('Mirrors:', rgbm.colors.cyan)
    ui.popFont()
    ui.tabBar('mirrors', ui.TabBarFlags.None, function()
      for i = 1, ac.getRealMirrorCount() do
        ui.tabItem(string.format('%d', i), function()
          mirrorSettings(i)
        end)
      end
    end)
    ui.endTransparentWindow()
  end
end

function script.windowSetting(dt)
  AppConfig.size = ui.slider('##SizeSlider', AppConfig.size, 200.0, 1000.0, 'Size: %1.f%')
  ui.separator()
  AppConfig.gamma = ui.slider('##GammaSlider', AppConfig.gamma, 0.5, 3.0, 'Gamma: %.2f%')

  AppConfig.whitePoint = ui.slider('##whitePointSlider', AppConfig.whitePoint, 0.5, 3.0, 'whitePoint: %.2f%')
end
