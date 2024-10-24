--
-- Created by Wile64 on April 2024
--

local AppConfig = ac.storage {
  Password = "",
  Ballast = 0,
  Restrictor = 0
}

local selection = {
  Selected = nil,
  SessionID = nil,
  ViewPassword = false
}

function script.windowMain(dt)
  local isAdmin = ac.getSim().isAdmin
  local isOnline = ac.getSim().isOnlineRace
  if not isOnline then
    ui.text('Only work in online!')
    return
  end
  ui.dwriteText('Set your admin password in setting!', 12, rgbm(1, 0, 0, 1))
  if ui.button("Set Admin") then
    ac.sendChatMessage(string.format("/admin %s", AppConfig.Password))
    ac.checkAdminPrivileges()
  end
  ui.newLine()
  if not isAdmin then
    ui.text('You need admin privileges!')
    return
  end
  if ui.button("Next session") then
    ac.sendChatMessage("/next_session")
  end
  ui.sameLine(130)
  if ui.button("Restart session") then
    ac.sendChatMessage("/restart_session")
  end
  ui.sameLine(260)
  if ui.button("Next weather") then
    ac.sendChatMessage("/next_weather")
  end
  ui.newLine()
  ui.separator()
  ui.text('Drivers:')
  local driverName = 'Select Driver First'
  if selection.Selected then
    driverName = ac.getDriverName(selection['Selected']) or "Unknown"
  end
  ui.combo('##Drivers', driverName, ui.ComboFlags.HeightChubby, function()
    for i = 0, ac.getSim().carsCount - 1 do
      if ac.getCar(i).isConnected then
        driverName = ac.getDriverName(i) or "Unknown"
        if driverName then
          if ui.selectable(driverName, false, ui.SelectableFlags.None) then
            selection.Selected = i
            selection.SessionID = ac.getCar(i).sessionID
          end
        end
      end
    end
  end)
  local ButonStatus = ui.ButtonFlags.Active
  if selection.SessionID == nil then
    ButonStatus = ui.ButtonFlags.Disabled
  end
  ui.newLine()
  if ui.button("kick", ButonStatus) then
    if selection.Selected then
      ac.sendChatMessage(string.format('/kick %d', selection.SessionID))
      selection.Selected  = nil
      selection.SessionID = nil
    end
  end
  ui.sameLine(130)
  if ui.button("Force kick", ButonStatus) then
    if selection.Selected then
      ac.sendChatMessage(string.format('/force_kick %d', selection.SessionID))
      selection.Selected  = nil
      selection.SessionID = nil
    end
  end
  ui.sameLine(260)
  if ui.button("Ban", ButonStatus) then
    if selection.Selected then
      ac.sendChatMessage(string.format('/ban %d', selection.SessionID))
      selection.Selected  = nil
      selection.SessionID = nil
    end
  end
  ui.newLine()
  if ui.button("Ballast", ButonStatus) then
    if selection.Selected then
      ac.sendChatMessage(string.format('/ballast %d %d', selection.SessionID, AppConfig.Ballast))
      selection.Selected = nil
      selection.SessionID = nil
    end
  end
  ui.sameLine(100)
  local newBallast = ui.slider('##Ballast', AppConfig.Ballast, 0.0, 5000.0, 'Ballast: %1.0f   Kg')
  if ui.itemEdited() then
    AppConfig.Ballast = newBallast
  end

  ui.sameLine(340)
  if ui.button("Ballast all") then
    for i = 0, ac.getSim().carsCount - 1 do
      if ac.getCar(i).isActive then
        selection.SessionID = ac.getCar(i).sessionID
        ac.sendChatMessage(string.format('/ballast %d %d', selection.SessionID, AppConfig.Ballast))
      end
    end
  end

  if ui.button("Restrictor", ButonStatus) then
    if selection.Selected then
      ac.sendChatMessage(string.format('/restrictor %d %d', selection.SessionID, AppConfig.Restrictor))
      selection.Selected  = nil
      selection.SessionID = nil
    end
  end

  ui.sameLine(100)
  local newRestrictor = ui.slider('##Restrictor', AppConfig.Restrictor, 0.0, 400.0, 'Restrictor: %1.0f %%')
  if ui.itemEdited() then
    AppConfig.Restrictor = newRestrictor
  end
  ui.sameLine(340)
  if ui.button("Restrict all") then
    for i = 0, ac.getSim().carsCount - 1 do
      if ac.getCar(i).isActive then
        selection.SessionID = ac.getCar(i).sessionID
        ac.sendChatMessage(string.format('/restrictor %d %d', selection.SessionID, AppConfig.Restrictor))
      end
    end
  end
  ui.separator()
  ui.newLine()
  if ui.button("Hide Driver", ButonStatus) then
    if selection.Selected then
      ac.setDriverVisible(selection.Selected, false)
    end
  end
  ui.sameLine()
  if ui.button("Show Driver", ButonStatus) then
    if selection.Selected then
      ac.setDriverVisible(selection.Selected, true)
    end
  end
  ui.sameLine()
  if ui.button("Open driver door", ButonStatus) then
    if selection.Selected then
      ac.setDriverDoorOpen(selection.Selected, true, false)
    end
  end
  ui.sameLine()
  if ui.button("Close driver door", ButonStatus) then
    if selection.Selected then
      ac.setDriverDoorOpen(selection.Selected, false, false)
    end
  end
end

function script.windowSetting(dt)
  ui.text("Set Admin Password:")
  local options = ui.InputTextFlags.CharsNoBlank
  if selection.ViewPassword then
    options = options and ui.InputTextFlags.Password
  end
  AppConfig.Password = ui.inputText("##Password", AppConfig.Password,
    options)
  ui.sameLine()
  if ui.iconButton(ui.Icons.Eye, 20, 0, true, ui.ButtonFlags.Activable) then
    selection.ViewPassword = not selection.ViewPassword
  end
end
