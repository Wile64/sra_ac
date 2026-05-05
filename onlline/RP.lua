--
-- Created by Wile64 on april 2026
--
VERSION = 1.0

--[[
[SCRIPT_...]
SCRIPT = RP.lua
REQUIRED = 1

[RP]
ENABLED = 1
RUNTITLE = "Be careful and drive in lines"
RUNSUBTITLE = "Do not exceed 180 KM/H"

BLACKFLAGSTART = 0.78
BLACKTITLE = "Take the %s side"
BLACKSUBTITLE = "SLOW DOWN TO 80 KM/H"

REDFLAGSTART = 0.92
REDTITLE = "PIT LIMITER ON"
REDSUBTITLE = "START IS IMMINENT"

SHOWAFTERREDSEC = 2
SHOWTOPGATE = 1
SHOWROADGATE = 1
SHOWAHEADMARKER = 1
]]

--- Option de configurations
local enabled                 = 1

local runTitle                = "Be careful and drive in lines"
local runSubtitle             = "Do not exceed 180 KM/H"

local blackFlagStart          = 0.78
local blackTitle              = "Take the %s side"
local blackSubtitle           = "SLOW DOWN TO 80 KM/H"

local redFlagStart            = 0.92
local redTitle                = "PIT LIMITER ON"
local redSubtitle             = "START IS IMMINENT"

local showAfterRedSec         = 2
local showTopGate             = 1
local showRoadGate            = 1
local showAheadMarker         = 1

----------------------
local ZONE_BANNER_HEIGHT_M    = 5.1
local ZONE_BANNER_THICKNESS_M = 0.35
local ROAD_GATE_LENGTH_M      = 3.0
local TITLE_TEXT              = rgbm(0.95, 0.97, 0.99, 1)
local SUBTITLE_TEXT           = rgbm(1, 1, 1, 1)
local RECT_COLOR              = rgbm(0.00, 0.0, 15.0, 0.5)
local AHEAD_COLOR             = rgbm(0.00, 15.0, 0.0, 0.4)

local formationState          = {
  phase = "idle",
  titleMessage = "",
  subtitleMessage = "",
  lastLapCount = 0,
  aheadCar = nil,
}

-- Screen resolution
local screen                  = ac.getSim().windowSize
-- Scale for UI
local scale                   = screen.y / 1080
-- Default font size
local fontSize                = 35 * scale
local runwaySide              = 'unknow'
local raceStarted             = false
local isInitialized           = false

local function resetState()
  raceStarted                    = false
  runwaySide                     = 'unknow'
  formationState.phase           = "idle"
  formationState.titleMessage    = ""
  formationState.subtitleMessage = ""
  formationState.lastLapCount    = 0
  formationState.aheadCar        = nil
  isInitialized                  = false
  ac.log("resetState")
end

local function wrap01(v)
  if v < 0 then
    return v + 1
  end
  if v >= 1 then
    return v - 1
  end
  return v
end

local function getTrackBasis(progress)
  local prevPos = ac.trackProgressToWorldCoordinate(wrap01(progress - 0.001), true)
  local nextPos = ac.trackProgressToWorldCoordinate(wrap01(progress + 0.001), true)
  local centerPos = ac.trackProgressToWorldCoordinate(progress, true)
  local tangent = nextPos - prevPos
  tangent.y = 0
  local tangentLen = math.sqrt(tangent.x * tangent.x + tangent.z * tangent.z)

  if tangentLen < 0.001 then
    tangent = vec3(0, 0, 1)
  else
    tangent = tangent / tangentLen
  end

  local right = vec3(-tangent.z, 0, tangent.x)
  return centerPos, tangent, right
end

local function projectToTrack(pos)
  local hit = vec3()
  local castFrom = pos + vec3(0, 5, 0)
  local castDistance = physics.raycastTrack(castFrom, vec3(0, -1, 0), 20, hit)
  if castDistance >= 0 then
    return hit + vec3(0, 0.09, 0)
  end
  return pos + vec3(0, 0.09, 0)
end

