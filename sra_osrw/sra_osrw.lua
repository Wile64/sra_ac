--
-- Created by Wile64 on october 2023
--

function script.windowMain(dt)
  ui.columns(2, false, nil)

  if ui.button("Formation lap") then
    ac.sendChatMessage("!Formation lap")
  end
  ui.nextColumn()
  if ui.button("start 5 secondes") then
    ac.sendChatMessage("!start 5 secondes")
  end
  ui.nextColumn()
  if ui.button("Lancement Standing") then
    ac.sendChatMessage("scss")
  end
  ui.nextColumn()
  ui.nextColumn()
  if ui.button("sortie safety") then
    ac.sendChatMessage("scon")
  end
  ui.nextColumn()
  if ui.button("SC IN THIS LAP") then
    ac.sendChatMessage("!SC IN THIS LAP")
  end
  ui.nextColumn()
  if ui.button("Fin Safety") then
    ac.sendChatMessage("scoff")
  end
  ui.nextColumn()
  ui.nextColumn()
  if ui.button("Fin les drapeaux") then
    ac.sendChatMessage("clearflags")
  end
  ui.nextColumn()
  ui.nextColumn()
  if ui.button("Virtual sc on") then
    ac.sendChatMessage("vscon")
  end
  ui.nextColumn()
  if ui.button("Virtual sc off") then
    ac.sendChatMessage("vscoff")
  end
  ui.nextColumn()
  if ui.button("START UNLAPPING PROCEDURE") then
    ac.sendChatMessage("!START UNLAPPING PROCEDURE")
  end
  ui.nextColumn()
  if ui.button("END UNLAPPING PROCEDURE") then
    ac.sendChatMessage("!END UNLAPPING PROCEDURE")
  end
end
