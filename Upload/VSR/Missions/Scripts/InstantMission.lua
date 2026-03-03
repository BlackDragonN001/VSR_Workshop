--[[
    InstantMission.lua
    Converted from InstantMission.cpp
]]

-- Required Support Files
require('_GlobalHandler')
require('_GlobalVariables')
require('_DLLUtils')

local _StartingVehicles = require("_StartingVehicles")

-- Mission Table Definition
local Mission = {
    -- Constants (using globals where possible)

    -- Member Variables (from C++)
    m_GameTPS = 20, -- Default
    m_StartDone = false,
    m_TurnCounter = 0,
    m_ElapsedGameTime = 0,
    m_RemainingGameTime = 0, -- Not strictly in header but usually used
    m_EndCounter = 0,
    m_CompTeam = 6,
    m_StratTeam = 1,
    m_Difficulty = 1,
    m_GoalVal = 0,
    m_MyForce = 0,
    m_CompForce = 0,

    m_Recycler = {}, -- Handles
    m_SiegeOn = {},  -- Bools
    m_AntiAssault = {},
    m_LateGame = {},
    m_HaveArmory = {},
    m_SiegeCounter = {}, -- Ints
    m_AssaultCounter = {},

    m_CPUCommBunkerCount = {},
    m_CPUScavList = {}, -- Array of tables? or linear array?
    m_NumCPUScavs = {},

    m_LastTauntPrintedAt = -2000,
    m_LastCPUPlan = {},

    m_CPUTeamRace = {},
    m_HumanTeamRace = 0,
    m_AllyTeams = {},
    m_HasAllies = {},

    -- Objects
    m_Obj1 = nil,
    m_Powerup1 = nil,
    m_Powerup2 = nil,
    m_Powerup3 = nil,
    m_Powerup4 = nil,

    -- Custom AIP
    m_CustomAIPStr = "",
    m_SetFirstAIP = false,
    m_PastAIP0 = false,
}

-- Scavenger Constants
local MAX_CPU_SCAVS = 15
local MIN_CPU_SCAVS_AFTER_CLEANUP = 5

-- Helper: BuildStartingVehicle
function BuildStartingVehicle(aTeam, aRace, ODF1, ODF2, Where, aGrp, Variant)
    aGrp = aGrp or -1
    Variant = Variant or ""

    -- Sanitize Race
    if type(aRace) == "number" then aRace = string.char(aRace) end

    -- Path to Vector logic
    if type(Where) == "string" then
        if DoesPathExist(Where) then
            local points = GetPathPoints(Where)
            if points and points[1] then
                Where = points[1]
                Where.y = Where.y + 0.1
            else
                return nil -- Path exists but no points?
            end
        else
            return nil -- Path doesn't exist
        end
    end

    local TempODF = ODF1

    -- Helper to construct ODF name: Race + Substring(ODF, 2) + Variant
    local function ConstructName(base, r, v)
        if not base or base == "" then return "" end
        if string.len(base) < 1 then return "" end
        -- Replace first char with race
        return r .. string.sub(base, 2) .. v
    end

    local function ConstructNameSimple(base, r)
        if not base or base == "" then return "" end
        return r .. string.sub(base, 2)
    end

    local Try1 = ConstructName(ODF1, aRace, Variant)
    if not DoesODFExist(Try1) then
        Try1 = ConstructNameSimple(ODF1, aRace)
    end

    if not DoesODFExist(Try1) then
        -- Fallback to ODF2
        Try1 = ConstructName(ODF2, aRace, Variant)
        if not DoesODFExist(Try1) then
            Try1 = ConstructNameSimple(ODF2, aRace)
        end
    end

    local h = nil
    if DoesODFExist(Try1) then
        h = BuildObject(Try1, aTeam, Where)
        if h then
            if aGrp == -2 then
                SetBestGroup(h)
            elseif aGrp >= 0 then
                SetGroup(h, aGrp)
            end
        end
    end

    return h
end

-- Helper: SetCPUAIPlan
function SetCPUAIPlan(Type, Team)
    if Type < 0 or Type > 6 then Type = AIPType3 end

    if (Type > AIPType3) and (Mission.m_CPUCommBunkerCount[Team] == 0) and (Mission.m_LastCPUPlan[Team] <= AIPType3) then
        return
    end

    local AIPFile = ""
    local AIPString = (Mission.m_CustomAIPStr ~= "") and Mission.m_CustomAIPStr or "VSR_"

    local cpuRace = Mission.m_CPUTeamRace[Team]
    if type(cpuRace) == "number" then cpuRace = string.char(cpuRace) end

    local humanRace = Mission.m_HumanTeamRace
    if type(humanRace) == "number" then humanRace = string.char(humanRace) end

    -- _strnicmp(AIPString, "VSR_", 4) == 0
    if string.sub(string.upper(AIPString), 1, 4) == "VSR_" then
        local Random = math.floor(GetRandomFloat(3.0))
        if Random > 2 then Random = 2 end

        AIPFile = string.format("%s%s%d_%d.aip", AIPString, cpuRace, Team, Random)
        if not DoesFileExist(AIPFile) then
            AIPFile = string.format("%s%s%d_0.aip", AIPString, cpuRace, Team)
        end
    else
        -- Ext char
        local extChar = string.sub(AIPTypeExtensions, Type + 1, Type + 1)
        AIPFile = string.format("%s%s_%s.aip", AIPString, cpuRace, extChar)

        if not DoesFileExist(AIPFile) then
            AIPFile = string.format("%s%s%s%s.aip", AIPString, cpuRace, humanRace, extChar)
        end
    end

    SetAIP(AIPFile, Team)

    Mission.m_LastCPUPlan[Team] = Type

    if Mission.m_SetFirstAIP then
        DoTaunt(TAUNTS_Random)
    end

    Mission.m_SetFirstAIP = true
