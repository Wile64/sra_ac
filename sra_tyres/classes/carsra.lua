--
-- Created by Wile64 on october 2023
--

CarSRA = class('CarSRA')
function CarSRA:initialize()
    ---@public
    self.carState = nil
    self.idealFrontPressure = 0
    self.idealRearPressure = 0
    ---@private
    self.carID = 0
    self.currentCompoundIndex = -1

    -- Wear
    self.frontWearCurve = nil
    self.rearWearCurve = nil

    -- Thermal
    self.minThermal = 0
    self.maxThermal = 0

    -- Disc
    self.isDiscLoaded = false
    self.isDiscAvailable = true
    self.discData = {
        minFrontTemp = 0,
        maxFrontTemp = 0,
        idealMinFrontTemp = 0,
        idealMaxFrontTemp = 0,
        minRearTemp = 0,
        maxRearTemp = 0,
        idealMinRearTemp = 0,
        idealMaxRearTemp = 0
    }
end

function CarSRA:setFocusedCar()
    local focusedCar = ac.getSim().focusedCar
    if focusedCar >= 0 then
        self.carID = focusedCar
    end
end

--- Change focus car
---@param ID number
function CarSRA:setCarID(ID)
    if self.carID ~= ID then
        self.carID = ID
    end
end

--- Get the engine life 100% --> 0%
---@return number
function CarSRA:getEngineLifePercent()
    return self.carState.engineLifeLeft > 0 and (1 - self.carState.engineLifeLeft / 1000) * 100 or 100
end

--- Get the gearbox damage 0 --> 100%
---@return number
function CarSRA:getGearboxDamagePercent()
    return self.carState.gearboxDamage < 1 and self.carState.gearboxDamage * 100 or 100
end

--- Get the front damage 0 --> 100%
---@return number
function CarSRA:getFrontDamagePercent()
    return self.carState.damage[0] <= 100 and self.carState.damage[0] or 100
end

--- Get the rear damage 0 --> 100%
---@return number
function CarSRA:getRearDamagePercent()
    return self.carState.damage[1] <= 100 and self.carState.damage[1] or 100
end

--- Get the left damage 0 --> 100%
---@return number
function CarSRA:getLeftDamagePercent()
    return self.carState.damage[2] <= 100 and self.carState.damage[2] or 100
end

--- Get the right damage 0 --> 100%
---@return number
function CarSRA:getRightDamagePercent()
    return self.carState.damage[3] <= 100 and self.carState.damage[3] or 100
end

--- Get front left tyre state
---@return ac.StateWheel
function CarSRA:getTyreFL()
    return self.carState.wheels[0]
end

--- Get front right tyre state
---@return ac.StateWheel
function CarSRA:getTyreFR()
    return self.carState.wheels[1]
end

--- Get rear left tyre state
---@return ac.StateWheel
function CarSRA:getTyreRL()
    return self.carState.wheels[2]
end

--- Get rear right tyre state
---@return ac.StateWheel
function CarSRA:getTyreRR()
    return self.carState.wheels[3]
end

--- Get traction car type "rwd", "fwd", "awd", "new awd"
---@return string
function CarSRA:getTractionType()
    local tractionType = { [0] = "rwd", "fwd", "awd", "new awd" }
    if self.carState.tractionType >= 0 then
        return tractionType[self.carState.tractionType]
    else
        return "unknow"
    end
end

--- Get engine position "unknow", "front", "rear", "mid"
---@return string
function CarSRA:getEnginePosition()
    local enginePosition = { [0] = "unknow", "front", "rear", "mid" }
    return enginePosition[self.carState.enginePosition]
end

--- Get remain fuel lap
---@return number
function CarSRA:getRemainFuelLap()
    return self.carState.fuelPerLap > 0 and self.carState.fuel / self.carState.fuelPerLap or 0
end