local function drawZoneGate(progress, color)
  local splinePos, tangent, right = getTrackBasis(progress)
  local sides = ac.getTrackAISplineSides(progress)

  local leftBase = projectToTrack(splinePos - right * sides.x)
  local rightBase = projectToTrack(splinePos + right * sides.y)

  local gateHeight = ZONE_BANNER_HEIGHT_M
  local gateThickness = math.max(1.0, ZONE_BANNER_THICKNESS_M * 4.0)
  local up = vec3(0, 1, 0)

  local leftBottom = leftBase + up * (gateHeight - gateThickness * 0.5)
  local rightBottom = rightBase + up * (gateHeight - gateThickness * 0.5)
  local leftTop = leftBase + up * (gateHeight + gateThickness * 0.5)
  local rightTop = rightBase + up * (gateHeight + gateThickness * 0.5)

  render.setBlendMode(1)
  render.setDepthMode(0)
  render.quad(leftBottom, leftTop, rightTop, rightBottom, color)
  render.setBlendMode(4)
  render.setDepthMode(4)
end

local function midpoint(a, b)
  return (a + b) * 0.5
end

local function getSegmentSidePoints(progress)
  local splineCenter, _, right = getTrackBasis(progress)
  local sides = ac.getTrackAISplineSides(progress)
  local leftSide = sides and sides.x or 0.5
  local rightSide = sides and sides.y or 0.5
  local leftEdge = splineCenter - right * leftSide
  local rightEdge = splineCenter + right * rightSide
  local trackCenter = midpoint(leftEdge, rightEdge)
  local outerEdge = runwaySide == "left"
      and (leftEdge + right * 0.2)
      or (rightEdge - right * 0.5)
  local innerEdge = outerEdge + (trackCenter - outerEdge) * 0.8
  return projectToTrack(outerEdge), projectToTrack(innerEdge)
end

local function drawTrackRectangles(car)
  local sim = ac.getSim()
  local trackLength = sim.trackLengthM or 0
  if car == nil or trackLength <= 0 then
    return
  end

  local startProgress = wrap01((car.splinePosition or 0) + 6.0 / trackLength)
  local stepLength = math.max(0.5, 3.0 + 0.6)
  local segmentLength = math.max(0.5, 2.5)
  local segmentsCount = math.max(1, math.floor(15 / stepLength))
  local stepProgress = stepLength / trackLength
  local segmentProgress = segmentLength / trackLength


  for i = 0, segmentsCount do
    local progressA = wrap01(startProgress + i * stepProgress)
    local progressB = wrap01(progressA + segmentProgress)
    local outerA, innerA = getSegmentSidePoints(progressA)
    local outerB, innerB = getSegmentSidePoints(progressB)
    render.setBlendMode(1)
    render.setDepthMode(0)
    render.quad(outerA, outerB, innerB, innerA, RECT_COLOR)
    render.setBlendMode(4)
    render.setDepthMode(4)
  end
end

local function drawGateRect(progress, color)
  local trackLength = ac.getSim().trackLengthM or 0
  if trackLength <= 0 then
    return
  end

  local halfSpan = (ROAD_GATE_LENGTH_M * 0.5) / trackLength
  local progressA = wrap01(progress - halfSpan)
  local progressB = wrap01(progress + halfSpan)
  local splineA, _, rightA = getTrackBasis(progressA)
  local splineB, _, rightB = getTrackBasis(progressB)
  local sidesA = ac.getTrackAISplineSides(progressA)
  local sidesB = ac.getTrackAISplineSides(progressB)

  local leftA = projectToTrack(splineA - rightA * (sidesA and sidesA.x or 0.5))
  local rightAEdge = projectToTrack(splineA + rightA * (sidesA and sidesA.y or 0.5))
  local leftB = projectToTrack(splineB - rightB * (sidesB and sidesB.x or 0.5))
  local rightBEdge = projectToTrack(splineB + rightB * (sidesB and sidesB.y or 0.5))

  render.setBlendMode(1)
  render.setDepthMode(0)
  render.quad(leftA, leftB, rightBEdge, rightAEdge, color)
  render.setBlendMode(4)
  render.setDepthMode(4)
end

local function getRaceDistanceM(car, trackLength)
  if (car.drivenInRace or 0) > 0 then
    return car.drivenInRace
  end
  return (car.lapCount or 0) * trackLength + (car.splinePosition or 0) * trackLength
end

local function getAheadCarGapM(player, aheadCar, trackLength)
  local gap = getRaceDistanceM(aheadCar, trackLength) - getRaceDistanceM(player, trackLength)
  while gap <= 0 do
    gap = gap + trackLength
  end
  return gap
end

