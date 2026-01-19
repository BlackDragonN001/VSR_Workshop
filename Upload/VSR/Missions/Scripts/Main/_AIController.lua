local BotMinRadiusAway = 30.0
local BotMaxRadiusAway = 100.0

local FIRST_AI_TEAM = 11
local LAST_AI_TEAM = 15
local MAX_AI_UNITS = 256
local SNIPED_AI_LIFESPAN = 300.0

AIController = {
    m_AIUnitSkill = 0,           -- from ivar22, 0..3 or 4==random
    m_NumAIUnits = 0,            -- Current count of AIs spawned in
    m_MaxAIUnits = 0,            -- Limit of AIs

    m_AICraftHandles = {},       -- Index is 0 based.
    m_AITargetHandles = {},      -- Whom each of those is aiming at.
    m_AILastWentForPowerup = {}, -- flag saying they last went for

    m_PowerupGotoTime = {},      -- How much time has elapsed on their quest for a powerup
}

function AIController:New()
    local newObj = {}

    newObj.m_AIUnitSkill = 0
    newObj.m_NumAIUnits = 0
    newObj.m_MaxAIUnits = 0

    newObj.m_AICraftHandles = {}
    newObj.m_AITargetHandles = {}
    newObj.m_AILastWentForPowerup = {}

    newObj.m_PowerupGotoTime = {}

    setmetatable(newObj, self)
    self.__index = self

    return newObj
end

function AIController:Setup()
    self.m_NumAIUnits = 0
    self.m_MaxAIUnits = GetVarItemInt("network.session.ivar9")
    self.m_AIUnitSkill = GetVarItemInt("network.session.ivar22")

    if (self.m_MaxAIUnits >= MAX_AI_UNITS) then
        self.m_MaxAIUnits = MAX_AI_UNITS
    end

    if (self.m_AIUnitSkill < 0 or self.m_AIUnitSkill > 4) then
        self.m_AIUnitSkill = 3
    end
end

function AIController:Update(ElapsedGameTime)
    if (self.m_MaxAIUnits <= 0) then
        return
    end

    local InitialSpawnInFrequency = 5

    if (ElapsedGameTime % InitialSpawnInFrequency == 0) then
        if (self.m_NumAIUnits < self.m_MaxAIUnits) then
            self:BuildBotCraft(self.m_NumAIUnits)
            self.m_NumAIUnits = self.m_NumAIUnits + 1
        else
            for i = 0, self.m_NumAIUnits - 1 do
                if (not IsNotDeadAndPilot(self.m_AICraftHandles[i])) then
                    SetLifespan(self.m_AICraftHandles[i], SNIPED_AI_LIFESPAN)
                    self.m_AICraftHandles[i] = nil
                end

                if (self.m_AICraftHandles[i] == nil) then
                    self:BuildBotCraft(i)
                    break
                end
            end
        end
    end

    for i = 0, self.m_NumAIUnits - 1 do
        if (bit32.band((ElapsedGameTime + i), 0x1F) == 0) then
            if (self.m_AILastWentForPowerup[i]) then
                local Target = self.m_AITargetHandles[i]
                self.m_PowerupGotoTime[i] = self.m_PowerupGotoTime[i] + 1
                if (not IsAlive(Target) or self.m_PowerupGotoTime[i] > 150 or GetDistance(self.m_AICraftHandles[i], self.m_AITargetHandles[i]) < 2.0) then
                    self:FindGoodAITarget(i)
                end
            end
        end
    end
end

function AIController:BuildBotCraft(index)
    local NUM_AI_TEAMS = LAST_AI_TEAM - FIRST_AI_TEAM + 1
    local theirTeam = FIRST_AI_TEAM + (index % NUM_AI_TEAMS)
    local APlayerTeam = 1

    for i = 1, MAX_TEAMS - 1 do
        if (GetPlayerHandle(i) ~= nil) then
            APlayerTeam = i
        end
    end

    local Where = GetRandomSpawnpoint(theirTeam)
    Where = GetPositionNear(Where, BotMinRadiusAway, BotMaxRadiusAway)
    Where.y = Where.y + 2.0 + GetRandomFloat(4)

    self.m_AICraftHandles[index] = BuildObject(GetPlayerODF(APlayerTeam, Randomize_Any), theirTeam, Where)
    SetRandomHeadingAngle(self.m_AICraftHandles[index])
    SetNoScrapFlagByHandle(self.m_AICraftHandles[index])
    AddPilotByHandle(self.m_AICraftHandles[index])

    self:FindGoodAITarget(index)
