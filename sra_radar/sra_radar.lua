--
-- Created by Wile64 on october 2024
--
-- update to Version 1.1 - 28/04/2025
--      Optimize some code
--      Disabled on replay
--      Add option show red sonar
--      Add radar range option (tips ACFever)
--      Add car proximity range option (tips ACFever)
--      Remove background completly (tips ACFever)
--      Change icon
--      Resizing circles according to proximity range
--      Add text in setting for sh
--      Changing the color of the circles depending on proximity
--      Added Central circle pulse animation
--      Added text in settings to display circle distance

-- update to Version 1.2 - 23/02/2026
--      Optimize hot-path allocations and math in windowMain
--      Remove unused visible state and show/hide handlers
--      Cache AppConfig flags locally in frame update
--      Add setup preview to keep radar visible without nearby cars
--      Add setup preview overlays for blind-spot side detection zones

VERSION = 1.2

local AppConfig = ac.storage {
    voice = true,
    voiceRepeat = 5,
    volume = 1,
    showPosition = true,
    showLine = true,
    showCircle = true,
    showSonar = true,
    range = 25,
    proximityDistance = 7
}

local gameVolume = ac.getAudioVolume(ac.AudioChannel.Main) or 1
local finalVolume = gameVolume  * AppConfig.volume

local carOnLeftSound = ui.MediaPlayer('sound/car-on-left.wav'):setVolume(finalVolume):setAutoPlay(false)
local carOnRightSound = ui.MediaPlayer('sound/car-on-right.wav'):setVolume(finalVolume):setAutoPlay(false)

-- Configuration du radar
local radarSize = 200 -- taille de la fenêtre du radar en pixels
local WINDOWS_HEADER = vec2(0, 22)
local settingsPreviewUntil = -math.huge

-- Temps du dernier son joué
local lastRightSoundTime = -math.huge -- Initialisé avec une valeur très basse
local lastLeftSoundTime = -math.huge

--- Vérifier si le son peut être rejoué après X secondes
---@param lastPlayedTime number
---@param currentTime number
---@return boolean
local function canPlaySound(lastPlayedTime, currentTime)
    return currentTime - lastPlayedTime >= AppConfig.voiceRepeat
end

---@param screen_pos vec2
---@param car_size vec2
---@param size number
---@param side string
---@return number, number, number, number
local function getSideBounds(screen_pos, car_size, size, side)
    local halfX = car_size.x * 0.5
    local halfY = car_size.y * 0.5
    local minX, maxX
    if side == 'right' then
        minX = screen_pos.x + halfX
        maxX = screen_pos.x + halfX * 2 + size
    else -- left
        minX = screen_pos.x - (halfX * 2 + size)
        maxX = screen_pos.x - halfX
    end
    local minY = screen_pos.y - halfY
    local maxY = screen_pos.y + halfY * 2
    return minX, maxX, minY, maxY
end

---Détection de la voiture sur la gauche ou droite
---@param position vec2
---@param screen_pos vec2
---@param car_size vec2
---@param size number
---@param side string
---@return boolean
local function isCarOnSide(position, screen_pos, car_size, size, side)
    local minX, maxX, minY, maxY = getSideBounds(screen_pos, car_size, size, side)
    return position.x >= minX and position.x <= maxX and position.y >= minY and position.y <= maxY
end

---@param screen_pos vec2
---@param car_size vec2
---@param size number
---@param side string
---@param color rgbm
local function drawSideZone(screen_pos, car_size, size, side, color)
    local minX, maxX, minY, maxY = getSideBounds(screen_pos, car_size, size, side)
    ui.drawRectFilled(vec2(minX, minY), vec2(maxX, maxY), color, 2)
end

--- Fonction pour dessiner un rectangle représentant une voiture
---@param screen_pos vec2
---@param car_size vec2
---@param color rgbm
---@param position string?
---@param showPosition boolean
local function drawCar(screen_pos, car_size, color, position, showPosition)
    local halfCarSize = car_size / 2
    -- Dessiner le rectangle de la voiture
    ui.drawRectFilled(
        screen_pos - halfCarSize, -- Position haut-gauche du rectangle
        screen_pos + halfCarSize, -- Position bas-droite du rectangle
        color,                    -- Couleur avec alpha (transparence)
        5                         -- Pas de bord arrondi
    )
    -- Afficher la position si l'option est activée
    if showPosition and position ~= nil then
        ui.dwriteDrawTextClipped(position,
            car_size.y / 3,
            screen_pos - halfCarSize,
            screen_pos + halfCarSize,
            ui.Alignment.Center,
            ui.Alignment.Center,
            false,
            rgbm(0.1, 0.1, 0.1, color.mult))
    end