local function findAheadCar(player)
  local sim = ac.getSim()
  local playerDistance = getRaceDistanceM(player, sim.trackLengthM)
  local bestGap = math.huge
  local bestCar = nil

  for i = 0, sim.carsCount - 1 do
    if i ~= player.index then
      local other = ac.getCar(i)
      if other ~= nil
          and other.isConnected
          and other.isActive
          and not other.isRetired
          and not other.isInPit
          and not other.isInPitlane then
        local gap = getRaceDistanceM(other, sim.trackLengthM) - playerDistance
        while gap <= 0 do
          gap = gap + sim.trackLengthM
        end
        if gap > 1 and gap < bestGap and gap <= 250 then
          bestGap = gap
          bestCar = other
        end
      end
    end
  end

  return bestCar
end

local function drawAheadMarker(player)
  if showAheadMarker == 0 then
    return
  end

  local sim = ac.getSim()
  local trackLength = sim.trackLengthM or 0
  if player == nil or trackLength <= 0 then
    return
  end

  if formationState.aheadCar == nil then
    return
  end
  local gapM = getAheadCarGapM(player, formationState.aheadCar, trackLength)

  local progress = formationState.aheadCar.splinePosition
  --or wrap01((player.splinePosition or 0) + AppConfig.lookAheadM / trackLength)

  local outerPoint, innerPoint = getSegmentSidePoints(progress)
  local panelBase = midpoint(outerPoint, innerPoint)
  local up = vec3(0, 1, 0)
  local lateral = innerPoint - outerPoint
  local lateralLen = math.sqrt(lateral.x * lateral.x + lateral.y * lateral.y + lateral.z * lateral.z)
  if lateralLen < 0.001 then
    return
  end
  local lateralDir = lateral / lateralLen
  local halfWidth = lateralLen * 0.5
  local bottomCenter = panelBase

  local bottomLeft = bottomCenter - lateralDir * halfWidth
  local bottomRight = bottomCenter + lateralDir * halfWidth
  local height = 1
  local topLeft = bottomLeft + up * height
  local topRight = bottomRight + up * height
  render.setBlendMode(1)
  render.setDepthMode(0)
  render.quad(bottomLeft, topLeft, topRight, bottomRight, AHEAD_COLOR)
  render.setBlendMode(4)
  render.setDepthMode(4)
end

function script.draw3D(dt)
  if enabled == 0 or formationState.phase == "hidden" then
    return
  end
  if showTopGate == 1 then
    drawZoneGate(blackFlagStart, rgbm(0.1, 0.10, 0.10, 1))
    drawZoneGate(redFlagStart, rgbm(1, 0.10, 0.10, 1))
  end
  if showRoadGate == 1 then
    drawGateRect(blackFlagStart, rgbm(0.05, 0.05, 0.05, 0.85))
    drawGateRect(redFlagStart, rgbm(1.0, 0.10, 0.10, 0.85))
  end
  if formationState.phase == 'black' or formationState.phase == 'red' then
    local car = ac.getCar(0)
    drawTrackRectangles(car)
    drawAheadMarker(car)
  end
end

local function drawCenterMessage()
  local effectivePhase = formationState.phase
  if effectivePhase == "idle" then
    return
  end
  local blockHeight = 90 * scale
  local topY = (ui.windowSize().y - blockHeight) * 0.5
  local middleScreen = ui.windowSize().x * 0.5
  local title = formationState.titleMessage
  local subtitle = formationState.subtitleMessage
  ui.pushDWriteFont('@System;Weight=Bold')
  local textSize = ui.measureDWriteText(title, fontSize)
  ui.dwriteDrawText(title, fontSize, vec2(middleScreen - (textSize.x * 0.5), topY - textSize.y), TITLE_TEXT)

  textSize = ui.measureDWriteText(subtitle, fontSize)
  ui.dwriteDrawText(subtitle, fontSize, vec2(middleScreen - (textSize.x * 0.5), topY + textSize.y), SUBTITLE_TEXT)
  ui.popDWriteFont()
end

function script.drawUI()
  if enabled == 0 or formationState.phase == "hidden" then
    return
  end
  drawCenterMessage()
end

local function crossedThreshold(progress, threshold)
  return threshold <= progress
end

local function detectCarSide(car)
  local splinePos, _, right = getTrackBasis(car.splinePosition)
  local sides = ac.getTrackAISplineSides(car.splinePosition)
  local leftEdge = splinePos - right * (sides and sides.x or 0.5)
  local rightEdge = splinePos + right * (sides and sides.y or 0.5)
  local trackCenter = (leftEdge + rightEdge) * 0.5

  local offset = car.position - trackCenter
  local lateral = offset.x * right.x + offset.z * right.z

  if lateral > 0 then
    return "right"
  elseif lateral < 0 then
    return "left"
  end

  return "left"
