--
-- Created by Wile64 on october 2023
--

local function nickName(name)
    local prev_token = ""
    local last = ""
    local result = ""
    for token in string.gmatch(name, "[^%s._-[-(())[{}|]+") do
        if prev_token ~= "" then
            if string.match(prev_token, ".*]") then
                --print(prev_token)
                result = result
            else
                --print(prev_token)
                result = result .. string.sub(prev_token, 1, 1) .. "."
            end
        end
        prev_token = token
        last = token
    end
    return result .. last
end

---gap in second
---@param gap number
---@return string
local function gapToString(gap)
    local minutes = math.floor(gap / 60)
    local seconds = gap - (minutes * 60)
    local centiseconds = math.floor((seconds - math.floor(seconds)) * 100)
    if minutes > 0 then
        return string.format("%d:%02d.%02d", minutes, math.floor(seconds), centiseconds)
    else
        return string.format("%d.%02d", seconds, centiseconds)
    end
end

local function lapTimeToString(lapTimeMs)
    local minutes = math.floor(lapTimeMs / 60e3)
    if minutes > 0 then
        return string.format("%02d:%02.3f", minutes, (lapTimeMs / 1000) % 60)
    else
        return string.format("%02.3f", (lapTimeMs / 1000) % 60)
    end
end

---@return string
function getRealGapStr(car1, car2)
    if ac.getSim().isSessionStarted then
        if car1.laps ~= car2.laps then
            local lapDiff = car1.laps - car2.laps
            if lapDiff > 1 then
                return string.format("%d Laps", car1.laps - car2.laps)
            else
                return string.format("%d Lap", car1.laps - car2.laps)
            end
        else
            if car2.speedKmh < 1 then
                return '--'
            end
            local car1Pos = car1.splinePosition
            local car2Pos = car2.splinePosition
            return gapToString(((car1Pos - car2Pos) / (car2.speedKmh / 3.6) * ac.getSim().trackLengthM))
        end
    else
        return ''
    end
end

---@return string
function getTimeGapStr(car1, car2)
    if ac.getSim().isSessionStarted then
        return lapTimeToString((car2.bestLapTimeMs - car1.bestLapTimeMs))
    else
        return ''
    end
end

CarsInfo = class('CarsInfo')
function CarsInfo:initialize(id)
    self.isActive = false
    self.id = id
    self.nickName = ""
    self.laps = 0
    self.bestLapTimeMs = 0
    self.racePosition = 0
    self.inPit = false
    self.splinePosition = 0
    self.speedKmh = 0
    self.previousLapTimeMs = 0
    self.lapTimeMs = 0
    self.isLastLapValid = false
end

function CarsInfo:reset()
    self.isActive = false
    self.laps = 0
    self.bestLapTimeMs = 0
    self.racePosition = 0
    self.inPit = false
    self.splinePosition = 0
    self.speedKmh = 0
    self.previousLapTimeMs = 0
    self.lapTimeMs = 0
    self.tyreName = ""
    self.isLastLapValid = false
end

function CarsInfo:setActive(isActive)
    if isActive ~= self.isActive then
        self:reset()
        self.isActive = isActive
        if self.isActive then
            self.nickName = nickName(ac.getDriverName(self.id))
        end
    end
end

---comment
---@param dt number
---@param stateCar ac.StateCar
function CarsInfo:update(dt, stateCar)
    self:setActive(stateCar.isConnected)
    if self.isActive then
        self.isLastLapValid = stateCar.isLastLapValid
        local lapTimeMs = stateCar.lapTimeMs
        if lapTimeMs < self.lapTimeMs then
            self.previousLapTimeMs = self.lapTimeMs + dt
            if stateCar.isLastLapValid then
                if self.bestLapTimeMs == 0 then
                    self.bestLapTimeMs = self.previousLapTimeMs
                elseif self.bestLapTimeMs > self.previousLapTimeMs then
                    self.bestLapTimeMs = self.previousLapTimeMs
                end
            end
        end
        self.lapTimeMs = lapTimeMs
        self.laps = stateCar.sessionLapCount
        self.racePosition = stateCar.racePosition
        self.inPit = stateCar.isInPit or stateCar.isInPitlane
        self.splinePosition = stateCar.splinePosition
        self.speedKmh = stateCar.speedKmh
        self.tyreName = ac.getTyresName(self.id, stateCar.compoundIndex)
    end
end
