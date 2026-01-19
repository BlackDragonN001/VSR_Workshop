local _SaveLoad = require("_SaveLoad")
local ZonerODF = "ivscout_h_vsr"

Zoner = {
    Memorials = {
        "TimeVirus",
        "MrJuggs",
        "Slaor",
        "Judge_Mental"
    },

    Zoners = {}
}

-- Register Save/Load for saveload system
_SaveLoad.RegisterSave("_Zoner", function()
    return Zoner
end)

_SaveLoad.RegisterLoad("_Zoner", function(ZonerData)
    if (ZonerData ~= nil) then
        for k, v in pairs(ZonerData) do
            Zoner[k] = v
        end
    else
        print("WARNING: _Zoner Load called with nil data")
    end
end)

function Zoner.Spawn()
    for i = 1, #Zoner.Memorials do
        local name = Zoner.Memorials[i]
        local team = 10 + i

        if (Zoner.Zoners[name] == nil) then
            Zoner.Zoners[name] = {}
            Zoner.Zoners[name].Name = name
            Zoner.Zoners[name].Team = team
            Zoner.Zoners[name].Handle = Zoner.BuildZoner(name, team)
        elseif (not IsAliveAndPilot(Zoner.Zoners[name].Handle)) then
            Zoner.Zoners[name].Handle = Zoner.BuildZoner(name, team)
        end
    end
end

function Zoner.RunLogic()
    for k, v in pairs(Zoner.Zoners) do
        if (not IsAliveAndPilot(v.Handle)) then
            Zoner.Spawn()
        end
    end
end

function Zoner.BuildZoner(name, team)
    local unit = BuildObject(ZonerODF, team, GetSafestSpawnpoint())
    SetObjectiveName(unit, name)
    return unit
end

return Zoner
