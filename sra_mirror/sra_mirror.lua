--
-- Created by Wile64 on may 2025
--

local AppConfig = ac.storage {
  size = 200,
  gamma = 1,
  whitePoint = 1.5
}

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
end

function script.windowSetting(dt)
  AppConfig.size = ui.slider('##SizeSlider', AppConfig.size, 200.0, 1000.0, 'Size: %1.f%')
  ui.separator()
  AppConfig.gamma = ui.slider('##GammaSlider', AppConfig.gamma, 0.5, 3.0, 'Gamma: %.2f%')

  AppConfig.whitePoint = ui.slider('##whitePointSlider', AppConfig.whitePoint, 0.5, 3.0, 'whitePoint: %.2f%')
end