end

local function initialize(car)
  ac.log("initialize")

  runwaySide = detectCarSide(car)

  -- Starting from the pits, do nothing
  if car.isInPitlane or car.isInPit then
    ac.log("phase = hidden pit")
    formationState.phase = "hidden"
  end
  formationState.aheadCar = findAheadCar(car)
  isInitialized = true
end

local function updateFormationState(car)
  local progress = car.splinePosition
  local simTime = ac.getSim().gameTime
  local phase = formationState.phase
  if phase == 'idle' then
    return
  end
  if phase == 'run' then
    if crossedThreshold(progress, blackFlagStart) then
      ac.log("phase = black")
      formationState.phase = "black"
      formationState.titleMessage = string.format(blackTitle, runwaySide)
      formationState.subtitleMessage = blackSubtitle
      formationState.lastLapCount = car.lapCount
      return
    end
  end
  if phase == 'black' then
    if crossedThreshold(progress, redFlagStart) then
      ac.log("phase = red")
      formationState.phase = "red"
      formationState.titleMessage = redTitle
      formationState.subtitleMessage = redSubtitle
      formationState.lastLapCount = car.lapCount
      formationState.redTriggeredAt = simTime
      return
    end
  end
  if phase == 'red' and simTime - formationState.redTriggeredAt > showAfterRedSec then
    ac.log("phase = hidden")
    formationState.phase = "hidden"
    formationState.titleMessage = ""
    formationState.subtitleMessage = ""
    formationState.lastLapCount = car.lapCount
    return
  end
end

local function isRacestarted(sim)
  local timeToStart = sim.timeToSessionStart or 0
  if timeToStart > 0 then
    return false
  end
  return true
end

function script.update(dt)
  ac.debug("isInitialized", isInitialized)
  ac.debug("raceStarted", raceStarted)
  ac.debug("runwaySide", runwaySide)
  ac.debug("phase", formationState.phase)
  if enabled == 0 or formationState.phase == "hidden" then
    return
  end

  local sim = ac.getSim()
  if sim.isPaused or sim.isInMainMenu then
    return
  end

  ac.debug("timeToSessionStart ", tostring(sim.timeToSessionStart))


  -- Exit if not online and not race
  if sim.raceSessionType ~= ac.SessionType.Race then
    return
  end

  local car = ac.getCar(0)
  if car == nil then
    return
  end

  raceStarted = isRacestarted(sim)

  if raceStarted and not isInitialized then
    ac.log("Race Started")
    initialize(car)
  end

  if not isInitialized then
    return
  end
  -- Check if the car crossed start line
  if car.splinePosition < 0.001 and formationState.phase == "idle" then
    ac.log("phase = run")
    formationState.phase = "run"
    formationState.titleMessage = runTitle
    formationState.subtitleMessage = runSubtitle
  end

  if raceStarted then
    if car.isInPitlane or car.isInPit then
      ac.log("phase = hidden pit")
      formationState.phase = "hidden"
    end
    updateFormationState(car)
  end
end

ac.onOnlineWelcome(function(message, config) --Reads the script config from the extra options
  ac.log("onOnlineWelcome")
  resetState()
  enabled = config:get("RP", "ENEBLED", 1)
  runTitle = config:get("RP", "RUNTITLE", "Be careful and drive in lines")
  runSubtitle = config:get("RP", "RUNSUBTITLE", "Do not exceed 180 KM/H")

  blackFlagStart = config:get("RP", "BLACKFLAGSTART", 0.78)
  blackTitle = config:get("RP", "BLACKTITLE", "Take the %s side")
  blackSubtitle = config:get("RP", "BLACKSUBTITLE", "SLOW DOWN TO 80 KM/H")

  redFlagStart = config:get("RP", "REDFLAGSTART", 0.92)
  redTitle = config:get("RP", "REDTITLE", "PIT LIMITER ON")
  redSubtitle = config:get("RP", "REDSUBTITLE", "START IS IMMINENT")

  showAfterRedSec = config:get("RP", "SHOWAFTERREDSEC", 2)
  showTopGate = config:get("RP", "SHOWTOPGATE", 1)
  showRoadGate = config:get("RP", "SHOWROADGATE", 1)
  showAheadMarker = config:get("RP", "SHOWAHEADMARKER", 1)
end)

ac.onSessionStart(function(sessionIndex, restarted)
  ac.log("onSessionStart " .. tostring(restarted))
  resetState()
end)
