--
-- Created by Wile64 on jun 2024
--

local sf = string.format
local visible = false
local gasData = {}
local brakeData = {}
local updateInterval = 0.1 -- Intervalle de mise à jour en secondes
local timeSinceLastUpdate = 0
local graphWidth = 300
local graphHeight = 100

---comment
---@param progress number
---@param rectSize vec2
---@param color rgbm
local function progressBarV(progress, rectSize, color)
  local startPosition = ui.getCursor()
  if progress == nil then progress = 0 end
  local progressBarFilledSize = vec2(rectSize.x, rectSize.y * progress)

  ui.drawRect(startPosition, startPosition + rectSize, rgbm.colors.gray)
  startPosition.y = startPosition.y + (rectSize.y - progressBarFilledSize.y)
  ui.drawRectFilled(startPosition, startPosition + progressBarFilledSize, color)
  ui.dummy(rectSize + 1)
end

function script.windowMain(dt)
  local drawOffset = ui.getCursor()
  local contentSize = ui.windowSize():sub(drawOffset)
  display.rect({ pos = drawOffset, size = contentSize, color = rgbm(0.1, 0.1, 0.1, 0.8) })

  progressBarV(brakeData[#brakeData], vec2(15, graphHeight), rgbm(1, 0, 0, 1))
  ui.sameLine()
  progressBarV(gasData[#gasData], vec2(15, graphHeight), rgbm(0, 1, 0, 1))
  ui.sameLine()
  local function drawGraph(data, color)
    local startPosition = ui.getCursor()
    local maxData = math.min(#data, graphWidth)
    ui.drawRect(startPosition, startPosition + vec2(graphWidth + 1, graphHeight + 1), rgbm.colors.gray)
    for i = 2, maxData do
      local x1 = startPosition.x + (i - 1)
      local y1 = startPosition.y + (graphHeight-1) - (data[#data - maxData + i - 1] * (graphHeight-2))
      local x2 = startPosition.x + i
      local y2 = startPosition.y + (graphHeight-1) - (data[#data - maxData + i] * (graphHeight-2))
      ui.drawLine(vec2(x1, y1), vec2(x2, y2), color, 2)
    end
  end

  -- Dessine les graphiques
  drawGraph(gasData, rgbm(0, 1, 0, 1))   -- Vert pour l'accélérateur
  drawGraph(brakeData, rgbm(1, 0, 0, 1)) -- Rouge pour le frein
  ui.dummy(vec2(graphWidth + 1, graphHeight + 1))
end

function script.onShowWindowMain(dt)
  visible = true
end

function script.onHideWindowMain(dt)
  visible = false
end

function script.update(dt)
  if not visible then return end
  local carstate = ac.getCar(ac.getSim().focusedCar)
  if carstate == nil then return end
  timeSinceLastUpdate = timeSinceLastUpdate + dt
  if timeSinceLastUpdate >= updateInterval then
    table.insert(gasData, carstate.gas)
    table.insert(brakeData, carstate.brake)
    -- Limite la taille des tableaux pour éviter des performances dégradées
    if #gasData > graphWidth then
      table.remove(gasData, 1)
      table.remove(brakeData, 1)
    end
    -- Réinitialise le temps écoulé
    timeSinceLastUpdate = 0
  end
end
