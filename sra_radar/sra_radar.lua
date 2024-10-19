--
-- Created by Wile64 on october 2024
--
VERSION = 1.0

local AppConfig = ac.storage {
    voice = true,
    voiceRepeat = 5,
    volume = 1,
    showPosition = true,
    showLine = true,
    showCircle = true,
}

local visible = false
local carOnLeftSound = ui.MediaPlayer('sound/car-on-left.wav'):setVolume(AppConfig.volume):setAutoPlay(false)
local carOnRightSound = ui.MediaPlayer('sound/car-on-right.wav'):setVolume(AppConfig.volume):setAutoPlay(false)

-- Configuration du radar
local radarRange = 25 -- portée du radar en mètres
local radarSize = 200 -- taille de la fenêtre du radar en pixels

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

-- Fonction pour convertir la distance en pixels
local function metersToPixels(meters)
    return (meters / radarRange) * (radarSize)
end

-- Vérifier si une position est dans un rectangle défini par rectStart et rectEnd
---@param pos vec2
---@param rectStart vec2
---@param rectEnd vec2
---@return boolean
local function isInsideRectangle(pos, rectStart, rectEnd)
    return (pos.x >= math.min(rectStart.x, rectEnd.x) and pos.x <= math.max(rectStart.x, rectEnd.x))
        and (pos.y >= math.min(rectStart.y, rectEnd.y) and pos.y <= math.max(rectStart.y, rectEnd.y))
end

-- Détection de la voiture sur la droite
---@param position vec2
---@param screen_pos vec2
---@param car_size vec2
---@param size number
---@return boolean
local function isCarOnRight(position, screen_pos, car_size, size)
    local halfCarSize = car_size / 2
    local starPos     = screen_pos + vec2(halfCarSize.x, -halfCarSize.y)
    local endPos      = screen_pos + vec2(halfCarSize.x * 2 + size, halfCarSize.y * 2)
    -- ui.drawRect(
    --     starPos,         -- Position haut-gauche du rectangle
    --     endPos,          -- Position bas-droite du rectangle
    --     rgbm.colors.red, -- Couleur avec alpha (transparence)
    --     0                -- Pas de bord arrondi
    -- )
    -- ui.drawCircleFilled(position, 1, rgbm.colors.blue, 20)
    return isInsideRectangle(position, starPos, endPos)
end

-- Détection de la voiture sur la gauche
---@param position vec2
---@param screen_pos vec2
---@param car_size vec2
---@param size number
---@return boolean
local function isCarOnLeft(position, screen_pos, car_size, size)
    local halfCarSize = car_size / 2
    local starPos     = screen_pos - vec2(halfCarSize.x * 2 + size, halfCarSize.y)
    local endPos      = screen_pos + vec2(-halfCarSize.x, halfCarSize.y * 2)

    -- ui.drawRect(
    --     starPos,         -- Position haut-gauche du rectangle
    --     endPos,          -- Position bas-droite du rectangle
    --     rgbm.colors.red, -- Couleur avec alpha (transparence)
    --     0                -- Pas de bord arrondi
    -- )
    -- ui.drawCircleFilled(position, 1, rgbm.colors.blue, 20)
    return isInsideRectangle(position, starPos, endPos)
end

--- Fonction pour dessiner un rectangle représentant une voiture
---@param screen_pos vec2
---@param car_size vec2
---@param color rgbm
---@param position string
local function drawCar(screen_pos, car_size, color, position)
    local halfCarSize = car_size / 2
    -- Dessiner le rectangle de la voiture
    ui.drawRectFilled(
        screen_pos - halfCarSize, -- Position haut-gauche du rectangle
        screen_pos + halfCarSize, -- Position bas-droite du rectangle
        color,                    -- Couleur avec alpha (transparence)
        5                         -- Pas de bord arrondi
    )
    -- Afficher la position si l'option est activée
    if AppConfig.showPosition then
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
    -- Obtenir l'angle de départ de l'arc
    local startAngle = math.atan2(direction.y, direction.x) - angle / 2
    local angleStep = angle / segments -- Angle entre chaque segment

    -- Boucle pour dessiner l'arc en utilisant des triangles
    for i = 0, segments - 1 do
        local currentAngle = startAngle + i * angleStep
        local nextAngle = startAngle + (i + 1) * angleStep

        -- Calcul des positions des points sur le cercle
        local point1 = center + vec2(math.cos(currentAngle), math.sin(currentAngle)) * radius
        local point2 = center + vec2(math.cos(nextAngle), math.sin(nextAngle)) * radius

        -- Dessiner un triangle entre le centre, point1, et point2
        ui.drawTriangleFilled(center, point1, point2, color)
    end
end