end

--- Fonction pour dessiner un arc de cercle rempli
---@param center vec2
---@param direction vec2
---@param radius number
---@param angle number
---@param segments number
---@param color rgbm
local function drawArc(center, direction, radius, angle, segments, color)
    local startAngle = math.atan2(direction.y, direction.x) - angle / 2
    local angleStep = angle / segments
    local cosStep = math.cos(angleStep)
    local sinStep = math.sin(angleStep)
    local cosA = math.cos(startAngle)
    local sinA = math.sin(startAngle)

    for _ = 1, segments do
        local nextCosA = cosA * cosStep - sinA * sinStep
        local nextSinA = sinA * cosStep + cosA * sinStep
        local point1 = center + vec2(cosA, sinA) * radius
        local point2 = center + vec2(nextCosA, nextSinA) * radius
        ui.drawTriangleFilled(center, point1, point2, color)
        cosA = nextCosA
        sinA = nextSinA
    end
end

function script.windowMain(dt)
    -- exit if not focused
    local sim = ac.getSim()
    local settingsPreview = sim.gameTime <= settingsPreviewUntil
    if sim.focusedCar ~= 0 then return end
    if sim.isReplayActive and not settingsPreview then return end
    local windowsHeader = WINDOWS_HEADER
    local fullWindowSize = ui.windowSize()
    local windowSize = fullWindowSize - windowsHeader
    local radarCenter = windowSize / 2               -- Centre du radar sur l'écran
    radarCenter = radarCenter + windowsHeader
    radarSize = math.min(windowSize.x, windowSize.y) -- Taille du radar en pixels
    -- Obtenez la position du joueur
    local playerCar = ac.getCar(0)
    if playerCar ~= nil then
        if (playerCar.isInPit or playerCar.isInPitlane) and not settingsPreview then
            return
        end
        local showPosition = AppConfig.showPosition
        local showLine = AppConfig.showLine
        local showCircle = AppConfig.showCircle
        local showSonar = AppConfig.showSonar
        local voiceEnabled = AppConfig.voice
        local range = AppConfig.range
        local rangeSq = range * range
        local pixelsPerMeter = (radarSize * 0.5) / range
        local proximityDistance = AppConfig.proximityDistance
        local playerPos = playerCar.position
        local playerSize = vec2(playerCar.aabbSize.x * pixelsPerMeter, playerCar.aabbSize.z * pixelsPerMeter)
        local playerLook = playerCar.look
        local playerAngle = math.atan2(playerLook.z, playerLook.x)
        local colorAlpha = 0
        local showRadar = false
        local isCarRight = false
        local isCarLeft = false
        local currentTime = sim.gameTime

        local forward = vec2(playerLook.x, playerLook.z) -- Direction du joueur sur x/z
        local right = vec2(-forward.y, forward.x)        -- Vecteur perpendiculaire à la direction du joueur
        local rightX, rightY = right.x, right.y
        local forwardX, forwardY = forward.x, forward.y
        local proximityOffset = 2 * pixelsPerMeter           -- Précalcule de la Distance de proximité
        local arcRadius = proximityDistance * pixelsPerMeter -- Précalcule Rayon de l'arc de cercle
        local arcAngle = math.rad(40)                        -- Précalcule Largeur de l'arc en radians
        -- Variables pour savoir quel cercle est impacté pour la couleur
        local minDistanceFound = math.huge

        -- Boucler sur les autres voitures
        for i = 1, sim.carsCount do
            local otherCar = ac.getCar(i)
            if otherCar ~= nil then
                -- Calculer la différence de hauteur
                local zOffset = math.abs(playerPos.y - otherCar.position.y)
                -- Only if the car is active and not in the pits and at the same height
                if otherCar.isActive and not (otherCar.isInPit or otherCar.isInPitlane) and zOffset < 2.8 then
                    local otherPos = otherCar.position
                    local otherLook = otherCar.look
                    local otherAngle = math.atan2(otherLook.z, otherLook.x)
                    local otherSize = vec2(otherCar.aabbSize.x * pixelsPerMeter, otherCar.aabbSize.z * pixelsPerMeter)

                    -- Calculer la distance relative par rapport au joueur
                    local dx = otherPos.x - playerPos.x
                    local dz = otherPos.z - playerPos.z

                    -- Filtrer les voitures en dehors de la portée du radar
                    local distanceSq = dx * dx + dz * dz
                    if distanceSq <= rangeSq then
                        local distance = math.sqrt(distanceSq)

                        -- Rayon de la voiture ennemie
                        local carRadius = (otherCar.aabbSize.x + otherCar.aabbSize.z) / 4
                        -- Distance réelle bord à bord
                        local effectiveDistance = math.max(0, distance - carRadius)
                        -- Met à jour seulement si on trouve plus proche
                        if effectiveDistance < minDistanceFound then
                            minDistanceFound = effectiveDistance
                        end
                        -- Projeter la position relative sur les axes forward et right
                        local xOffset = dx * rightX + dz * rightY
                        local yOffset = dx * forwardX + dz * forwardY
                        -- Convertir la position en pixels
                        local otherScreenPos = vec2(radarCenter.x + xOffset * pixelsPerMeter,
                            radarCenter.y - yOffset * pixelsPerMeter)
                        local new_alpha = math.max(0, 1 - (distance / range))
                        -- assignation uiquement si suppérieur
                        if colorAlpha < new_alpha then
                            colorAlpha = new_alpha
                        end
                        local OtherColor = rgbm(0.9, 0.9, 0.9, colorAlpha)
                        if otherCar.racePosition < playerCar.racePosition then
                            OtherColor = rgbm(0, 0.4, 1, colorAlpha)
                        end
                        -- Dessiner l'autre voiture sur le radar
                        ui.beginRotation()
                        local otherPositionText = showPosition and tostring(otherCar.racePosition) or nil
                        drawCar(otherScreenPos, otherSize, OtherColor, otherPositionText, showPosition)
                        ui.endRotation(math.deg(playerAngle - otherAngle) + 90)

                        if distance < proximityDistance then -- Distance très proche, par exemple moins de 5m
                            if voiceEnabled then
                                if not isCarRight then
                                    isCarRight = isCarOnSide(otherScreenPos, radarCenter, playerSize, proximityOffset,
                                        'right')
                                end
                                if not isCarLeft then
                                    isCarLeft = isCarOnSide(otherScreenPos, radarCenter, playerSize, proximityOffset,
                                        'left')
                                end
                            end
                            if showSonar then
                                -- Dessiner la flèche rouge sans la ligne
                                local invLen = 1 / math.max(1e-12, math.sqrt(xOffset * xOffset + yOffset * yOffset))
                                local direction = vec2(xOffset * invLen, -yOffset * invLen)
                                local segments = 10 -- Nombre de segments pour l'arc
                                drawArc(radarCenter, direction, arcRadius, arcAngle, segments, rgbm(1, 0.2, 0.2, 0.5))
                            end
                        end
                        showRadar = true
                    end
                end
            end
        end

        if showRadar or settingsPreview then
            if settingsPreview and colorAlpha < 0.8 then
                colorAlpha = 0.8
            end
            if voiceEnabled then
                if isCarLeft and canPlaySound(lastLeftSoundTime, currentTime) then
                    carOnLeftSound:play()
                    lastLeftSoundTime = currentTime
                end
                if isCarRight and canPlaySound(lastRightSoundTime, currentTime) then
                    carOnRightSound:play()           -- Jouer le son pour la voiture à droite
                    lastRightSoundTime = currentTime -- Mettre à jour le dernier moment où le son a été joué
                end
            end
            if showLine then
                ui.drawLine(vec2(radarCenter.x, 22), vec2(radarCenter.x, fullWindowSize.y),
                    rgbm(0.8, 0.8, 0.8, colorAlpha))
                ui.drawLine(vec2(0, radarCenter.y), vec2(windowSize.x, radarCenter.y), rgbm(0.8, 0.8, 0.8, colorAlpha))
            end
            if showCircle then
                -- Couleurs par défaut
                local colorInner = rgbm(0.8, 0.8, 0.8, colorAlpha)
                local colorMiddle = rgbm(0.8, 0.8, 0.8, colorAlpha)
                local colorOuter = rgbm(0.8, 0.8, 0.8, colorAlpha)
                local offsetDistance = proximityDistance / 2
                -- Maintenant appliquer la couleur selon distance MIN trouvée
                if minDistanceFound <= proximityDistance + offsetDistance then
                    colorOuter = rgbm(1, 0.6, 0.2, 0.5) -- Orange clair
                end
                if minDistanceFound <= proximityDistance then
                    colorMiddle = rgbm(1, 0.5, 0, colorAlpha) -- Orange intense
                    colorOuter = rgbm(1, 0.5, 0, colorAlpha)  -- Harmoniser
                end
                -- Animation de pulsation sur danger critique
                local pulse = 1
                if minDistanceFound <= proximityDistance - offsetDistance then
                    colorInner = rgbm(1, 0, 0, colorAlpha) -- Rouge vif Danger
                    pulse = 1 + math.sin(currentTime * 6) * 0.1
                end
                ui.drawCircle(radarCenter, (proximityDistance - offsetDistance) * pixelsPerMeter * pulse,
                    colorInner, 30)
                ui.drawCircle(radarCenter, proximityDistance * pixelsPerMeter, colorMiddle, 40)
                ui.drawCircle(radarCenter, (proximityDistance + offsetDistance) * pixelsPerMeter, colorOuter, 50)
            end
            if settingsPreview then
                drawSideZone(radarCenter, playerSize, proximityOffset, 'left', rgbm(1, 1, 0, 0.30))
                drawSideZone(radarCenter, playerSize, proximityOffset, 'right', rgbm(1, 1, 0, 0.30))
            end
            -- Dessiner le joueur au centre
            local playerPositionText = showPosition and tostring(playerCar.racePosition) or nil
            drawCar(radarCenter, playerSize, rgbm(0.3, 0.6, 0.5, colorAlpha), playerPositionText, showPosition)
        end
    end
