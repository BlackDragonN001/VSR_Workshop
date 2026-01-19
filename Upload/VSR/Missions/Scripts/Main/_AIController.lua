local _SaveLoad = require("_SaveLoad")

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

-- Register Save/Load for saveload system
_SaveLoad.RegisterSave("_AIController", function()
    return AIController
end)

_SaveLoad.RegisterLoad("_AIController", function(AIControllerData)
    if (AIControllerData ~= nil) then
        for k, v in pairs(AIControllerData) do
            AIController[k] = v
        end
    else
        print("WARNING: _AIController Load called with nil data")
    end
end)

function AIController.Setup()
    AIController.m_NumAIUnits = 0
    AIController.m_MaxAIUnits = GetVarItemInt("network.session.ivar9")
    AIController.m_AIUnitSkill = GetVarItemInt("network.session.ivar22")

    if (AIController.m_MaxAIUnits >= MAX_AI_UNITS) then
        AIController.m_MaxAIUnits = MAX_AI_UNITS
    end

    if (AIController.m_AIUnitSkill < 0 or AIController.m_AIUnitSkill > 4) then
        AIController.m_AIUnitSkill = 3
    end
end

function AIController.Update(ElapsedGameTime)
    if (AIController.m_MaxAIUnits <= 0) then
        return
    end

    local InitialSpawnInFrequency = 5

    if (ElapsedGameTime % InitialSpawnInFrequency == 0) then
        if (AIController.m_NumAIUnits < AIController.m_MaxAIUnits) then
            AIController.BuildBotCraft(AIController.m_NumAIUnits)
            AIController.m_NumAIUnits = AIController.m_NumAIUnits + 1
        else
            for i = 0, AIController.m_NumAIUnits - 1 do
                if (not IsNotDeadAndPilot(AIController.m_AICraftHandles[i])) then
                    SetLifespan(AIController.m_AICraftHandles[i], SNIPED_AI_LIFESPAN)
                    AIController.m_AICraftHandles[i] = nil
                end

                if (AIController.m_AICraftHandles[i] == nil) then
                    AIController.BuildBotCraft(i)
                    break
                end
            end
        end
    end

    for i = 0, AIController.m_NumAIUnits - 1 do
        if (bit32.band((ElapsedGameTime + i), 0x1F) == 0) then
            if (AIController.m_AILastWentForPowerup[i]) then
                local Target = AIController.m_AITargetHandles[i]
                AIController.m_PowerupGotoTime[i] = AIController.m_PowerupGotoTime[i] + 1
                if (not IsAlive(Target) or AIController.m_PowerupGotoTime[i] > 150 or GetDistance(AIController.m_AICraftHandles[i], AIController.m_AITargetHandles[i]) < 2.0) then
                    AIController.FindGoodAITarget(i)
                end
            end
        end
    end
end

function AIController.BuildBotCraft(index)
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

    AIController.m_AICraftHandles[index] = BuildObject(GetPlayerODF(APlayerTeam, Randomize_Any), theirTeam, Where)
    SetRandomHeadingAngle(AIController.m_AICraftHandles[index])
    SetNoScrapFlagByHandle(AIController.m_AICraftHandles[index])
    AddPilotByHandle(AIController.m_AICraftHandles[index])

    AIController.FindGoodAITarget(index)
end

function AIController.FindGoodAITarget(index)
    if (not IsAliveAndPilot(AIController.m_AICraftHandles[index])) then
        AIController.m_AICraftHandles[index] = nil
        return
    end

    local nearestEnemy = GetNearestEnemy(AIController.m_AICraftHandles[index])
    for i = 1, MAX_TEAMS - 1 do
        local PlayerH = GetPlayerHandle(i)
        -- Ignore any close-by pilots.
        if (nearestEnemy == PlayerH and IsAliveAndPilot(PlayerH)) then
            nearestEnemy = nil
        end
    end

    if (nearestEnemy ~= nil and not AIController.m_AILastWentForPowerup[index]) then
        local nearestPerson = GetNearestPerson(AIController.m_AICraftHandles[index], true, 100.0)
        local distToEnemy = GetDistance(AIController.m_AICraftHandles[index], nearestEnemy)

        if (nearestPerson ~= nil) then
            local distToPerson = GetDistance(AIController.m_AICraftHandles[index], nearestPerson)

            if (distToPerson < (distToEnemy * 1.2)) then
                Goto(AIController.m_AICraftHandles[index], nearestPerson)
                AIController.m_AILastWentForPowerup[index] = true
                AIController.m_PowerupGotoTime[index] = 0
                AIController.m_AITargetHandles[index] = nearestPerson
                return
            end
        end

        local nearestPowerup = GetNearestPowerup(AIController.m_AICraftHandles[index], true, 100.0)
        if (nearestPowerup ~= nil) then
            local distToPowerup = GetDistance(AIController.m_AICraftHandles[index], nearestPowerup)

            if (distToPowerup < (distToEnemy * 1.2)) then
                Goto(AIController.m_AICraftHandles[index], nearestPowerup)
                AIController.m_AILastWentForPowerup[index] = true
                AIController.m_PowerupGotoTime[index] = 0
                AIController.m_AITargetHandles[index] = nearestPowerup
                return
            end
        end
    end

    if (nearestEnemy == nil) then
        local BestDist = MAX_FLOAT
        local BestHandle = nil

        for i = 0, AIController.m_NumAIUnits - 1 do
            if (i == index) then
                break
            end

            if (not AIController.m_AICraftHandles[index]) then
                break
            end

            local ThisBotH = AIController.m_AICraftHandles[i]
            if (not IsAlive(ThisBotH)) then
                break
            end

            if (IsAlly(AIController.m_AICraftHandles[index], AIController.m_AICraftHandles[i])) then
                break
            end

            local MyH = AIController.m_AICraftHandles[index]
            local ThisDist = GetDistance(MyH, ThisBotH)

            if (ThisDist > 0.01 and ThisDist < BestDist) then
                BestDist = ThisDist
                BestHandle = AIController.m_AICraftHandles[i]
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

            local MyH = AIController.m_AICraftHandles[index]
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

    AIController.m_AITargetHandles[index] = nearestEnemy

    if (nearestEnemy ~= nil) then
        Attack(AIController.m_AICraftHandles[index], AIController.m_AITargetHandles[index])
    end

    AIController.m_AILastWentForPowerup[index] = false
end

function AIController.HandleHumanKilled()
    if (AIController.m_MaxAIUnits <= 0) then
        return
    end

    DoTaunt(TAUNTS_HumanShipDestroyed)
end

function AIController.HandleDeadObject(DeadObjectHandle)
    for i = 0, AIController.m_NumAIUnits - 1 do
        if (DeadObjectHandle == AIController.m_AICraftHandles[i]) then
            AIController.m_AICraftHandles[i] = nil
            AIController.BuildBotCraft(i)
            break
        end
    end
end

return AIController