function script.windowMain(dt)
    ac.setWindowTitle('windowMain', string.format('SRA Radar v%.2f', VERSION))
    local windowsHeader = vec2(0, 22)
    local windowSize = ui.windowSize() - windowsHeader
    local radarCenter = windowSize / 2               -- Centre du radar sur l'écran
    radarCenter = radarCenter + windowsHeader
    radarSize = math.min(windowSize.x, windowSize.y) -- Taille du radar en pixels

    -- Obtenez la position du joueur
    local playerCar = ac.getCar(0)
    if playerCar ~= nil then
        if playerCar.isInPit or playerCar.isInPitlane then
            return
        end
        local playerPos = playerCar.position
        local playerSize = vec2(metersToPixels(playerCar.aabbSize.x), metersToPixels(playerCar.aabbSize.z))
        local playerLook = playerCar.look
        local playerAngle = math.atan2(playerLook.z, playerLook.x)
        local colorAlpha = 0
        local showRadar = false
        local isCarRight = false
        local isCarLeft = false
        local currentTime = os.clock()
        local proximityDistance = 7 -- Distance de proximité pour afficher l'effet

        -- Boucler sur les autres voitures
        for i = 1, ac.getSim().carsCount do
            local otherCar = ac.getCar(i)
            if otherCar ~= nil then
                local zOffset = math.abs(playerPos.y - otherCar.position.y)
                -- Only if the car is active and not in the pits and at the same height
                if otherCar.isActive and not (otherCar.isInPit or otherCar.isInPitlane) and zOffset < 2 then
                    local otherPos = otherCar.position
                    local otherLook = otherCar.look
                    local otherAngle = math.atan2(otherLook.z, otherLook.x)
                    local otherSize = vec2(metersToPixels(otherCar.aabbSize.x), metersToPixels(otherCar.aabbSize.z))

                    -- Calculer la distance relative par rapport au joueur
                    local dx = otherPos.x - playerPos.x
                    local dz = otherPos.z - playerPos.z

                    local forward = vec2(playerLook.x, playerLook.z) -- Direction du joueur sur x/z
                    local right = vec2(-forward.y, forward.x)        -- Vecteur perpendiculaire à la direction du joueur

                    -- Projeter la position relative sur les axes forward et right
                    local xOffset = math.dot(vec2(dx, dz), right)
                    local yOffset = math.dot(vec2(dx, dz), forward)
                    -- Filtrer les voitures en dehors de la portée du radar
                    local distance = math.sqrt(dx * dx + dz * dz)
                    if distance <= radarRange then
                        -- Convertir la position en pixels
                        local otherScreenPos = vec2(radarCenter.x + metersToPixels(xOffset),
                            radarCenter.y + metersToPixels(-yOffset))
                        local new_alpha = math.max(0, 1 - (distance / radarRange))
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
                        drawCar(otherScreenPos, otherSize, OtherColor, tostring(otherCar.racePosition))
                        ui.endRotation(math.deg(playerAngle - otherAngle) + 90)

                        if distance < proximityDistance then -- Distance très proche, par exemple moins de 5m
                            if not isCarRight then
                                isCarRight = isCarOnRight(otherScreenPos, radarCenter, playerSize, metersToPixels(2))
                            end
                            if not isCarLeft then
                                isCarLeft = isCarOnLeft(otherScreenPos, radarCenter, playerSize, metersToPixels(2))
                            end
                            -- Dessiner la flèche rouge sans la ligne
                            local direction = (vec2(xOffset, -yOffset)):normalize()
                            local radius = metersToPixels(7) -- Rayon de l'arc de cercle
                            local arcAngle = math.rad(40)    -- Largeur de l'arc en radians
                            local segments = 10              -- Nombre de segments pour l'arc
                            drawArc(radarCenter, direction, radius, arcAngle, segments, rgbm(1, 0.2, 0.2, 0.5))
                        end
                        showRadar = true
                    end
                end
            end
        end
        if showRadar then
            if isCarLeft and canPlaySound(lastLeftSoundTime, currentTime) then
                if AppConfig.voice then
                    carOnLeftSound:play()
                    lastLeftSoundTime = currentTime
                end
            end
            if isCarRight and canPlaySound(lastRightSoundTime, currentTime) then
                if AppConfig.voice then
                    carOnRightSound:play()           -- Jouer le son pour la voiture à droite
                    lastRightSoundTime = currentTime -- Mettre à jour le dernier moment où le son a été joué
                end
            end
            if AppConfig.showLine then
                ui.drawLine(vec2(radarCenter.x, 22), vec2(radarCenter.x, ui.windowSize().y),
                    rgbm(0.8, 0.8, 0.8, colorAlpha))
                ui.drawLine(vec2(0, radarCenter.y), vec2(windowSize.x, radarCenter.y), rgbm(0.8, 0.8, 0.8, colorAlpha))
            end
            if AppConfig.showCircle then
                ui.drawCircle(radarCenter, metersToPixels(4), rgbm(0.8, 0.8, 0.8, colorAlpha), 30)
                ui.drawCircle(radarCenter, metersToPixels(7), rgbm(0.8, 0.8, 0.8, colorAlpha), 40)
                ui.drawCircle(radarCenter, metersToPixels(10), rgbm(0.8, 0.8, 0.8, colorAlpha), 50)
            end
            -- Dessiner le joueur au centre
            drawCar(radarCenter, playerSize, rgbm(0.3, 0.6, 0.5, colorAlpha), tostring(playerCar.racePosition))
        end
    end
end

function script.onShowWindowMain(dt)
    visible = true
end

function script.onHideWindowMain(dt)
    visible = false
end

function script.windowSetting(dt)
    ui.header("Voice")
    if ui.checkbox("Voice", AppConfig.voice) then
        AppConfig.voice = not AppConfig.voice
    end
    AppConfig.voiceRepeat = ui.slider('##voiceRepeat', AppConfig.voiceRepeat, 1.0, 10.0, 'Voice Repeat Time: %1.0f')
    AppConfig.volume = ui.slider('##volume', AppConfig.volume * 100, 0.1, 100, 'Voice volume: %.1f') / 100
    if ui.itemEdited() then
        carOnLeftSound:setVolume(AppConfig.volume)
        carOnRightSound:setVolume(AppConfig.volume)
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
end