end

function script.windowSetting(dt)
    local sim = ac.getSim()
    settingsPreviewUntil = sim.gameTime + 0.25
    ui.header("Voice")
    if ui.checkbox("Voice", AppConfig.voice) then
        AppConfig.voice = not AppConfig.voice
    end
    AppConfig.voiceRepeat = ui.slider('##voiceRepeat', AppConfig.voiceRepeat, 1.0, 10.0, 'Voice Repeat Time: %1.0f')
    AppConfig.volume = ui.slider('##volume', AppConfig.volume * 100, 0.1, 100, 'Voice volume: %.1f') / 100
    if ui.itemEdited() then
        finalVolume = gameVolume  * AppConfig.volume
        carOnLeftSound:setVolume(finalVolume)
        carOnRightSound:setVolume(finalVolume)
    end
    ui.header("Car")
    if ui.checkbox("Show position on car", AppConfig.showPosition) then
        AppConfig.showPosition = not AppConfig.showPosition
    end
    if ui.checkbox("Show line", AppConfig.showLine) then
        AppConfig.showLine = not AppConfig.showLine
    end
    if ui.checkbox("Show circle", AppConfig.showCircle) then
        AppConfig.showCircle = not AppConfig.showCircle
    end
    if ui.checkbox("Show Sonar", AppConfig.showSonar) then
        AppConfig.showSonar = not AppConfig.showSonar
    end
    AppConfig.range = ui.slider('##range', AppConfig.range, 10, 100, 'Radar Range: %.0fm')
    if ui.itemHovered() then
        ui.setTooltip("Distance to show cars on radar.")
    end
    AppConfig.proximityDistance = ui.slider('##Proximity', AppConfig.proximityDistance, 5, 20, 'Radar Proximity: %.0fm')
    if ui.itemHovered() then
        ui.setTooltip("Distance to show red proximity cone.")
    end
    local offsetDistance = AppConfig.proximityDistance / 2
    ui.text(string.format("Circles in meters: Inner %.1f / Middle %.1f / Outer %.1f",
        AppConfig.proximityDistance - offsetDistance,
        AppConfig.proximityDistance,
        AppConfig.proximityDistance + offsetDistance
    ))
end
