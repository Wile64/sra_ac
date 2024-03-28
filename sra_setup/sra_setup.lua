require('classes/setup')

VERSION = 0.991
FONTSIZE = 12

local dirSetup = ac.getFolder(ac.FolderID.UserSetups)
local carName = ac.getCarID(0)
local trackName = ac.getTrackID()

local carSetup = CarSetup()
local fileSetup = CarSetup()
local defaultSetup = CarSetup()
local CurrentSetupFile = ''

defaultSetup:GetCurrentSetup()

local knownNames = {
  ['FUEL'] = 'Fuel',
  ['BRAKE_POWER_MULT'] = 'Brake power',
  ['ENGINE_LIMITER'] = 'Engine limiter',
  ['FRONT_BIAS'] = 'Brake bias',
  ['FINAL_RATIO'] = 'Final gear ratio',
  ['GEARSET'] = 'Gear set',
  ['ARB_FRONT'] = 'ARB (front)',
  ['ARB_REAR'] = 'ARB (rear)',
  ['PRESSURE_LF'] = 'Tyre pressure (left front)',
  ['PRESSURE_LR'] = 'Tyre pressure (left rear)',
  ['PRESSURE_RF'] = 'Tyre pressure (right front)',
  ['PRESSURE_RR'] = 'Tyre pressure (right rear)',
  ['ROD_LENGTH_LR'] = 'Suspension height (left rear)',
  ['ROD_LENGTH_LF'] = 'Suspension height (left front)',
  ['ROD_LENGTH_RF'] = 'Suspension height (right front)',
  ['ROD_LENGTH_RR'] = 'Suspension height (right rear)',
  ['SPRING_RATE_LF'] = 'Suspension wheel rate (left front)',
  ['SPRING_RATE_LR'] = 'Suspension wheel rate (left rear)',
  ['SPRING_RATE_RF'] = 'Suspension wheel rate (right front)',
  ['SPRING_RATE_RR'] = 'Suspension wheel rate (right rear)',
  ['TOE_OUT_LF'] = 'Toe (left front)',
  ['TOE_OUT_LR'] = 'Toe (left rear)',
  ['TOE_OUT_RF'] = 'Toe (right front)',
  ['TOE_OUT_RR'] = 'Toe (right rear)',
  ['CAMBER_LF'] = 'Camber (left front)',
  ['CAMBER_LR'] = 'Camber (left rear)',
  ['CAMBER_RF'] = 'Camber (right front)',
  ['CAMBER_RR'] = 'Camber (right rear)',
  ['INTERNAL_GEAR_2'] = 'First gear',
  ['INTERNAL_GEAR_3'] = 'Second gear',
  ['INTERNAL_GEAR_4'] = 'Third gear',
  ['INTERNAL_GEAR_5'] = 'Fourth gear',
  ['INTERNAL_GEAR_6'] = 'Fifth gear',
  ['INTERNAL_GEAR_7'] = 'Sixth gear',
  ['TRACTION_CONTROL'] = 'Traction control',
  ['PACKER_RANGE_LF'] = 'Travel range (left front)',
  ['PACKER_RANGE_LR'] = 'Travel range (left rear)',
  ['PACKER_RANGE_RF'] = 'Travel range (right front)',
  ['PACKER_RANGE_RR'] = 'Travel range (right rear)',
}

local function pairsByKeys(t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0             -- iterator variable
  local iter = function() -- iterator function
    i = i + 1
    if a[i] == nil then
      return nil
    else
      return a[i], t[a[i]]
    end
  end
  return iter
end

function script.windowMain(dt)
  ui.pushDWriteFont('Segoe UI;Weight=Bold')
  ac.setWindowTitle('windowMain', string.format('SRA Setup v%2.3f', VERSION))
  ui.dwriteText(string.format('SRA Setup v%2.3f', VERSION), FONTSIZE, rgbm.colors.white)
  ui.separator()
  ui.newLine()

  if ui.button('Reset to default setup', ui.ButtonFlags.Active) then
    ac.resetSetupToDefault(dirSetup .. '\\' .. carName)
  end



  if ui.button('load Setup File', ui.ButtonFlags.Active) then
    os.openFileDialog({
      title = 'Open Setup',
      folder = dirSetup .. '\\' .. carName .. '\\' .. trackName,
      fileTypes = { { name = 'Setup file', mask = '*.ini' } },
    }, function(err, filename)
      if not err and filename then
        CurrentSetupFile = string.gsub(filename, dirSetup .. '\\' .. carName .. '\\' .. trackName .. '\\', "")
        fileSetup:LoadFromFile(filename)
      end
    end)
  end
  ui.sameLine()
  ui.dwriteText(string.format('File: %s', CurrentSetupFile), FONTSIZE, rgbm.colors.white)

  if fileSetup.isLoaded then
    if ui.button('Apply File Setup', ui.ButtonFlags.Active) then
      ac.loadSetup(dirSetup .. '\\' .. carName .. '\\' .. trackName .. '\\' .. CurrentSetupFile)
    end
    ui.sameLine()
    if ui.button('Unload setup file', ui.ButtonFlags.Active) then
      CurrentSetupFile = ''
      fileSetup:reset()
    end
    ui.newLine()
    carSetup:GetCurrentSetup()
    ui.columns(4)
    ui.dwriteText('Items', FONTSIZE, rgbm.colors.yellow)
    ui.nextColumn()
    ui.dwriteText('File Setup', FONTSIZE, rgbm.colors.yellow)
    ui.nextColumn()
    ui.dwriteText('Current Setup', FONTSIZE, rgbm.colors.yellow)
    ui.nextColumn()
    ui.dwriteText('Default Setup', FONTSIZE, rgbm.colors.yellow)
    ui.nextColumn()
    local list = fileSetup:getValueList()
    if list ~= false then
      for k, v in pairsByKeys(list) do
        if carSetup:getValue(k) ~= false then
          if carSetup:getValue(k) ~= v then
            ui.dwriteText(string.format('%s', knownNames[k] or k), FONTSIZE, rgbm.colors.white)
            ui.nextColumn()
            ui.dwriteText(string.format('%02d ', v), FONTSIZE, rgbm.colors.fuchsia)
            ui.sameLine()
            if ui.arrowButton('cur' .. k, ui.Direction.Right, vec2(15, 15), ui.ButtonFlags.Active) then
              carSetup:applySetupValue(k, v)
            end
            if ui.itemHovered() then
              ui.setTooltip('Fixe value (not work for all)')
            end
            ui.nextColumn()
            ui.dwriteText(string.format('%02d', carSetup:getValue(k)), FONTSIZE, rgbm.colors.red)
            ui.nextColumn()
            ui.dwriteText(string.format('%02d', defaultSetup:getValue(k)), FONTSIZE, rgbm.colors.white)
            if defaultSetup:getValue(k) ~= carSetup:getValue(k) then
              ui.sameLine()
              if ui.arrowButton('def' .. k, ui.Direction.Right, vec2(15, 15), ui.ButtonFlags.Active) then
                carSetup:applySetupValue(k, defaultSetup:getValue(k))
              end
            end
            ui.nextColumn()
          end
        end
      end
    end
  end
  ui.popDWriteFont()
end
