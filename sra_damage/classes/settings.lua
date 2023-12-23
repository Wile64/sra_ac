--
-- Created by Wile64 on october 2023
--

Settings = class('Settings')
function Settings:initialize()
    self.ini = nil
    self.fileINI = ac.getFolder(ac.FolderID.ACDocuments) .. '\\apps\\sra_damage.ini'
    self.scale = 1
    self.textColor = rgbm.new("#FFFFFFF")
    self:load()
end

function Settings:load()
    self.ini = ac.INIConfig.load(self.fileINI)
    if self.ini ~= nil then
        self.scale = self.ini:get("UI", "Scale", 1)
        self.textColor = rgbm.new(self.ini:get("UI", "TextColor", "#FFFFFFF"))
    end
end

function Settings:rgbToHex(color)
    return string.upper(string.format("#%02x%02x%02x",
        math.floor(color.r * 255),
        math.floor(color.g * 255),
        math.floor(color.b * 255)))
end

function Settings:save()
    self.ini:set("UI", "Scale", self.scale)
    self.ini:set("UI", "TextColor", self:rgbToHex(self.textColor))
    self.ini:save(self.fileINI)
end
