local MAX_ANIMALS = 8

local _SaveLoad = require("_SaveLoad")
require("")

AnimalController = {
    m_NumAnimals = 0,     -- Current count of AIs spawned in
    m_MaxAnimals = 0,     -- Limit of AIs
    m_AnimalConfig = nil, -- HACK - storing a string in here.

    m_AnimalHandles = {},
}

-- Register Save/Load for saveload system
_SaveLoad.RegisterSave("_AnimalController", function()
    return AnimalController
end)

_SaveLoad.RegisterLoad("_AnimalController", function(AnimalControllerData)
    if (AnimalControllerData ~= nil) then
        for k, v in pairs(AnimalControllerData) do
            AnimalController[k] = v
        end
    else
        print("WARNING: _AnimalController Load called with nil data")
    end
end)

function AnimalController.Setup()
    AnimalController.m_NumAnimals = 0
    AnimalController.m_MaxAnimals = GetVarItemInt("network.session.ivar27")

    if (AnimalController.m_MaxAnimals >= MAX_ANIMALS) then
        AnimalController.m_MaxAnimals = MAX_ANIMALS
    end

    if (AnimalController.m_MaxAnimals > 0) then
        AnimalController.m_AnimalConfig = GetCheckedNetworkSvar(12, NETLIST_Animals)
        if (AnimalController.m_AnimalConfig == nil or string.len(AnimalController.m_AnimalConfig) < 2) then
            AnimalController.m_AnimalConfig = "mcjak01"
        end
    end
end

function AnimalController.Update(ElapsedGameTime, GameTPS)
    if (AnimalController.m_MaxAnimals <= 0) then
        return
    end

    -- Have to manually check on animals  they won't trigger a call to
    -- DeadObject(). If any died, note that.
    for i = 0, AnimalController.m_NumAnimals - 1 do
        if (AnimalController.m_AnimalHandles[i] ~= nil) then
            local h = AnimalController.m_AnimalHandles[i]
            if (not IsAlive(h)) then
                AnimalController.m_AnimalHandles[i] = nil
            end
        end
    end

    -- Spawn in animals at the start of the game (staggered every 4 seconds)
    local InitialSpawnInFrequency = 4 * GameTPS -- GameTPS ticks per second

    if (ElapsedGameTime % InitialSpawnInFrequency == 0) then
        if (AnimalController.m_NumAnimals < AnimalController.m_MaxAnimals) then
            AnimalController.SetupAnimal(AnimalController.m_NumAnimals)
            AnimalController.m_NumAnimals = AnimalController.m_NumAnimals + 1
        else
            -- 'Full' set of animals. Do respawns as needed.
            for i = 0, AnimalController.m_NumAnimals - 1 do
                if (AnimalController.m_AnimalHandles[i] == nil) then
                    AnimalController.SetupAnimal(i)
                    break
                end
            end
        end
    end
end

-- Sets up the specified Animal unit, first time or later.
function AnimalController.SetupAnimal(index)
    local AnimalTeam = 8 + math.floor(GetRandomFloat(6))

    local Where = GetRandomSpawnpoint()
    -- Somewhere near the spawnpoint..
    Where = GetPositionNear(Where, AllyMinRadiusAway, AllyMaxRadiusAway)
    -- Bounce them up in the air a little
    Where.y = Where.y + 2 + GetRandomFloat(4)

    local AnimalODF = AnimalController.m_AnimalConfig
    AnimalController.m_AnimalHandles[index] = BuildObject(AnimalODF, AnimalTeam, Where)
    SetRandomHeadingAngle(AnimalController.m_AnimalHandles[index])
    SetNoScrapFlagByHandle(AnimalController.m_AnimalHandles[index])
end

return AnimalController
