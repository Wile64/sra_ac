--
-- Created by Wile64 on october 2023
--

DEBUG = false
STATE = {
    Enabled = 0,
    Disabled = 1
}

Label = class('Label')
function Label:initialize(size, title, value, scale, color) -- constructor
    self.scale = scale
    self.baseSize = size
    self.rectSize = size * self.scale
    self.rectColor = color
    self.state = STATE.Enabled
    self.title = title
    self.value = value
    self.initialized = false
    self.bgColor = nil
    self.disabledColor = rgbm.colors.gray
end

function Label:rezise()
    self.rectSize = self.baseSize * self.scale

    self.rectStart = ui.getCursor()
    self.rectEnd = self.rectStart + (self.rectSize * self.scale)
    self.rectRound = 3

    self.titleStart = vec2(self.rectStart.x + 2, self.rectStart.y + 1)
    self.titleSize = 10.5 * self.scale
    self.titleColor = rgbm.colors.white

    self.valueStart = self.rectStart + 2
    self.valueEnd = self.valueStart + (vec2(self.rectSize.x - 3, self.rectSize.y - 1 + (self.scale * 2.5)))
    self.valueSize = self.rectSize.y / 1.30
    self.valueColor = rgbm.colors.white

    self.progress = 0
    self.progressColor = rgbm.colors.gray
    self.rectProgress = vec2(0, 0)
    self.initialized = true
end

function Label:setScale(scale)
    self.scale = scale
    self.initialized = false
    --self:resize()
end

function Label:setBgColor(color)
    self.bgColor = color
end

function Label:setColor(color)
    self.valueColor = color
end

function Label:disable()
    self.state = STATE.Disabled
    self:setBgColor(nil)
end

function Label:enable()
    self.state = STATE.Enabled
end

function Label:draw(value)
    if not self.initialized then self:rezise() end

    self.value = value

    if self.progress > 0 then
        ui.drawRectFilled(self.rectStart, self.rectStart + self.rectProgress, self.progressColor, self.rectRound)
    end
    if self.bgColor then
        ui.drawRectFilled(self.rectStart, self.rectStart + self.rectSize, self.bgColor, self.rectRound)
    end
    ui.drawRect(self.rectStart, self.rectStart + self.rectSize, self.rectColor, self.rectRound)
    if self.state == STATE.Enabled then
        ui.dwriteDrawText(self.title, self.titleSize, self.titleStart, self.titleColor)
    else
        ui.dwriteDrawText(self.title, self.titleSize, self.titleStart, self.disabledColor)
    end
    if DEBUG then
        ui.drawRect(self.valueStart, self.valueEnd, rgbm.colors.red)
    end
    if self.state == STATE.Enabled then
        ui.dwriteDrawTextClipped(self.value, self.valueSize, self.valueStart, self.valueEnd, ui.Alignment.End,
            ui.Alignment.End, false, self.valueColor)
    else
        ui.dwriteDrawTextClipped(self.value, self.valueSize, self.valueStart, self.valueEnd, ui.Alignment.End,
            ui.Alignment.End, false, self.disabledColor)
    end

    ui.dummy(self.rectSize + 1)
end

function Label:setProgress(progress, color)
    if self.progress ~= progress then
        self.progress = math.min(math.max(progress, 0), 1)
        self.progressColor = color
        self.rectProgress = vec2((self.rectSize.x * self.progress), self.rectSize.y)
    end
end