end

function AIController:FindGoodAITarget(index)
    if (not IsAliveAndPilot(self.m_AICraftHandles[index])) then
        self.m_AICraftHandles[index] = nil
        return
    end

    local nearestEnemy = GetNearestEnemy(self.m_AICraftHandles[index])
    for i = 1, MAX_TEAMS - 1 do
        local PlayerH = GetPlayerHandle(i)
        -- Ignore any close-by pilots.
        if (nearestEnemy == PlayerH and IsAliveAndPilot(PlayerH)) then
            nearestEnemy = nil
        end
    end

    if (nearestEnemy ~= nil and not self.m_AILastWentForPowerup[index]) then
        local nearestPerson = GetNearestPerson(self.m_AICraftHandles[index], true, 100.0)
        local distToEnemy = GetDistance(self.m_AICraftHandles[index], nearestEnemy)

        if (nearestPerson ~= nil) then
            local distToPerson = GetDistance(self.m_AICraftHandles[index], nearestPerson)

            if (distToPerson < (distToEnemy * 1.2)) then
                Goto(self.m_AICraftHandles[index], nearestPerson)
                self.m_AILastWentForPowerup[index] = true
                self.m_PowerupGotoTime[index] = 0
                self.m_AITargetHandles[index] = nearestPerson
                return
            end
        end

        local nearestPowerup = GetNearestPowerup(self.m_AICraftHandles[index], true, 100.0)
        if (nearestPowerup ~= nil) then
            local distToPowerup = GetDistance(self.m_AICraftHandles[index], nearestPowerup)

            if (distToPowerup < (distToEnemy * 1.2)) then
                Goto(self.m_AICraftHandles[index], nearestPowerup)
                self.m_AILastWentForPowerup[index] = true
                self.m_PowerupGotoTime[index] = 0
                self.m_AITargetHandles[index] = nearestPowerup
                return
            end
        end
    end

    if (nearestEnemy == nil) then
        local BestDist = MAX_FLOAT
        local BestHandle = nil

        for i = 0, self.m_NumAIUnits - 1 do
            if (i == index) then
                break
            end

            if (not self.m_AICraftHandles[index]) then
                break
            end

            local ThisBotH = self.m_AICraftHandles[i]

            if (not IsAlive(ThisBotH)) then
                break
            end

            if (IsAlly(self.m_AICraftHandles[index], self.m_AICraftHandles[i])) then
                break
            end

            local MyH = self.m_AICraftHandles[index]
            local ThisDist = GetDistance(MyH, ThisBotH)

            if (ThisDist > 0.01 and ThisDist < BestDist) then
                BestDist = ThisDist
                BestHandle = self.m_AICraftHandles[i]
            end
        end

        for i = 1, MAX_TEAMS - 1 do
            local PlayerH = GetPlayerHandle(i)

            if (PlayerH == nil) then
                break
            end

            if (IsAliveAndPilot(PlayerH)) then
                break
            end

            local MyH = self.m_AICraftHandles[index]
            local ThisDist = GetDistance(MyH, PlayerH)

            if (ThisDist > 0.01 and ThisDist < BestDist) then
                BestDist = ThisDist
                BestHandle = PlayerH
            end
        end

        if (BestHandle ~= nil) then
            nearestEnemy = BestHandle
        end
    end

    self.m_AITargetHandles[index] = nearestEnemy

    if (nearestEnemy ~= nil) then
        Attack(self.m_AICraftHandles[index], self.m_AITargetHandles[index])
    end

    self.m_AILastWentForPowerup[index] = false
end

function AIController:HandleHumanKilled()
    if (self.m_MaxAIUnits <= 0) then
        return
    end

    DoTaunt(TAUNTS_HumanShipDestroyed)
end

function AIController:HandleDeadObject(DeadObjectHandle)
    for i = 0, self.m_NumAIUnits - 1 do
        if (DeadObjectHandle == self.m_AICraftHandles[i]) then
            self.m_AICraftHandles[i] = nil
            self:BuildBotCraft(i)
            break
        end
    end
end

return AIController
