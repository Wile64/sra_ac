--
-- Created by Wile64 on october 2023
--

KersStatus = {
    Ready = 1,
    Charge = 2,
    Active = 3
}

CarSRA = class('CarSRA')
function CarSRA:initialize()
    ---@public
    self.carState = nil
    self.idealFrontPressure = 0
    self.idealRearPressure = 0
    ---@private
    self.carID = 0
    self.currentCompoundIndex = -1
end
--- Set the current focused car
function CarSRA:setFocusedCar()
    local focusedCar = ac.getSim().focusedCar
    if focusedCar >= 0 then
        self:setCarID(focusedCar)
    end
end

--- Set focused car ID
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

---Get Kers Status
---KersStatus = {
---    Ready = 1,
---    Charge = 2,
---    Active = 3
---}
---@return integer
function CarSRA:getKersStatus()
    if self.carState.kersCurrentKJ >= self.carState.kersMaxKJ then
        return KersStatus.Charge
    elseif self.carState.kersButtonPressed then
        return KersStatus.Active
    else
        return KersStatus.Ready
    end
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

--- Get current gear in string
---@return string
function CarSRA:getGearToString()
    if self.carState.gear < 0 then
        return "R"
    elseif self.carState.gear == 0 then
        return "N"
    else
        return tostring(self.carState.gear)
    end
end

function CarSRA:update(dt)
    local carstate = ac.getCar(self.carID)
    
    if carstate ~= nil then
        self.carState = carstate
        if self.currentCompoundIndex ~= self.carState.compoundIndex then
            self:loadTyreInfo()
            self.currentCompoundIndex = self.carState.compoundIndex
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
end
