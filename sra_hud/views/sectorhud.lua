---comment
---@param text string
local function drawSector(text)
  local pos = ui.getCursor()
  local lenght = 80
  local size = vec2(lenght, 25) * SETTING.sectorHUD.scale
  local fontSize = 20 * SETTING.sectorHUD.scale
  ui.drawRectFilled(pos, pos + size, SETTING.styleColor, 10 * SETTING.sectorHUD.scale)
  ui.dwriteTextAligned(text, fontSize, ui.Alignment.Center, ui.Alignment.Center, size, false, SETTING.fontColor)
end

function script.sectorHUD(dt)
  ui.pushDWriteFont('OneSlot:/fonts;Weight=Bold')
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, 1)

  local simState = ac.getSim()
  local sectorCount = #simState.lapSplits
  local sectorTime = 0
  for i = 0, sectorCount - 1 do
    ui.sameLine()
    ui.beginGroup()
    if SETTING.sectorHUD.showCurrent then
      if CAR.carState.currentSplits[i] then
        --add past sector to itme
        sectorTime = sectorTime + CAR.carState.currentSplits[i]
      end
      if CAR.carState.currentSector == i then
        -- Current sector progress
        drawSector(ac.lapTimeToString(CAR.carState.lapTimeMs - sectorTime))
        if ui.itemHovered() then ui.setTooltip("Current sector " .. tostring(i + 1)) end
      else
        local currentSplits = CAR.carState.currentSplits[i] or 0
        drawSector(ac.lapTimeToString(currentSplits))
        if ui.itemHovered() then ui.setTooltip("Current sector " .. tostring(i + 1)) end
      end
    end
    if SETTING.sectorHUD.showLast then
      local lastSplits = CAR.carState.lastSplits[i] or 0
      drawSector(ac.lapTimeToString(lastSplits))
      if ui.itemHovered() then ui.setTooltip("Last sector " .. tostring(i + 1)) end
    end
    if SETTING.sectorHUD.showBest then
      local bestSplits = CAR.carState.bestSplits[i] or 0
      drawSector(ac.lapTimeToString(bestSplits))
      if ui.itemHovered() then ui.setTooltip("Best sector " .. tostring(i + 1)) end
    end
    ui.endGroup()
  end
  ui.popStyleVar()
  ui.popDWriteFont()
end
