--
-- Created by Wile64 on october 2023
--

-- https://github.com/ac-custom-shaders-patch/acc-lua-sdk/blob/main/.definitions/ac_common.txt

require('classes/carsra')
require('views/chronohud')
require('views/timehud')
require('views/ledhud')
require('views/poshud')
require('views/sectorhud')
require('views/weatherhud')
require('classes/settings')

CAR = CarSRA()
SETTING = Settings()

function script.windowSetup(dt)
  SETTING.scale = ui.slider('##Scale', SETTING.scale, 1.0, 3.0, 'Scale: %1.1f')
  if ui.colorButton('##StyleColor', SETTING.styleColor, ui.ColorPickerFlags.AlphaBar + ui.ColorPickerFlags.PickerHueBar) then
    SETTING.styleColor = SETTING.styleColor
  end
  ui.sameLine()
  ui.text('Style Color')

  if ui.colorButton('backgroundColor##', SETTING.fontColor, ui.ColorPickerFlags.NoAlpha + ui.ColorPickerFlags.PickerHueBar) then
    SETTING.fontColor = SETTING.fontColor
  end
  ui.sameLine()
  ui.text('Font Color')

  ui.separator()
  ui.setCursorX(210)
  if ui.iconButton(ui.Icons.Save, vec2(50, 0), 0, true, ui.ButtonFlags.Activable) then
    SETTING:save()
  end
end

function script.update(dt)
  CAR:setFocusedCar()
  CAR:update(dt)
end
