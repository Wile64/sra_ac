Sectors = class('Sectors')
function Sectors:initialize() -- constructor
    self.sectorIndex = 0
    self.sectorCount = 0
    self.sectorTime = 0
    self.oldSectorTime = 0
    self.bestSplits = {}
    self.splits = {}
    self:reset()
end

function Sectors:reset()
    local carState = ac.getCar(0)
    if carState == nil then return end
    local simState = ac.getSim()
    if simState == nil then return end

    self.sectorIndex = carState.currentSector
    self.sectorCount = #simState.lapSplits
    self.sectorTime = 0
    self.oldSectorTime = 0
    self.inPit = false
    table.clear(self.bestSplits)
    table.clear(self.splits)
    for _ = 1, self.sectorCount do
        table.insert(self.bestSplits, 0)
        table.insert(self.splits, 99999999)
    end
end

function Sectors:update(dt)
    local carState = ac.getCar(0)
    if carState == nil then return end
    self.inPit = carState.isInPit or carState.isInPitlane
    self.sectorTime = carState.lapTimeMs - self.oldSectorTime
    self.splits[self.sectorIndex] = self.sectorTime

    if self.sectorIndex ~= carState.currentSector then
        self.bestSplits[self.sectorIndex] = carState.bestSplits[self.sectorIndex]
        self.splits[self.sectorIndex] = carState.previousSectorTime
        self.oldSectorTime = carState.previousSectorTime
        if self.sectorIndex > carState.currentSector then
            -- new lap
            self.oldSectorTime = 0
            self.splits[self.sectorIndex] = carState.lastSplits[self.sectorIndex]
        end
        self.sectorIndex = carState.currentSector
    end
end
