local InfoCards = {}

local DEFAULT_CORNERS = ui.CornerFlags.BottomRight + ui.CornerFlags.TopLeft

local function drawCardFrame(size, colors, scale, opts)
  local pos = ui.getCursor()
  local radius = (opts.radius or 8) * scale
  local corners = opts.cornerFlags or DEFAULT_CORNERS
  local borderWidth = opts.borderWidth or 1

  ui.drawRectFilled(pos, pos + size, colors.background, radius, corners)
  ui.drawRect(pos, pos + size, colors.border, radius, corners, borderWidth)

  return pos
end

function InfoCards.drawValueCard(value, size, font, colors, accent, scale, opts)
  opts = opts or {}

  local pos = drawCardFrame(size, colors, scale, opts)
  local padding = (opts.padding or 8) * scale
  local valueFontScale = opts.valueFontScale or 1

  ui.dwriteDrawTextClipped(
    value,
    font.size * valueFontScale * scale,
    pos + vec2(padding, 0),
    pos + vec2(size.x - padding, size.y),
    opts.valueAlignX or ui.Alignment.Center,
    opts.valueAlignY or ui.Alignment.Center,
    false,
    accent
  )

  ui.dummy(size)
end

function InfoCards.drawLabelValueCard(label, value, size, font, colors, accent, scale, opts)
  opts = opts or {}

  local pos = drawCardFrame(size, colors, scale, opts)
  local padding = (opts.padding or 8) * scale
  local labelWidthRatio = opts.labelWidthRatio or 0.42
  local labelFontScale = opts.labelFontScale or 0.7
  local labelColor = opts.labelColor or colors.label
  local splitX = size.x * labelWidthRatio

  ui.dwriteDrawTextClipped(
    label,
    font.size * labelFontScale * scale,
    pos + vec2(padding, 0),
    pos + vec2(splitX, size.y),
    opts.labelAlignX or ui.Alignment.Start,
    opts.labelAlignY or ui.Alignment.Center,
    false,
    labelColor
  )

  ui.dwriteDrawTextClipped(
    value,
    font.size * (opts.valueFontScale or 1) * scale,
    pos + vec2(splitX, 0),
    pos + vec2(size.x - padding, size.y),
    opts.valueAlignX or ui.Alignment.End,
    opts.valueAlignY or ui.Alignment.Center,
    false,
    accent
  )

  ui.dummy(size)
end

return InfoCards