end

function AddCPUScav(scavHandle, Team)
    -- Initialize if new
    if not Mission.m_NumCPUScavs[Team] then Mission.m_NumCPUScavs[Team] = 0 end
    if not Mission.m_CPUScavList[Team] then Mission.m_CPUScavList[Team] = {} end

    if Mission.m_NumCPUScavs[Team] < MAX_CPU_SCAVS then
        Mission.m_NumCPUScavs[Team] = Mission.m_NumCPUScavs[Team] + 1
        Mission.m_CPUScavList[Team][Mission.m_NumCPUScavs[Team]] = scavHandle
    end

    if Mission.m_NumCPUScavs[Team] < MAX_CPU_SCAVS then
        return
    end

    DoTaunt(TAUNTS_Random)

    -- Cleanup logic
    local newScavList = {}
    local newScavListCount = 0

    for i = 1, Mission.m_NumCPUScavs[Team] do
        local checkScav = Mission.m_CPUScavList[Team][i]
        local keepIt = false

        if IsAround(checkScav) and (GetTeamNum(checkScav) == Mission.m_CompTeam) then
            local ObjClass = GetClassLabel(checkScav)
            if ObjClass then
                ObjClass = string.upper(ObjClass)
                keepIt = (ObjClass == "CLASS_SCAVENGER") or (ObjClass == "CLASS_SCAVENGERH")
            end
        end

        if checkScav == scavHandle then keepIt = true end

        if keepIt then
            newScavListCount = newScavListCount + 1
            newScavList[newScavListCount] = checkScav
        end
    end

    Mission.m_NumCPUScavs[Team] = newScavListCount
    Mission.m_CPUScavList[Team] = newScavList

    -- Cull if still too many
    while Mission.m_NumCPUScavs[Team] > MIN_CPU_SCAVS_AFTER_CLEANUP do
        local i = Mission.m_NumCPUScavs[Team] -- Lua 1-based, last element

        -- Find newest scav that isn't the current one (safety check)
        while (i > 1) and (Mission.m_CPUScavList[Team][i] == scavHandle) do
            i = i - 1
        end
        if Mission.m_CPUScavList[Team][i] == scavHandle then break end

        local killScav = Mission.m_CPUScavList[Team][i]
        SetNoScrapFlagByHandle(killScav, 1) -- SetNoScrapFlagByHandle
        SelfDamage(killScav, 1e28)

        table.remove(Mission.m_CPUScavList[Team], i)
        Mission.m_NumCPUScavs[Team] = Mission.m_NumCPUScavs[Team] - 1
    end
end

