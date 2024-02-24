--
-- Created by Wile64 on october 2023
--

Settings = class('Settings')
function Settings:initialize() -- constructor
    self.ini = nil
    self.fileINI = ac.getFolder(ac.FolderID.ACDocuments) .. '\\apps\\sra_hud.ini'
    self.scale = 1
    self.styleColor = rgbm.new("#8800FFFF")
    self.fontColor = rgbm.new("#FFFFFFFF")
    self:load()
end

function Settings:load()
    self.ini = ac.INIConfig.load(self.fileINI)
    if self.ini ~= nil then
        self.scale = self.ini:get("UI", "Scale", 1)
        self.styleColor = rgbm.new(self.ini:get("UI", "styleColor", "#8800FFFF"))
        self.fontColor = rgbm.new(self.ini:get("UI", "fontColor", "#FFFFFFFF"))
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

function Settings:save()
    self.ini:set("UI", "Scale", self.scale)
    self.ini:set("UI", "styleColor", self:rgbToHex(self.styleColor))
    self.ini:set("UI", "fontColor", self:rgbToHex(self.fontColor))
    self.ini:save(self.fileINI)
end
