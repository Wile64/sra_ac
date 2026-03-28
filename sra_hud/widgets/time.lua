local TimeWidget = {}
TimeWidget.__index = TimeWidget

local InfoCards = require('core.info_cards')

function TimeWidget:new()
  return setmetatable({
    id = 'time',
    title = 'Time',
    windowId = 'windowTime',
    localTime = '--:--:--',
    serverTime = '--:--:--',
  }, self)
end

function TimeWidget:update(dt, context)
  local sim = context.sim
  self.localTime = os.date('%X')
  self.serverTime = sim and os.date('!%X', sim.timestamp) or '--:--:--'
end

function TimeWidget:draw(dt, drawContext)
  local scale = (drawContext.scale or 1) * (drawContext.timeScale or 1)
  local colors = drawContext.colors
  local font = drawContext.font
  local width = 120 * scale
  local cardSize = vec2(width, 28 * scale)
  local accent = colors.valueNeutral

  ui.pushDWriteFont(font.police)
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(4 * scale, 4 * scale))
  InfoCards.drawLabelValueCard('Local', self.localTime, cardSize, font, colors, accent, scale)
  ui.sameLine()
  InfoCards.drawLabelValueCard('Server', self.serverTime, cardSize, font, colors, accent, scale)
  ui.popStyleVar()
  ui.popDWriteFont()
end

return TimeWidget