function CarSRA:update(dt)
    local carstate = ac.getCar(self.carID)
    if carstate ~= nil then
        self.carState = carstate
        if self.currentCompoundIndex ~= self.carState.compoundIndex then
            self:loadTyreInfo()
            self.currentCompoundIndex = self.carState.compoundIndex
        end
        if self.isDiscLoaded == false and self.isDiscAvailable then
            self:loadDiscInfo()
        end
    end
end

function CarSRA:loadTyreInfo()
    local tyreini = ac.INIConfig.carData(0, 'tyres.ini')
    local front = "FRONT"
    local rear = "REAR"
    if self.carState.compoundIndex > 0 then
        front = front .. "_" .. tostring(self.carState.compoundIndex)
        rear = rear .. "_" .. tostring(self.carState.compoundIndex)
    end
    self.idealFrontPressure = tyreini:get(front, "PRESSURE_IDEAL", 0)
    self.idealRearPressure = tyreini:get(rear, "PRESSURE_IDEAL", 0)
    self.frontWearCurve = tyreini:tryGetLut(front, "WEAR_CURVE")
    self.rearWearCurve = tyreini:tryGetLut(rear, "WEAR_CURVE")
    front = "THERMAL_" .. front
    rear = "THERMAL_" .. rear
    local thermalCurve = tyreini:tryGetLut(front, "PERFORMANCE_CURVE")
    if thermalCurve == nil then
        thermalCurve = tyreini:tryGetLut(rear, "PERFORMANCE_CURVE")
    end
    self.minThermal = 0
    self.maxThermal = 0
    if thermalCurve ~= nil then
        for i = 0, #thermalCurve - 1 do
            if thermalCurve:getPointOutput(i) == 1 then
                local input = thermalCurve:getPointInput(i)
                if self.maxThermal < input then
                    self.maxThermal = input
                end
                if self.minThermal == 0 then
                    self.minThermal = input
                end
            end
        end
    else
        self.minThermal = 80
        self.maxThermal = self:getTyreFL().tyreOptimumTemperature
    end
    if DEBUG then
        ac.log("Tyre loaded")
    end
end

function CarSRA:loadDiscInfo()
    local brakeini = ac.INIConfig.carData(0, 'brakes.ini')
    --Front
    local frontCurve = brakeini:tryGetLut("TEMPS_FRONT", "PERF_CURVE")
    if frontCurve ~= nil then
        self.isDiscLoaded = true
        self.isDiscAvailable = true
        local min, max = frontCurve:bounds()
        self.discData.minFrontTemp = min.x
        self.discData.maxFrontTemp = max.x
        for i = 0, #frontCurve - 1 do
            if frontCurve:getPointOutput(i) == 1 then
                local input = frontCurve:getPointInput(i)
                if self.discData.idealMaxFrontTemp < input then
                    self.discData.idealMaxFrontTemp = input
                end
                if self.discData.idealMinFrontTemp == 0 then
                    self.discData.idealMinFrontTemp = input
                end
            end
        end
    else
        self.isDiscLoaded = false
        self.isDiscAvailable = false
        return
    end
    --Rear
    local rearCurve = brakeini:tryGetLut("TEMPS_REAR", "PERF_CURVE")
    if rearCurve ~= nil then
        self.isDiscLoaded = true
        self.isDiscAvailable = true
        local min, max = rearCurve:bounds()
        self.discData.minRearTemp = min.x
        self.discData.maxRearTemp = max.x
        for i = 0, #rearCurve - 1 do
            if rearCurve:getPointOutput(i) == 1 then
                local input = rearCurve:getPointInput(i)
                if self.discData.idealMaxRearTemp < input then
                    self.discData.idealMaxRearTemp = input
                end
                if self.discData.idealMinRearTemp == 0 then
                    self.discData.idealMinRearTemp = input
                end
            end
        end
    else
        self.isDiscLoaded = false
        self.isDiscAvailable = false
        return
    end
    if DEBUG then
        ac.log("Disc loaded")
    end
end
