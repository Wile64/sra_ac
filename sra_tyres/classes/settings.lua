--
-- Created by Wile64 on october 2023
--

Settings = class('Settings')
function Settings:initialize() -- constructor
    self.ini = nil
    self.fileINI = ac.getFolder(ac.FolderID.ACDocuments) .. '\\apps\\sra_tyres.ini'
    self.Scale = 1
    self.showOptimal = true
    self.showTyreName = true
    self.showToeIn = true
    self.showGrain = true
    self.showBlister = true
    self.showFlatSpot = true
    self.showLoad = true
    self.showDisc = true
    self:load()
end

function Settings:load()
    self.ini = ac.INIConfig.load(self.fileINI)
    if self.ini ~= nil then
        self.Scale = self.ini:get("UI", "Scale", 1)
        self.showOptimal = self.ini:get("UI", "showOptimal", true)
        self.showTyreName = self.ini:get("UI", "showTyreName", true)
        self.showToeIn = self.ini:get("UI", "showToeIn", true)
        self.showGrain = self.ini:get("UI", "showGrain", true)
        self.showFlatSpot = self.ini:get("UI", "showFlatSpot", true)
        self.showLoad = self.ini:get("UI", "showLoad", true)
        self.showDisc = self.ini:get("UI", "showDisc", true)
    end
end

function Settings:save()
    self.ini:set("UI", "Scale", self.Scale)
    self.ini:set("UI", "showOptimal", self.showOptimal)
    self.ini:set("UI", "showTyreName", self.showTyreName)
    self.ini:set("UI", "showToeIn", self.showToeIn)
    self.ini:set("UI", "showGrain", self.showGrain)
    self.ini:set("UI", "showBlister", self.showBlister)
    self.ini:set("UI", "showFlatSpot", self.showFlatSpot)
    self.ini:set("UI", "showLoad", self.showLoad)
    self.ini:set("UI", "showDisc", self.showDisc)
    self.ini:save(self.fileINI)
end
