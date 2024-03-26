--
-- Created by Wile64 on mars 2024
--

CarSetup = class('CarSRA')
function CarSetup:initialize()
    self.setupList = nil
    self.isLoaded = false
end

---Load data from current setup
function CarSetup:GetCurrentSetup()
    local cs = ac.stringifyCurrentSetup()
    local ini = ac.INIConfig.parse(cs, ac.INIFormat.Default)
    self.setupList = table.map(ini.sections,
        function(item, index) return item.VALUE and tonumber(item.VALUE[1]), index end)
    self.isLoaded = true
end

---Load data from setup INI file
---@param fileName string
function CarSetup:LoadFromFile(fileName)
    if io.fileExists(fileName) then
        local ini = ac.INIConfig.load(fileName)
        self.setupList = table.map(ini.sections,
            function(item, index) return item.VALUE and tonumber(item.VALUE[1]), index end)
        self.isLoaded = true
    end
end

---Get the setup list
---@return table|boolean
function CarSetup:getValueList()
    if self.isLoaded then
        return self.setupList
    else
        return false
    end
end

---Get the setup value
---@param setupValueID string
---@return number|boolean
function CarSetup:getValue(setupValueID)
    if self.isLoaded then
        return self.setupList[setupValueID]
    else
        return false
    end
end

---Apply the setup value to the Car
---@param setupValueID string
---@param value integer
---@return boolean
function CarSetup:applySetupValue(setupValueID, value)
    return ac.setSetupSpinnerValue(setupValueID, value)
end
