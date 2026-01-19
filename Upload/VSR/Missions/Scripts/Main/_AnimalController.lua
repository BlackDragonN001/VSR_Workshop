local MAX_ANIMALS = 8

local _DLLUtils = require("_DLLUtils")

AnimalController = {
    m_NumAnimals = 0,     -- Current count of AIs spawned in
    m_MaxAnimals = 0,     -- Limit of AIs
    m_AnimalConfig = nil, -- HACK - storing a string in here.

    m_AnimalHandles = {},
}

function AnimalController:New()
    local newObj = {}

    newObj.m_NumAnimals = 0
    newObj.m_MaxAnimals = 0
    newObj.m_AnimalConfig = nil

    newObj.m_AnimalHandles = {}

    setmetatable(newObj, self)
    self.__index = self

    return newObj
end

function AnimalController:Setup()
    self.m_NumAnimals = 0
    self.m_MaxAnimals = GetVarItemInt("network.session.ivar27")

    if (self.m_MaxAnimals >= MAX_ANIMALS) then
        self.m_MaxAnimals = MAX_ANIMALS
    end

    if (self.m_MaxAnimals > 0) then
        self.m_AnimalConfig = _DLLUtils:GetCheckedNetworkSvar(12, NETLIST_Animals)

        if (self.m_AnimalConfig == nil or string.len(self.m_AnimalConfig) < 2) then
            self.m_AnimalConfig = "mcjak01"
        end
    end
end

function AnimalController:Update(ElapsedGameTime, GameTPS)
    if (self.m_MaxAnimals <= 0) then
        return
    end

    -- Have to manually check on animals  they won't trigger a call to
    -- DeadObject(). If any died, note that.
    for i = 0, self.m_NumAnimals - 1 do
        if (self.m_AnimalHandles[i] ~= nil) then
            local h = self.m_AnimalHandles[i]
            if (not IsAlive(h)) then
                self.m_AnimalHandles[i] = nil
            end
        end
    end

    -- Spawn in animals at the start of the game (staggered every 4 seconds)
    local InitialSpawnInFrequency = 4 * GameTPS -- GameTPS ticks per second

    if (ElapsedGameTime % InitialSpawnInFrequency == 0) then
        if (self.m_NumAnimals < self.m_MaxAnimals) then
            self:SetupAnimal(self.m_NumAnimals)
            self.m_NumAnimals = self.m_NumAnimals + 1
        else
            -- 'Full' set of animals. Do respawns as needed.
            for i = 0, self.m_NumAnimals - 1 do
                if (self.m_AnimalHandles[i] == nil) then
                    self:SetupAnimal(i)
                    break
                end
            end
        end
    end
end

-- Sets up the specified Animal unit, first time or later.
function AnimalController:SetupAnimal(index)
    local AnimalTeam = 8 + math.floor(GetRandomFloat(6))

    local Where = GetRandomSpawnpoint()
    -- Somewhere near the spawnpoint..
    Where = GetPositionNear(Where, AllyMinRadiusAway, AllyMaxRadiusAway)
    -- Bounce them up in the air a little
    Where.y = Where.y + 2 + GetRandomFloat(4)

    local AnimalODF = self.m_AnimalConfig
    self.m_AnimalHandles[index] = BuildObject(AnimalODF, AnimalTeam, Where)
    SetRandomHeadingAngle(self.m_AnimalHandles[index])
    SetNoScrapFlagByHandle(self.m_AnimalHandles[index])
end

return AnimalController