function SetupExtraVehicles()
    local pathNames = GetAiPaths() or {}
    local pathCount = #pathNames

    local cCPUTeamRace = Mission.m_CPUTeamRace[Mission.m_CompTeam]
    if type(cCPUTeamRace) == "number" then cCPUTeamRace = string.char(cCPUTeamRace) end

    local cHumanTeamRace = Mission.m_HumanTeamRace
    if type(cHumanTeamRace) == "number" then cHumanTeamRace = string.char(cHumanTeamRace) end

    for i = 1, MAX_TEAMS do
        Mission.m_NumCPUScavs[i] = 0
        Mission.m_CPUScavList[i] = {}
    end

    for i = 1, pathCount do
        local Label = pathNames[i]
        if string.sub(Label, 1, 3) == "mpi" then
            local pUnderscore = string.find(Label, "_")
            if pUnderscore then
                local ODF1, ODF2 = "", ""

                local pUnderscore2 = string.find(Label, "_", pUnderscore + 1)
                if not pUnderscore2 then
                    -- Only 1 underscore: mpic#_ivturr
                    ODF1 = string.sub(Label, pUnderscore + 1)
                else
                    -- 2 underscores: mpic#_ivturr_fvturr
                    ODF1 = string.sub(Label, pUnderscore + 1, pUnderscore2 - 1)
                    ODF2 = string.sub(Label, pUnderscore2 + 1)
                end

                -- Check for trailing underscores
                if string.sub(ODF1, -1) == "_" then ODF1 = string.sub(ODF1, 1, -2) end
                if string.sub(ODF2, -1) == "_" then ODF2 = string.sub(ODF2, 1, -2) end

                -- Construct with correct race char
                if string.sub(Label, 1, 4) == "mpic" then
                    -- Lowercase c: matching race only
                    local odf1Char = string.sub(ODF1, 1, 1)
                    local odf2Char = string.sub(ODF2, 1, 1)

                    if odf1Char == cCPUTeamRace then
                        BuildObject(ODF1, Mission.m_CompTeam, Label)
                    elseif odf2Char == cCPUTeamRace then
                        BuildObject(ODF2, Mission.m_CompTeam, Label)
                    end
                elseif string.sub(Label, 1, 4) == "mpiC" then
                    -- Uppercase C: force race
                    if ODF1 ~= "" then
                        ODF1 = cCPUTeamRace .. string.sub(ODF1, 2)
                        BuildObject(ODF1, Mission.m_CompTeam, Label)
                    elseif ODF2 ~= "" then
                        ODF2 = cCPUTeamRace .. string.sub(ODF2, 2)
                        BuildObject(ODF2, Mission.m_CompTeam, Label)
                    end
                elseif string.sub(Label, 1, 4) == "mpih" then
                    -- Lowercase h: matching human race
                    local h = nil
                    local odf1Char = string.sub(ODF1, 1, 1)
                    local odf2Char = string.sub(ODF2, 1, 1)

                    if odf1Char == cHumanTeamRace then
                        h = BuildObject(ODF1, Mission.m_StratTeam, Label)
                    elseif odf2Char == cHumanTeamRace then
                        h = BuildObject(ODF2, Mission.m_StratTeam, Label)
                    end
                    if h then SetBestGroup(h) end
                elseif string.sub(Label, 1, 4) == "mpiH" then
                    -- Uppercase H: force human race
                    local h = nil
                    if ODF1 ~= "" then
                        ODF1 = cHumanTeamRace .. string.sub(ODF1, 2)
                        h = BuildObject(ODF1, Mission.m_StratTeam, Label)
                    elseif ODF2 ~= "" then
                        ODF2 = cHumanTeamRace .. string.sub(ODF2, 2)
                        h = BuildObject(ODF2, Mission.m_StratTeam, Label)
                    end
                    if h then SetBestGroup(h) end
                end
            end
        end
    end
end

-- Helper: TestObjectives
function TestObjectives()
    if Mission.m_EndCounter == 0 then
        local NumFunctioningTeams = 0
        local TeamIsFunctioning = {} -- [MAX_TEAMS]
        local AlliesFunctioning = {} -- [MAX_TEAMS]
        for i = 1, MAX_TEAMS do
            TeamIsFunctioning[i] = false
            AlliesFunctioning[i] = false
        end

        for Team = 1, MAX_TEAMS do
            if Mission.m_Recycler[Team] then -- If we ever had a recycler
                local Functioning = false

                local TempH = Mission.m_Recycler[Team]
                if not IsAround(TempH) then
                    TempH = GetObjectByTeamSlot(Team, 1) -- DLL_TEAM_SLOT_RECYCLER = 1
                end

                local RecyH = nil
                if IsAround(TempH) then
                    RecyH = TempH
                else
                    RecyH = GetObjectByTeamSlot(Team, 1)
                end

                if RecyH then
                    Functioning = true
                else
                    Mission.m_Recycler[Team] = nil -- Clear it
                end

                if Functioning then
                    local allyTeam = Mission.m_AllyTeams[Team]
                    if allyTeam and allyTeam >= 1 and allyTeam <= MAX_TEAMS then
                        AlliesFunctioning[allyTeam] = true
                    end
                    TeamIsFunctioning[Team] = true
                end
            end
        end

        for i = 1, MAX_TEAMS do
            if AlliesFunctioning[i] then NumFunctioningTeams = NumFunctioningTeams + 1 end
        end

        if (NumFunctioningTeams == 0) and (Mission.m_ElapsedGameTime > (5 * Mission.m_GameTPS)) then
            DoTaunt(TAUNTS_HumanRecyDestroyed)
            FailMission(GetTime() + 5.0, "instantl.txt")
            Mission.m_EndCounter = Mission.m_EndCounter + 1
        elseif (NumFunctioningTeams == 1) then
            for i = 1, MAX_TEAMS do
                if AlliesFunctioning[Mission.m_AllyTeams[i]] then
                    if i == Mission.m_StratTeam then
                        DoTaunt(TAUNTS_CPURecyDestroyed)
                        SucceedMission(GetTime() + 5.0, "instantw.txt")
                        Mission.m_EndCounter = Mission.m_EndCounter + 1
                    else
                        DoTaunt(TAUNTS_HumanRecyDestroyed)
                        FailMission(GetTime() + 5.0, "instantl.txt")
                        Mission.m_EndCounter = Mission.m_EndCounter + 1
                    end
                    break
                end
            end
        end
    end
end

