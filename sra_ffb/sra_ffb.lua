--
-- Created by Wile64 on jun 2024
--

local sf = string.format
local visible = false
local FinalData = {}
local updateInterval = 0.1 -- Intervalle de mise à jour en secondes
local timeSinceLastUpdate = 0
local graphWidth = 300
local graphHeight = 100
local car = ac.getCar(0) or error()
local data = {
  FinalMax = 0,
  PureMax = 0,
}

local function carFFB()
  local currentFFB = car.ffbMultiplier
  if ui.button('##ffbMinus', vec2(20, 20), ui.ButtonFlags.PressedOnClick and ui.ButtonFlags.Repeat) then
    if currentFFB > 0 then
      currentFFB = car.ffbMultiplier - 0.01
      ac.setFFBMultiplier(currentFFB)
      data.FinalMax = 0
    end
  end
  ui.addIcon(ui.Icons.Minus, 10, 0.5, nil, 0)
  ui.sameLine()
  ui.text(string.format("Car FFB gain %.2f%%", currentFFB * 100))
  ui.sameLine()
  if ui.button('##ffbPlus', vec2(20, 20), ui.ButtonFlags.PressedOnClick and ui.ButtonFlags.Repeat) then
    if currentFFB < 1.99 then
      currentFFB = car.ffbMultiplier + 0.01
      ac.setFFBMultiplier(currentFFB)
      data.FinalMax = 0
    end
  end
  ui.addIcon(ui.Icons.Plus, 10, 0.5, nil, 0)
end

function script.windowMain(dt)
  local drawOffset = ui.getCursor()
  local contentSize = ui.windowSize():sub(drawOffset)
  display.rect({ pos = drawOffset, size = contentSize, color = rgbm(0.1, 0.1, 0.1, 0.8) })

  ui.text(string.format("FFB %2.2f %%", car.ffbFinal * 100))
  if data.FinalMax < car.ffbFinal * 100 then
    data.FinalMax = car.ffbFinal * 100
  end
  ui.text(string.format("FFB Max %2.2f %%", data.FinalMax))
  ui.sameLine()
  if ui.button('##ffbReset', vec2(20, 20), changed and ui.ButtonFlags.None) then
    data.FinalMax = 0
  end
  ui.addIcon(ui.Icons.Restart, 10, 0.5, nil, 0)
  carFFB()
  ui.separator()
  ui.newLine()

  local function drawGraph(data, color)
    local startPosition = ui.getCursor()
    local maxData = math.min(#data, graphWidth)
    ui.drawRect(startPosition, startPosition + vec2(graphWidth + 1, graphHeight + 1), rgbm.colors.gray)
    for i = 2, maxData do
      local x1 = startPosition.x + (i - 1)
      local y1 = startPosition.y + (graphHeight - 1) - (data[#data - maxData + i - 1] * (graphHeight - 2))
      local x2 = startPosition.x + i
      local y2 = startPosition.y + (graphHeight - 1) - (data[#data - maxData + i] * (graphHeight - 2))
      if (y1 <= startPosition.y) or (y2 <= startPosition.y) then
        color = rgbm(1, 0, 0, 1)
      else
        color = rgbm(0, 1, 0, 1)
      end
      ui.drawLine(vec2(x1, y1), vec2(x2, y2), color, 2)
    end
  end

  -- Dessine les graphiques
  drawGraph(FinalData, rgbm(0, 1, 0, 1)) -- Vert pour l'accélérateur
  ui.dummy(vec2(graphWidth + 1, graphHeight + 1))
end

function script.onShowWindowMain(dt)
  visible = true
end

function script.onHideWindowMain(dt)
  visible = false
end

function script.update(dt)
  if visible == false then return end
  local carstate = ac.getCar(ac.getSim().focusedCar)
  if carstate == nil then return end
  timeSinceLastUpdate = timeSinceLastUpdate + dt
  if timeSinceLastUpdate >= updateInterval then
    table.insert(FinalData, math.min(math.abs(carstate.ffbFinal), 200))
    -- Limite la taille des tableaux pour éviter des performances dégradées
    if #FinalData > graphWidth then
      table.remove(FinalData, 1)
    end
    -- Réinitialise le temps écoulé
    timeSinceLastUpdate = 0
  end
end
