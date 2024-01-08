--
-- Created by Wile64 on october 2023
--

Settings = class('Settings')
function Settings:initialize() -- constructor
    self.ini = nil
    self.fileINI = ac.getFolder(ac.FolderID.ACDocuments) .. '\\apps\\sra_gap.ini'
    self.scale = 1
    self.carCount = 1
    self.bestLap = true
    self.lastLap = true
    self.tyres = true
    self:load()
end

function Settings:load()
    self.ini = ac.INIConfig.load(self.fileINI)
    if self.ini ~= nil then
        self.scale = self.ini:get("UI", "Scale", 1)
        self.carCount = self.ini:get("UI", "carCount", 1)
        self.bestLap = self.ini:get("UI", "bestLap", true)
        self.lastLap = self.ini:get("UI", "lastLap", true)
        self.tyres = self.ini:get("UI", "tyres", true)
    end
end

function Settings:save()
    self.ini:set("UI", "Scale", self.scale)
    self.ini:set("UI", "carCount", self.carCount)
    self.ini:set("UI", "bestLap", self.bestLap)
    self.ini:set("UI", "lastLap", self.lastLap)
    self.ini:set("UI", "tyres", self.tyres)
    self.ini:save(self.fileINI)
end
