local sf = string.format
local InfoCards = require('core.info_cards')

local sessionNames = {
    'Undefined',
    'Practice',
    'Qualify',
    'Race',
    'Hotlap',
    'TimeAttack',
    'Drift',
    'Drag',
}

local function getFlagColors(style)
    local flags = style.flags
    return {
        [ac.FlagType.None] = { bg = flags.clear.bg, text = flags.clear.text, label = 'CLEAR' },
        [ac.FlagType.Start] = { bg = flags.green.bg, text = flags.green.text, label = 'START' },
        [ac.FlagType.Caution] = { bg = flags.yellow.bg, text = flags.yellow.text, label = 'CAUTION' },
        [ac.FlagType.Slippery] = { bg = flags.aqua.bg, text = flags.aqua.text, label = 'SLIPPERY' },
        [ac.FlagType.PitLaneClosed] = { bg = flags.aqua.bg, text = flags.aqua.text, label = 'PIT CLOSED' },
        [ac.FlagType.Stop] = { bg = flags.black.bg, text = flags.black.text, label = 'STOP' },
        [ac.FlagType.SlowVehicle] = { bg = flags.yellow.bg, text = flags.yellow.text, label = 'SLOW' },
        [ac.FlagType.Ambulance] = { bg = flags.red.bg, text = flags.red.text, label = 'AMBULANCE' },
        [ac.FlagType.ReturnToPits] = { bg = flags.red.bg, text = flags.red.text, label = 'RETURN' },
        [ac.FlagType.MechanicalFailure] = { bg = flags.aqua.bg, text = flags.aqua.text, label = 'MECHANICAL' },
        [ac.FlagType.Unsportsmanlike] = { bg = flags.aqua.bg, text = flags.aqua.text, label = 'UNSPORTSMAN' },
        [ac.FlagType.StopCancel] = { bg = flags.aqua.bg, text = flags.aqua.text, label = 'CANCEL' },
        [ac.FlagType.FasterCar] = { bg = flags.blue.bg, text = flags.blue.text, label = 'BLUE' },
        [ac.FlagType.Finished] = { bg = flags.gray.bg, text = flags.gray.text, label = 'FINISHED' },
        [ac.FlagType.OneLapLeft] = { bg = flags.white.bg, text = flags.white.text, label = 'FINAL LAP' },
        [ac.FlagType.SessionSuspended] = { bg = flags.aqua.bg, text = flags.aqua.text, label = 'SUSPENDED' },
        [ac.FlagType.Code60] = { bg = flags.aqua.bg, text = flags.aqua.text, label = 'CODE 60' },
    }
end

local function formatSessionTime(sessionTimeLeft)
    if sessionTimeLeft <= 0 then
        return 'Overtime'
    end

    return tostring(os.date('!%X', sessionTimeLeft / 1000))
end

local PositionWidget = {}
PositionWidget.__index = PositionWidget

function PositionWidget:new()
    return setmetatable({
        id = 'position',
        title = 'Position',
        windowId = 'windowPosition',
        racePosition = 0,
        lapCount = 0,
        isTimedSession = false,
        sessionTimeLeftMs = 0,
        sessionName = '',
        flagType = 0,
    }, self)
end

function PositionWidget:update(dt, context)
    local car = context.car
    local sim = context.sim
    if not car or not sim then
        return
    end

    self.racePosition = car.racePosition
    self.lapCount = car.lapCount
    self.isTimedSession = (sim.raceSessionType == ac.SessionType.Race and sim.isTimedRace)
        or (sim.raceSessionType ~= ac.SessionType.Race and sim.isOnlineRace)
    self.sessionTimeLeftMs = sim.sessionTimeLeft
    self.sessionName = sessionNames[sim.raceSessionType + 1] or 'Session'
    self.flagType = sim.raceFlagType
end

function PositionWidget:draw(dt, drawContext)
    local scale = (drawContext.scale or 1) * (drawContext.positionScale or 1)
    local colors = drawContext.colors
    local style = drawContext.style
    local font = drawContext.font

    local accentPosition = colors.textOnLight
    local accentMeta = colors.valueNeutral
    local flagColors = getFlagColors(style)
    local flag = flagColors[self.flagType] or flagColors[0]

    local width = 180 * scale
    local leftWidth = 68 * scale
    local rightWidth = width - leftWidth - 4 * scale
    local heroSize = vec2(leftWidth, 62 * scale)
    local smallSize = vec2(rightWidth, (heroSize.y - 4 * scale) / 2)
    local statusSize = vec2(width, 22 * scale)

    ui.pushDWriteFont(font.police)
    ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(4 * scale, 4 * scale))

    local pos = ui.getCursor()
    ui.drawRectFilled(pos, pos + heroSize, colors.surfaceLight, 10 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)
    ui.drawRect(pos, pos + heroSize, colors.border, 10 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft, 1)
    ui.dwriteDrawTextClipped(sf('%02d', self.racePosition), font.size * 3.2 * scale, pos + vec2(6 * scale, 0),
        pos + vec2(heroSize.x - 8 * scale, heroSize.y), ui.Alignment.Center, ui.Alignment.Center, false,
        accentPosition)
    ui.dummy(heroSize)

    ui.sameLine()
    ui.beginGroup()
    InfoCards.drawValueCard(self.sessionName, smallSize, font, colors, accentMeta, scale)
    InfoCards.drawValueCard(sf('Lap %d', self.lapCount), smallSize, font, colors, accentMeta, scale)
    ui.endGroup()

    pos = ui.getCursor()
    ui.drawRectFilled(pos, pos + statusSize, flag.bg, 8 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft)
    ui.drawRect(pos, pos + statusSize, colors.border, 8 * scale, ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft, 1)

    local showSessionTime = self.isTimedSession and self.flagType == ac.FlagType.None
    local statusText = flag.label
    if showSessionTime then
        statusText = formatSessionTime(self.sessionTimeLeftMs)
    end

    ui.dwriteDrawTextClipped(statusText, font.size * scale, pos + vec2(8 * scale, 0),
        pos + vec2(statusSize.x - 8 * scale, statusSize.y),
        ui.Alignment.Center, ui.Alignment.Center, false, showSessionTime and colors.valueNeutral or flag.text)
    ui.dummy(statusSize)

    ui.popStyleVar()
    ui.popDWriteFont()
end

return PositionWidget
