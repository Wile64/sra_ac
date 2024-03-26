require('classes/setup')

VERSION = 0.99

local dirSetup = ac.getFolder(ac.FolderID.UserSetups)
local carName = ac.getCarID(0)
local trackName = ac.getTrackID()

local carSetup = CarSetup()
local fileSetup = CarSetup()
local defaultSetup = CarSetup()
local CurrentSetupFile = ''

defaultSetup:GetCurrentSetup()

FONTSIZE = 12

local function listFilesInDirectory(directory)
  local command = 'dir "' .. directory .. '" /b'
  local file = io.popen(command)
  local fileList = {}
  for filename in file:lines() do
    if filename:match("%.ini$") then
      table.insert(fileList, filename)
    end
  end
  file:close()
  return fileList
end

local files = listFilesInDirectory(dirSetup .. '\\' .. carName .. '\\' .. trackName)

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
            ui.dwriteText(string.format('%s', k), FONTSIZE, rgbm.colors.white)
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
            ui.sameLine()
            if ui.arrowButton('def' .. k, ui.Direction.Right, vec2(15, 15), ui.ButtonFlags.Active) then
              carSetup:applySetupValue(k, defaultSetup:getValue(k))
            end
            ui.nextColumn()
          end
        end
      end
    end
  end
  ui.popDWriteFont()
end
