--
-- Created by Wile64 on october 2023
--

Settings = class('Settings')
function Settings:initialize() -- constructor
    self.chronoHUD = {
        showDelta = true,
        showCurrent = true,
        showEstimated = true,
        showPrevious = true,
        showBest = true,
        showPersonal = true,
    }
    self.weatherHUD = {
        showAmbientTemp = true,
        showRoadTemp = true,
        showWindSpeed = true,
    }
    self.raceHUD = {
        showRoadGrip = true,
        showFuelRate = true,
        showDamageRate = true,
        showTyreRate = true,
    }
    self.positionHUD = {
        showSession = true,
        showPosition = true,
        showLapCount = true,
        showSessionTimer = true,
        showFlag = true,
    }
    self.ledHUD = {
        scale = 1.0
    }
    self.ini = nil
    self.fileINI = ac.getFolder(ac.FolderID.ACDocuments) .. '/apps/sra_hud.ini'
    self.scale = 1
    self.styleColor = rgbm.new("#8800FFFF")
    self.fontColor = rgbm.new("#FFFFFFFF")
    self:load()
end

function Settings:loadList(table, name)
    for key, value in pairs(table) do
        if rgbm.isrgbm(value) then
            table[key] = rgbm.new(self.ini:get(name, key, value))
        else
            table[key] = self.ini:get(name, key, value)
        end
    end
end

function Settings:load()
    self.ini = ac.INIConfig.load(self.fileINI)
    if self.ini ~= nil then
        self.scale = self.ini:get("UI", "Scale", 1)
        self.styleColor = rgbm.new(self.ini:get("UI", "styleColor", "#8800FFFF"))
        self.fontColor = rgbm.new(self.ini:get("UI", "fontColor", "#FFFFFFFF"))
        self:loadList(self.chronoHUD, "chronoHUD")
        self:loadList(self.weatherHUD, "weatherHUD")
        self:loadList(self.raceHUD, "raceHUD")
        self:loadList(self.positionHUD, "positionHUD")
        self:loadList(self.ledHUD, "ledHUD")
    end
end

---comment
---@param color rgbm
---@return string
function Settings:rgbToHex(color)
    return string.upper(string.format("#%02x%02x%02x%02x",
        math.floor(color.mult * 255),
        math.floor(color.r * 255),
        math.floor(color.g * 255),
        math.floor(color.b * 255)))
end

function Settings:saveList(table, name)
    for key, value in pairs(table) do
        if rgbm.isrgbm(value) then
            self.ini:set(name, key, self:rgbToHex(value))
        else
            self.ini:set(name, key, value)
        end
    end
end

function Settings:save()
    self.ini:set("UI", "Scale", self.scale)
    self.ini:set("UI", "styleColor", self:rgbToHex(self.styleColor))
    self.ini:set("UI", "fontColor", self:rgbToHex(self.fontColor))
    self:saveList(self.chronoHUD, "chronoHUD")
    self:saveList(self.weatherHUD, "weatherHUD")
    self:saveList(self.raceHUD, "raceHUD")
    self:saveList(self.positionHUD, "positionHUD")
    self:saveList(self.ledHUD, "ledHUD")
    self.ini:save(self.fileINI)
end
