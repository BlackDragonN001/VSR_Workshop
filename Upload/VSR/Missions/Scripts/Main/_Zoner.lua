local ZonerODF = "ivscout_h_vsr"

Zoner = {
    Name = '',
    Team = 0,
    Handle = nil,
    CurrentTarget = nil,
}

function Zoner:New(Name, Team)
    local o = {}
    o.Name = Name
    o.Team = Team or 0
    o.Handle = nil

    setmetatable(o, { __index = self })

    return o
end

function Zoner:Spawn()
    self.Handle = BuildObject(ZonerODF, self.Team, GetSafestSpawnpoint())
    SetObjectiveName(self.Handle, self.Name)
end

function Zoner:RunLogic()
    if (not IsAliveAndPilot(self.Handle)) then
        self:Spawn()
    end
end

return Zoner
