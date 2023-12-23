--
-- Created by Wile64 on october 2023
--

Settings = class('Settings')
function Settings:initialize() -- constructor
    self.ini = nil
    self.fileINI = ac.getFolder(ac.FolderID.ACDocuments) .. '\\apps\\sra_minidash.ini'
    self.Scale = 1
    self.LineColor = rgbm.new("#FFFB10")
    self.RPMColor = rgbm.new("#39A200")
    self.FuelColor = rgbm.new("#0377A8")
    self.BackgroundColor = rgbm.new("#292929")
    self:load()
end

function Settings:load()
    self.ini = ac.INIConfig.load(self.fileINI)
    if self.ini ~= nil then
        self.Scale = self.ini:get("UI", "Scale", 1)
        self.LineColor = rgbm.new(self.ini:get("UI", "LineColor", "#FFFB10"))
        self.RPMColor = rgbm.new(self.ini:get("UI", "RPMColor", "#39A200"))
        self.FuelColor = rgbm.new(self.ini:get("UI", "FuelColor", "#0377A8"))
        self.BackgroundColor = rgbm.new(self.ini:get("UI", "BackgorundColor", "#292929"))
    end
end

function Settings:rgbToHex(color)
    return string.upper(string.format("#%02x%02x%02x",
        math.floor(color.r * 255),
        math.floor(color.g * 255),
        math.floor(color.b * 255)))
end

function Settings:save()
    self.ini:set("UI", "Scale", self.Scale)
    self.ini:set("UI", "LineColor", self:rgbToHex(self.LineColor))
    self.ini:set("UI", "RPMColor", self:rgbToHex(self.RPMColor))
    self.ini:set("UI", "FuelColor", self:rgbToHex(self.FuelColor))
    self.ini:set("UI", "BackgorundColor", self:rgbToHex(self.BackgroundColor))
    self.ini:save(self.fileINI)
end
