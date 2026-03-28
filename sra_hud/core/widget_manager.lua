local WidgetManager = {}
WidgetManager.__index = WidgetManager

function WidgetManager:new()
  return setmetatable({
    widgets = {},
    order = {},
  }, self)
end

function WidgetManager:register(widget)
  self.widgets[widget.id] = {
    instance = widget,
    windowVisible = false,
  }
  self.order[#self.order + 1] = widget.id
end

function WidgetManager:get(id)
  local entry = self.widgets[id]
  return entry and entry.instance or nil
end

function WidgetManager:setWindowVisible(id, visible)
  local entry = self.widgets[id]
  if not entry then
    return
  end

  entry.windowVisible = visible and true or false
end

function WidgetManager:isWindowVisible(id)
  local entry = self.widgets[id]
  return entry ~= nil and entry.windowVisible or false
end

function WidgetManager:update(dt, context)
  for _, id in ipairs(self.order) do
    local entry = self.widgets[id]
    local widget = entry.instance

    if entry.windowVisible and widget.update then
      widget:update(dt, context)
    end
  end
end

function WidgetManager:draw(id, dt, drawContext)
  local entry = self.widgets[id]
  if not entry then
    ui.text('Widget introuvable')
    return
  end

  if not entry.windowVisible then
    return
  end

  local widget = entry.instance
  if widget.draw then
    widget:draw(dt, drawContext)
  end
end

return WidgetManager
