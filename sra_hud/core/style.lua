local Style = {}

local themeModules = {
  purple = 'core.theme.purple',
  orange = 'core.theme.orange',
  ice = 'core.theme.ice',
}

local themeNames = { 'default', 'purple', 'orange', 'ice' }
local loadedThemes = {}

local function cloneValue(value)
  if rgbm.isrgbm(value) then
    return rgbm(value.r, value.g, value.b, value.mult)
  end
  if type(value) ~= 'table' then
    return value
  end

  local result = {}
  for k, v in pairs(value) do
    result[k] = cloneValue(v)
  end
  return result
end

local defaultColors = {
  background = rgbm(0.15, 0.15, 0.15, 0.90),
  backgroundAlt = rgbm(0.08, 0.08, 0.08, 0.88),
  border = rgbm(1.00, 1.00, 1.00, 1.00),
  label = rgbm(1.00, 1.00, 1.00, 0.80),
  valueNeutral = rgbm(1.00, 1.00, 1.00, 0.80),
  valueStatic = rgbm(0.78, 0.90, 1.00, 1.00),
  valueEdit = rgbm(1.00, 0.86, 0.52, 1.00),
  valuePositive = rgbm(0.25, 1.00, 0.55, 1.00),
  valueNegative = rgbm(1.00, 0.45, 0.45, 1.00),
  valueBestTime = rgbm(0.72, 0.42, 1.00, 1.00),
  rowStripe = rgbm(1.00, 1.00, 1.00, 0.05),
  gaugeBackground = rgbm(1.00, 1.00, 1.00, 0.08),
  pageDot = rgbm(1.00, 1.00, 1.00, 0.30),
  selection = rgbm(0.95, 0.78, 0.30, 0.22),
  surfaceLight = rgbm(1.00, 1.00, 1.00, 1.00),
  textOnLight = rgbm(0.00, 0.00, 0.00, 1.00),
  transparent = rgbm(0.00, 0.00, 0.00, 0.00),
}

local sharedTheme = {
  setup = {
    section = rgbm(0.96, 0.83, 0.52, 1.00),
  },
  delta = {
    green = rgbm(0.25, 1.00, 0.55, 1.00),
    red = rgbm(1.00, 0.40, 0.40, 1.00),
    purple = rgbm(0.72, 0.42, 1.00, 1.00),
    off = rgbm(0.35, 0.35, 0.35, 1.00),
  },
  rpm = {
    low = rgbm(0.25, 1.00, 0.55, 1.00),
    mid = rgbm(1.00, 0.95, 0.55, 1.00),
    high = rgbm(1.00, 0.40, 0.40, 1.00),
  },
  speed = {
    shiftAlert = rgbm(1.00, 0.40, 0.40, 1.00),
  },
  flags = {
    clear = { bg = rgbm(0.00, 0.00, 0.00, 0.00), text = rgbm(1.00, 1.00, 1.00, 1.00) },
    green = { bg = rgbm(0.00, 1.00, 0.00, 1.00), text = rgbm(1.00, 1.00, 1.00, 1.00) },
    yellow = { bg = rgbm(1.00, 1.00, 0.00, 1.00), text = rgbm(0.00, 0.00, 0.00, 1.00) },
    aqua = { bg = rgbm(0.00, 1.00, 1.00, 1.00), text = rgbm(0.00, 0.00, 0.00, 1.00) },
    black = { bg = rgbm(0.00, 0.00, 0.00, 1.00), text = rgbm(1.00, 1.00, 1.00, 1.00) },
    red = { bg = rgbm(1.00, 0.00, 0.00, 1.00), text = rgbm(1.00, 1.00, 1.00, 1.00) },
    blue = { bg = rgbm(0.00, 0.00, 1.00, 1.00), text = rgbm(1.00, 1.00, 1.00, 1.00) },
    gray = { bg = rgbm(0.50, 0.50, 0.50, 1.00), text = rgbm(1.00, 1.00, 1.00, 1.00) },
    white = { bg = rgbm(1.00, 1.00, 1.00, 1.00), text = rgbm(0.00, 0.00, 0.00, 1.00) },
  },
  tyres = {
    tempCold = rgbm(0.28, 0.62, 0.96, 1.00),
    tempIdeal = rgbm(0.30, 0.86, 0.38, 1.00),
    tempHot = rgbm(0.98, 0.30, 0.26, 1.00),
    tempUnknown = rgbm(0.72, 0.74, 0.78, 1.00),
    slip = rgbm(1.00, 0.62, 0.22, 1.00),
    wearGood = rgbm(0.30, 0.80, 0.30, 1.00),
    wearWarn = rgbm(0.90, 0.90, 0.30, 1.00),
    wearBad = rgbm(1.00, 0.30, 0.30, 1.00),
    wearOutline = rgbm(0.50, 1.00, 1.00, 1.00),
  },
  fuel = {
    safe = rgbm(0.25, 1.00, 0.55, 1.00),
    warning = rgbm(1.00, 0.95, 0.55, 1.00),
    critical = rgbm(1.00, 0.40, 0.40, 1.00),
  },
  damage = {
    blown = rgbm(0.10, 0.10, 0.10, 0.60),
    ok = rgbm(0.25, 1.00, 0.55, 1.00),
    bad = rgbm(1.00, 0.40, 0.40, 1.00),
    repair = rgbm(1.00, 0.40, 0.40, 1.00),
  },
  led = {
    off = rgbm(0.35, 0.35, 0.35, 1.00),
    available = rgbm(0.25, 1.00, 0.55, 1.00),
    alert = rgbm(1.00, 0.40, 0.40, 1.00),
  },
  gforce = {
    dot = rgbm(1.00, 0.62, 0.22, 1.00),
  },
  pedals = {
    clutch = rgbm(0.25, 0.70, 1.00, 1.00),
    brake = rgbm(1.00, 0.28, 0.28, 1.00),
    throttle = rgbm(0.25, 1.00, 0.40, 1.00),
  },
}

local function buildTheme(overrideColors)
  local theme = cloneValue(sharedTheme)
  theme.colors = cloneValue(overrideColors or defaultColors)
  return theme
end

function Style.getDefaultColors()
  return cloneValue(defaultColors)
end

function Style.getTheme(name)
  local themeName = themeModules[name] and name or 'default'

  if not loadedThemes[themeName] then
    if themeName == 'default' then
      loadedThemes[themeName] = buildTheme(defaultColors)
    else
      local moduleName = themeModules[themeName]
      package.loaded[moduleName] = nil
      local colors = require(moduleName)
      loadedThemes[themeName] = buildTheme(colors)
    end
  end

  return loadedThemes[themeName]
end

function Style.reset()
  loadedThemes = {}
end

function Style.getThemeNames()
  return themeNames
end

return Style