-- Helper: DoGenericStrategy
function DoGenericStrategy()
    Mission.m_TimeCount = Mission.m_TimeCount + 1

    if not Mission.m_StartDone then
        Mission.m_StartDone = true

        Mission.m_MyGoal = GetInstantGoal()
        Mission.m_CanRespawn = IFace_GetInteger("options.instant.bool0") ~= 0
        Mission.m_AwareV13 = IFace_GetInteger("options.instant.awarev13") ~= 0

        if Mission.m_AwareV13 then
            Mission.m_CustomAIPStr = IFace_GetString("options.instant.string0")

            for Team = Mission.m_CompTeam, MAX_TEAMS do
                if Team == Mission.m_CompTeam then
                    Mission.m_CPUTeamRace[Team] = IFace_GetInteger("options.instant.hisrace")
                else
                    Mission.m_CPUTeamRace[Team] = IFace_GetInteger("options.instant.int" .. Team)
                end

                Mission.m_AllyTeams[1] = IFace_GetInteger("options.instant.int16")
                if Mission.m_AllyTeams[1] <= 0 then Mission.m_AllyTeams[1] = 1 end

                for i = 6, MAX_TEAMS do
                    local ally = IFace_GetInteger("options.instant.int" .. (11 + i))
                    if ally <= 0 then ally = i - 4 end
                    Mission.m_AllyTeams[i] = ally
                end
            end

            Mission.m_HumanTeamRace = IFace_GetInteger("options.instant.myrace")

            for x = 1, MAX_TEAMS do
                for y = 1, MAX_TEAMS do
                    if (Mission.m_AllyTeams[x] > 0) and (x ~= y) and (Mission.m_AllyTeams[x] == Mission.m_AllyTeams[y]) then
                        Ally(x, y)
                        Mission.m_HasAllies[x] = true
                    end
                end
            end

            local PlayerH = GetPlayerHandle()
            if PlayerH then
                local PlayerTeam = GetTeamNum(PlayerH)
                local PlayerPos = GetPosition(PlayerH)

                local humanRaceChar = Mission.m_HumanTeamRace
                if type(humanRaceChar) == "number" then humanRaceChar = string.char(humanRaceChar) end

                local NewPlayerODF = string.format("%svscout_vsr", humanRaceChar)
                if not DoesODFExist(NewPlayerODF) then
                    NewPlayerODF = string.format("%svscout", humanRaceChar)
                end

                local OldODFName = GetCfg(PlayerH)
                if OldODFName and string.sub(OldODFName, 2, 2) == "s" then
                    NewPlayerODF = string.format("%spilo", humanRaceChar)
                end

                RemoveObject(PlayerH)
                local NewPlayerH = BuildObject(NewPlayerODF, PlayerTeam, PlayerPos)
                SetAsUser(NewPlayerH, PlayerTeam)
            end
        else
            local mySide = GetInstantMySide()
            if mySide == 1 then
                Mission.m_CPUTeamRace[Mission.m_CompTeam] = 102
                Mission.m_HumanTeamRace = 105
            else
                Mission.m_CPUTeamRace[Mission.m_CompTeam] = 105
                Mission.m_HumanTeamRace = 102
            end
        end

        Mission.m_MyForce = GetInstantMyForce() or 0
        Mission.m_CompForce = GetInstantCompForce() or 0
        Mission.m_Difficulty = GetInstantDifficulty() or 1

        if Mission.m_MyGoal == 0 then
            Mission.m_StratTeam = 3
            Ally(3, 1)
            Ally(1, 3)

            local atk = 0
            if Mission.m_CPUTeamRace[Mission.m_CompTeam] == 102 then
                atk = BuildObject("fvsent", Mission.m_CompTeam, "tankEnemy1")
            else
                atk = BuildObject("ivmisl", Mission.m_CompTeam, "tankEnemy1")
            end
            if IsAround(atk) then Attack(atk, GetPlayerHandle()) end
        else
            Mission.m_StratTeam = 1
        end

        SetupExtraVehicles()

        for Team = Mission.m_CompTeam, MAX_TEAMS do
            if Mission.m_CPUTeamRace[Team] then
                local SpawnPath = "Enemy_" .. Team
                local points = GetPathPoints(SpawnPath)
                if (not points) or (#points == 0) then
                    if Team > Mission.m_CompTeam then break end
                    SpawnPath = "RecyclerEnemy"
                end

                local CustomCPURecy = IFace_GetString("options.instant.string2")
                if not DoesODFExist(CustomCPURecy) then CustomCPURecy = "*vrecycpu" end

                local raceChar = Mission.m_CPUTeamRace[Team]
                if type(raceChar) == "number" then raceChar = string.char(raceChar) end

                if CustomCPURecy ~= "" then
                    Mission.m_Recycler[Team] = BuildStartingVehicle(Team, raceChar, CustomCPURecy, "*vrecy", SpawnPath)
                else
                    Mission.m_Recycler[Team] = BuildStartingVehicle(Team, raceChar, "*vrecycpu", "*vrecy", SpawnPath)
                end

                local AITeamName = "Computer Team " .. Team
                SetTeamNameForStat(Team, TranslateString("cfg", AITeamName) or AITeamName)

                local function ExtractVariant(recyName)
                    local pU1 = string.find(recyName, "_")
                    if not pU1 then return "" end
                    local pU2 = string.find(recyName, "_", pU1 + 1)
                    if pU2 then
                        return string.sub(recyName, pU2 + 1)
                    else
                        return string.sub(recyName, pU1 + 1)
                    end
                end
                local VariantName = ExtractVariant(CustomCPURecy)

                local RecPos = GetPosition(Mission.m_Recycler[Team])
                local posNear = GetPositionNear(RecPos, 30.0, 60.0)

                BuildStartingVehicle(Team, raceChar, "*vscav", "*vscav", posNear, -1, VariantName)
                BuildStartingVehicle(Team, raceChar, "*vturr", "*vturr", posNear, -1, VariantName)
                BuildStartingVehicle(Team, raceChar, "*vturr", "*vturr", posNear, -1, VariantName)

                if Mission.m_CompForce > 0 then
                    if Team == Mission.m_CompTeam then
                        BuildStartingVehicle(Team, raceChar, "*bspir", "*vturr", "gtow2", -1, VariantName)
                        BuildStartingVehicle(Team, raceChar, "*bspir", "*vturr", "gtow3", -1, VariantName)
                    end
                    BuildStartingVehicle(Team, raceChar, "*vsent", "*vscout", posNear, -1, VariantName)
                    BuildStartingVehicle(Team, raceChar, "*vsent", "*vscout", posNear, -1, VariantName)
                end

                if Mission.m_CompForce > 1 then
                    if Team == Mission.m_CompTeam then
                        BuildStartingVehicle(Team, raceChar, "*bspir", "*vturr", "gtow4", -1, VariantName)
                        BuildStartingVehicle(Team, raceChar, "*bspir", "*vturr", "gtow5", -1, VariantName)
                    end
                    BuildStartingVehicle(Team, raceChar, "*vtank", "*vtank", posNear, -1, VariantName)
                    BuildStartingVehicle(Team, raceChar, "*vtank", "*vtank", posNear, -1, VariantName)
                    BuildStartingVehicle(Team, raceChar, "*vtank", "*vtank", posNear, -1, VariantName)
                    BuildStartingVehicle(Team, raceChar, "*vtank", "*vtank", posNear, -1, VariantName)
                    BuildStartingVehicle(Team, raceChar, "*vsent", "*vscout", posNear, -1, VariantName)
                end
            end
        end

        local grp = -2
        local SpawnPath = "Player_1"
        local points = GetPathPoints(SpawnPath)
        if (not points) or (#points == 0) then SpawnPath = "Recycler" end

        local CustomHumanRecy = IFace_GetString("options.instant.string1")

        local humanRaceChar = Mission.m_HumanTeamRace
        if type(humanRaceChar) == "number" then humanRaceChar = string.char(humanRaceChar) end

        if CustomHumanRecy ~= "" then
            Mission.m_Recycler[Mission.m_StratTeam] = BuildStartingVehicle(Mission.m_StratTeam, humanRaceChar,
                CustomHumanRecy, "*vrecy", SpawnPath, grp)
        else
            Mission.m_Recycler[Mission.m_StratTeam] = BuildStartingVehicle(Mission.m_StratTeam, humanRaceChar, "*vrecy",
                "*vrecy", SpawnPath, grp)
        end

        local function ExtractVariant(recyName)
            local pU1 = string.find(recyName, "_")
            if not pU1 then return "" end
            local pU2 = string.find(recyName, "_", pU1 + 1)
            if pU2 then
                return string.sub(recyName, pU2 + 1)
            else
                return string.sub(recyName, pU1 + 1)
            end
        end
        local VariantName = ExtractVariant(CustomHumanRecy)

        local RecPos = GetPosition(Mission.m_Recycler[Mission.m_StratTeam])
        SetPosition(GetPlayerHandle(), GetPositionNear(RecPos, 30.0, 60.0))

        local posNear = GetPositionNear(RecPos, 30.0, 60.0)
        BuildStartingVehicle(Mission.m_StratTeam, humanRaceChar, "*vscav", "*vscav", posNear, grp, VariantName)
        BuildStartingVehicle(Mission.m_StratTeam, humanRaceChar, "*vturr", "*vturr", posNear, grp, VariantName)
        BuildStartingVehicle(Mission.m_StratTeam, humanRaceChar, "*vturr", "*vturr", posNear, grp, VariantName)

        if Mission.m_MyForce > 0 then
            BuildStartingVehicle(Mission.m_StratTeam, humanRaceChar, "*vturr", "*vturr", posNear, grp, VariantName)
            BuildStartingVehicle(Mission.m_StratTeam, humanRaceChar, "*vscout", "*vscout", posNear, grp, VariantName)
            BuildStartingVehicle(Mission.m_StratTeam, humanRaceChar, "*vscout", "*vscout", posNear, grp, VariantName)
            BuildStartingVehicle(Mission.m_StratTeam, humanRaceChar, "*vtank", "*vtank", posNear, grp, VariantName)
            BuildStartingVehicle(Mission.m_StratTeam, humanRaceChar, "*vtank", "*vtank", posNear, grp, VariantName)
        end

        if Mission.m_MyForce > 1 then
            BuildStartingVehicle(Mission.m_StratTeam, humanRaceChar, "*vscout", "*vscout", posNear, grp, VariantName)
            BuildStartingVehicle(Mission.m_StratTeam, humanRaceChar, "*vtank", "*vtank", posNear, grp, VariantName)

            grp = GetFirstEmptyGroup()
            BuildStartingVehicle(Mission.m_StratTeam, humanRaceChar, "*vtank", "*vtank", posNear, grp, VariantName)
            BuildStartingVehicle(Mission.m_StratTeam, humanRaceChar, "*vtank", "*vtank", posNear, grp, VariantName)
            BuildStartingVehicle(Mission.m_StratTeam, humanRaceChar, "*vtank", "*vtank", posNear, grp, VariantName)
        end

        if not Mission.m_AwareV13 then
            if Mission.m_MyGoal == 0 then
                if Mission.m_HumanTeamRace == 105 then
                    SetPlan("isdfteam.aip", Mission.m_StratTeam)
                else
                    SetPlan("scionteam.aip", Mission.m_StratTeam)
                end
            end
        end

        if not Mission.m_PastAIP0 then
            for Team = Mission.m_CompTeam, MAX_TEAMS do
                if IsAround(Mission.m_Recycler[Team]) then
                    SetCPUAIPlan(AIPType0, Team)
                end
            end
        end

        BuildObject("apammo", 0, "ammo1")
        BuildObject("apammo", 0, "ammo2")
        BuildObject("apammo", 0, "ammo3")
        BuildObject("aprepa", 0, "repair1")
        BuildObject("aprepa", 0, "repair2")
        BuildObject("aprepa", 0, "repair3")

        SetScrap(Mission.m_CompTeam, 40)
        SetScrap(1, 40)
    end

    if Mission.m_CompForce > 0 then
        local Turns, Amount = 0, 0
        if Mission.m_CompForce == 0 then
            Turns, Amount = Mission.m_GameTPS * 3, 1
        elseif Mission.m_CompForce == 1 then
            Turns, Amount = Mission.m_GameTPS * 2, 1
        elseif Mission.m_CompForce == 2 then
            Turns, Amount = Mission.m_GameTPS * 1, 1
        end
        if Turns > 0 and (Mission.m_TimeCount % Turns == 0) then
            for Team = Mission.m_CompTeam, MAX_TEAMS do
                AddScrap(Team, Amount)
            end
        end
    end

    if Mission.m_MyForce > 0 then
        local Turns, Amount = 0, 0
        if Mission.m_MyForce == 0 then
            Turns, Amount = Mission.m_GameTPS * 10, 1
        elseif Mission.m_MyForce == 1 then
            Turns, Amount = Mission.m_GameTPS * 8, 1
        elseif Mission.m_MyForce == 2 then
            Turns, Amount = Mission.m_GameTPS * 6, 1
        end

        if Turns > 0 and (Mission.m_TimeCount % Turns == 0) then
            AddScrap(Mission.m_StratTeam, Amount)
        end
    end

    if Mission.m_TimeCount % Mission.m_FriendReinforcementTime == 0 then
        BuildObject("apammo", 0, "ammo1")
        BuildObject("apammo", 0, "ammo2")
        BuildObject("apammo", 0, "ammo3")
        BuildObject("aprepa", 0, "repair1")
        BuildObject("aprepa", 0, "repair2")
        BuildObject("aprepa", 0, "repair3")
    end

    if Mission.m_MyGoal == 0 then
        Mission.m_PowerupCounter = (Mission.m_PowerupCounter or 0) + 1
        if Mission.m_PowerupCounter % (20 * Mission.m_GameTPS) == 0 then
            if not IsAround(Mission.m_Powerup1) then Mission.m_Powerup1 = BuildObject("apshdw", 0, "power1") end
            if not IsAround(Mission.m_Powerup2) then Mission.m_Powerup2 = BuildObject("apsstb", 0, "power2") end
            if not IsAround(Mission.m_Powerup3) then Mission.m_Powerup3 = BuildObject("apffld", 0, "power3") end
            if not IsAround(Mission.m_Powerup4) then Mission.m_Powerup4 = BuildObject("apspln", 0, "power4") end
        end
    end

    for Team = Mission.m_CompTeam, MAX_TEAMS do
        if IsAround(Mission.m_Recycler[Team]) then
            if not Mission.m_SiegeOn[Team] then
                -- Note: SIEGE_DISTANCE global
                local enemy = GetNearestEnemy(Mission.m_Recycler[Team], true, true, SIEGE_DISTANCE)
                if enemy then
                    Mission.m_SiegeCounter[Team] = Mission.m_SiegeCounter[Team] + 1
                else
                    Mission.m_SiegeCounter[Team] = 0
                end

                if Mission.m_SiegeCounter[Team] > (45 * Mission.m_GameTPS) then
                    Mission.m_SiegeOn[Team] = true
                    SetCPUAIPlan(AIPTypeS, Team)
                end
            else
                local enemy = GetNearestEnemy(Mission.m_Recycler[Team], true, true, SIEGE_DISTANCE)
                if not enemy then
                    SetCPUAIPlan(AIPTypeL, Team)
                    -- Check if plan set logic succeeded? Lua calling SetCPUAIPlan updates m_LastCPUPlan
                    if Mission.m_LastCPUPlan[Team] == AIPTypeL then
                        Mission.m_SiegeOn[Team] = false
                        Mission.m_SiegeCounter[Team] = 0
                    end
                end
            end

            -- Assault Test
            if (not Mission.m_LateGame[Team]) and (not Mission.m_SiegeOn[Team]) and (not Mission.m_AntiAssault[Team]) and (Mission.m_AssaultCounter[Mission.m_StratTeam] > 2) then
                Mission.m_AntiAssault[Team] = true
                SetCPUAIPlan(AIPTypeA, Team)
            else
                if Mission.m_AntiAssault[Team] and (Mission.m_AssaultCounter[Mission.m_StratTeam] < 3) then
                    Mission.m_AntiAssault[Team] = false
                    SetCPUAIPlan(AIPTypeL, Team)
                end
            end
        end
    end

    TestObjectives()
end

function InitialSetup()
    -- Do not auto group units.
    SetAutoGroupUnits(false)

    -- We want bot kill messages as this may be a coop mission.
    WantBotKillMessages()

    PreloadODF("ivrecy")
    PreloadODF("fvrecy")
	PreloadODF("evrecy")
	PreloadODF("cvrecy")
    PreloadODF("ivrecycpu")
    PreloadODF("fvrecycpu")
	PreloadODF("evrecycpu")
	PreloadODF("cvrecycpu")
end

function Start()
    Mission.m_StartDone = false
    Mission.m_TimeCount = 1
    Mission.m_FriendReinforcementTime = 2500
    Mission.m_EndCounter = 0
    Mission.m_CompTeam = 6
    Mission.m_StratTeam = 1
    Mission.m_Obj1 = nil
    Mission.m_TurnCounter = 0

    for i = 1, MAX_TEAMS do
        Mission.m_NumCPUScavs[i] = 0
        Mission.m_SiegeOn[i] = false
        Mission.m_AntiAssault[i] = false
        Mission.m_SiegeCounter[i] = 0
        Mission.m_LateGame[i] = false
        Mission.m_AssaultCounter[i] = 0
        Mission.m_HaveArmory[i] = false
        -- Init Handles
        Mission.m_Recycler[i] = nil
        Mission.m_AllyTeams[i] = 0
        Mission.m_HasAllies[i] = false
        Mission.m_CPUScavList[i] = {}
        Mission.m_LastCPUPlan[i] = 0
        Mission.m_CPUCommBunkerCount[i] = 0
    end

    Mission.m_Powerup1 = nil
    Mission.m_Powerup2 = nil
    Mission.m_Powerup3 = nil
    Mission.m_Powerup4 = nil
    Mission.m_LastTauntPrintedAt = -2000

    DoTaunt(TAUNTS_GameStart)
end

function AddObject(h)
    local ODFName = GetCfg(h) or ""
    local ObjClass = GetClassLabel(h) or ""
    ObjClass = string.upper(ObjClass)
    local Team = GetTeamNum(h)

    local IsCommBunker = (ObjClass == "CLASS_COMMBUNKER") or (ObjClass == "CLASS_COMMTOWER")
    if IsCommBunker and (Team == Mission.m_CompTeam) then
        Mission.m_CPUCommBunkerCount[Team] = (Mission.m_CPUCommBunkerCount[Team] or 0) + 1
    end

    local IsRecyVehicle = (ObjClass == "CLASS_RECYCLERVEHICLE") or (ObjClass == "CLASS_RECYCLERVEHICLEH") or
        (ObjClass == "CLASS_RECYCLER")
    if IsRecyVehicle then
        if not IsAround(Mission.m_Recycler[Team]) then
            Mission.m_Recycler[Team] = h
        end
    end

    if Team >= Mission.m_CompTeam then
        if (ObjClass == "CLASS_SCAVENGER") or (ObjClass == "CLASS_SCAVENGERH") then
            AddCPUScav(h, Team)
        end

        SetSkill(h, Mission.m_Difficulty + 1)
        AddToDispatch(h, 15.0, false, 0, false)
    elseif (Mission.m_MyGoal == 0) and (Team == Mission.m_StratTeam) then
        if (ObjClass == "CLASS_ARTILLERY") or (ObjClass == "CLASS_BOMBER") then
            for CTeam = Mission.m_CompTeam, MAX_TEAMS do
                if (not Mission.m_SiegeOn[CTeam]) and (not Mission.m_LateGame[CTeam]) then
                    Mission.m_LateGame[CTeam] = true
                    SetCPUAIPlan(AIPTypeL, CTeam)
                end
            end
        end

        if (ObjClass == "CLASS_HOVER") or (ObjClass == "CLASS_WINGMAN") or (ObjClass == "CLASS_MORPHTANK") or
            (ObjClass == "CLASS_ASSAULTTANK") or (ObjClass == "CLASS_SERVICE") or (ObjClass == "CLASS_WALKER") then
            SetTeamNum(h, 1)
        end
    end

    if Team == Mission.m_StratTeam then
        SetSkill(h, 3 - Mission.m_Difficulty)

        if ObjClass == "CLASS_RECYCLER" then
            if not Mission.m_PastAIP0 then
                Mission.m_PastAIP0 = true
                for CTeam = Mission.m_CompTeam, MAX_TEAMS do
                    if IsAround(Mission.m_Recycler[CTeam]) then
                        local stratchoice = Mission.m_TurnCounter % 2
                        if Mission.m_CPUTeamRace[CTeam] == 102 then
                            local choice = Mission.m_TurnCounter % 3
                            if choice == 0 then
                                SetCPUAIPlan(AIPType1, CTeam)
                            elseif choice == 1 then
                                SetCPUAIPlan(AIPType3, CTeam)
                            else
                                SetCPUAIPlan(AIPType2, CTeam)
                            end
                        else
                            local choice = Mission.m_TurnCounter % 2
                            if choice == 0 then
                                SetCPUAIPlan(AIPType1, CTeam)
                            else
                                SetCPUAIPlan(AIPType3, CTeam)
                            end
                        end
                    end
                end
            end
        else
            if (ObjClass == "CLASS_ASSAULTTANK") or (ObjClass == "CLASS_WALKER") then
                Mission.m_AssaultCounter[Team] = (Mission.m_AssaultCounter[Team] or 0) + 1
            end
        end
    end

    if (not Mission.m_PastAIP0) and (Mission.m_TurnCounter > (180 * Mission.m_GameTPS)) then
        Mission.m_PastAIP0 = true
        for CTeam = Mission.m_CompTeam, MAX_TEAMS do
            if IsAround(Mission.m_Recycler[CTeam]) then
                local stratchoice = Mission.m_TurnCounter % 2
                if stratchoice == 0 then
                    SetCPUAIPlan(AIPType1, CTeam)
                else
                    SetCPUAIPlan(AIPType3, CTeam)
                end
            end
        end
    end
end

function DeleteObject(h)
    local ObjClass = GetClassLabel(h) or ""
    ObjClass = string.upper(ObjClass)
    local Team = GetTeamNum(h)

    if Team == Mission.m_StratTeam then
        if (ObjClass == "CLASS_ASSAULTTANK") or (ObjClass == "CLASS_WALKER") then
            Mission.m_AssaultCounter[Team] = (Mission.m_AssaultCounter[Team] or 0) - 1
            if Mission.m_AssaultCounter[Team] < 0 then Mission.m_AssaultCounter[Team] = 0 end
        end
    else
        local IsCommBunker = (ObjClass == "CLASS_COMMBUNKER") or (ObjClass == "CLASS_COMMTOWER")
        if IsCommBunker then
            Mission.m_CPUCommBunkerCount[Team] = (Mission.m_CPUCommBunkerCount[Team] or 0) - 1
            if Mission.m_CPUCommBunkerCount[Team] < 0 then Mission.m_CPUCommBunkerCount[Team] = 0 end
        end
        if ObjClass == "CLASS_ARMORY" then
            Mission.m_HaveArmory[Team] = false
        end
    end
end

function PlayerEjected(DeadObjectHandle)
    return EJECTKILLRETCODES_DOEJECTPILOT
end

function PlayerDied(DeadObjectHandle, bSniped)
    if not IsPerson(DeadObjectHandle) then
        if not bSniped then return EJECTKILLRETCODES_DOEJECTPILOT end
    end

    if Mission.m_CanRespawn and IsAlive(Mission.m_Recycler[Mission.m_StratTeam]) then
        local Where = GetPosition(Mission.m_Recycler[Mission.m_StratTeam])
        Where = GetPositionNear(Where, 10.0, 50.0)
        Where.y = Where.y + 50.0

        local raceChar = Mission.m_HumanTeamRace
        if type(raceChar) == "number" then raceChar = string.char(raceChar) end

        local PlayerODF = string.format("%spilo", raceChar)
        local PlayerH = BuildObject(PlayerODF, 1, Where)
        SetAsUser(PlayerH, 1)
        AddPilotByHandle(PlayerH)

        DoTaunt(TAUNTS_HumanShipDestroyed)
    else
        FailMission(GetTime() + 3.0)
    end

    return EJECTKILLRETCODES_DLLHANDLED
end

function ObjectKilled(DeadObjectHandle, KillersHandle)
    if not IsPlayer(DeadObjectHandle) then
        if IsPerson(DeadObjectHandle) then return EJECTKILLRETCODES_DLLHANDLED end
        return EJECTKILLRETCODES_DOEJECTPILOT
    else
        return PlayerDied(DeadObjectHandle, false)
    end
end

function ObjectSniped(DeadObjectHandle, KillersHandle)
    if not IsPlayer(DeadObjectHandle) then
        return EJECTKILLRETCODES_DLLHANDLED
    else
        return PlayerDied(DeadObjectHandle, true)
    end
end

function PreGetIn(curWorld, pilotHandle, emptyCraftHandle)
    if curWorld ~= 0 then return 0 end

    if GetTeamNum(emptyCraftHandle) >= Mission.m_CompTeam then
        AddToDispatch(emptyCraftHandle, 15.0, false, 0, false)
    end
    return PREGETIN_ALLOW
end

function Update()
    Mission.m_ElapsedGameTime = Mission.m_ElapsedGameTime + 1
    Mission.m_TurnCounter = Mission.m_TurnCounter + 1
    Mission.m_Player = GetPlayerHandle()

    DoGenericStrategy()
end

function Save()
    return Mission
end

function Load(data)
    if data then
        Mission = data
    end
end
