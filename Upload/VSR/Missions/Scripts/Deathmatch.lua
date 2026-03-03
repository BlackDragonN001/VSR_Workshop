--[[
    Deathmatch01.lua
    Converted from Deathmatch01.cpp
    
    Deathmatch DLL code for a simple multiplay game. Requires map with
    spawnpoints, optional powerups. 
    
    Converted to new DLL interface spec by Nathan Mates 2/23/99
]]

-- Required Support Files
require('_GlobalHandler');
require('_GlobalVariables');
require('_DLLUtils');
local _PUPMgr = require('_PUPMgr')





-- Constants
local MAX_FLOAT = 3.4028e+38
local VEHICLE_SPACING_DISTANCE = 20.0

-- How many seconds sniped AI craft will stick around before
-- going boom.
local SNIPED_AI_LIFESPAN = 300.0

-- How far away a new craft will be from the old one
local RespawnMinRadiusAway = 10.0
local RespawnMaxRadiusAway = 20.0

-- How high up to respawn a pilot
local RespawnPilotHeight = 200.0

-- How far allies will be from the commander's position
local AllyMinRadiusAway = 10.0
local AllyMaxRadiusAway = 30.0

local BotMinRadiusAway = 30.0
local BotMaxRadiusAway = 100.0

-- Tuning distances for GetSpawnpointForTeam()

-- Friendly spawnpoint: Max distance away for ally
local FRIENDLY_SPAWNPOINT_MAX_ALLY = 100.0
-- Friendly spawnpoint: Min distance away for enemy
local FRIENDLY_SPAWNPOINT_MIN_ENEMY = 300.0

-- Random spawnpoint: min distance away for enemy
local RANDOM_SPAWNPOINT_MIN_ENEMY = 150.0

local FIRST_AI_TEAM = 11
local LAST_AI_TEAM = 15

-- ---------- Scoring Values-- these are delta scores, added to current score --------
local ScoreForKillingCraft = 5
local ScoreForKillingPerson = 5
local ScoreForDyingAsCraft = -1
local ScoreForDyingAsPerson = -1

-- Unlike Strat/MPI, these are always on.
local PointsForAIKill = true
local KillForAIKill = true

-- -----------------------------------------------

-- Enums / Subtypes


-- Helper array for race subtypes
local DMIsRaceSubtype = {
    [DMSubtype_Normal] = false,
    [DMSubtype_KOH] = false,
    [DMSubtype_CTF] = false,
    [DMSubtype_Race1] = true,
    [DMSubtype_Race2] = true,
    [DMSubtype_Loot] = false,
    [DMSubtype_Normal2] = false,
}

-- Max values
local MAX_AI_UNITS = 256
local MAX_ANIMALS = 8
local MAX_VEHICLES_TRACKED = (2 * MAX_TEAMS)

local Mission = {
    -- Member Variables
    m_GameTPS = 20,
    m_TotalGameTime = 0,
    m_ElapsedGameTime = 0,
    m_RemainingGameTime = 0,
    m_KillLimit = 0,
    m_MissionType = 0,
    m_RespawnType = 0,
    
    m_NumVehiclesTracked = 0,
    m_EmptyVehicles = {}, -- [MAX_VEHICLES_TRACKED]
    
    m_SpawnedAtTime = {}, -- [MAX_TEAMS]
    m_MaxSpawnKillTime = 0,
    
    m_LastTauntPrintedAt = 0,
    
    -- Race Variables
    m_NextRaceCheckpoint = {}, -- [MAX_TEAMS]
    m_TotalCheckpointsCompleted = {}, -- [MAX_TEAMS]
    m_TotalCheckpoints = 0,
    m_LapNumber = {}, -- [MAX_TEAMS]
    m_LastTeamInLead = -1, -- DPID_UNKNOWN or team index
    m_TotalRaceLaps = 0,
    m_RaceWinerCount = 0,
    m_RaceCheckpointRadius = 35.0,
    
    m_AIUnitSkill = 0,
    m_NumAIUnits = 0,
    m_MaxAIUnits = 0,
    m_NumAnimals = 0,
    m_MaxAnimals = 0,
    m_AnimalConfig = "mcjak01", -- string, formerly array
    
    m_AICraftHandles = {}, -- [MAX_AI_UNITS]
    m_AITargetHandles = {}, -- [MAX_AI_UNITS]
    m_PowerupGotoTime = {}, -- [MAX_AI_UNITS]
    m_AILastWentForPowerup = {}, -- [MAX_AI_UNITS]
    
    m_AnimalHandles = {}, -- [MAX_ANIMALS]
    
    m_RabbitTeam = 0,
    m_ForbidRabbitTeam = 0,
    m_RabbitShooterTeam = 0,
    m_RabbitMissingTurns = 0,
    m_RabbitTargetHandle = nil,
    m_RabbitShooterHandle = nil,
    m_RabbitWasHuman = false,
    m_RabbitShooterWasHuman = false,
    
    m_Gravity = 25,
    m_ScoreLimit = 0,
    
    m_DidOneTimeInit = false,
    m_FirstTime = true,
    m_GameWon = false,
    m_Flying = {}, -- [MAX_TEAMS]
    m_TeamIsSetUp = {}, -- [MAX_TEAMS]
    m_DMSetup = false,
    m_RaceIsSetup = false,
    m_HumansVsBots = false,
    m_RabbitMode = false,
    m_WeenieMode = false,
    m_ShipOnlyMode = false,
    m_RespawnAtLowAltitude = false,
    m_bIsFriendlyFireOn = false,
    m_bDidGameOverByScore = false,
    
    m_TeamPos = {}, -- [MAX_TEAMS] -> Vector (using table? or Vector object?)
    
    m_FRIENDLY_SPAWNPOINT_MAX_ALLY = FRIENDLY_SPAWNPOINT_MAX_ALLY,
    m_FRIENDLY_SPAWNPOINT_MIN_ENEMY = FRIENDLY_SPAWNPOINT_MIN_ENEMY,
    m_RANDOM_SPAWNPOINT_MIN_ENEMY = RANDOM_SPAWNPOINT_MIN_ENEMY,
    
    m_Flag1 = nil,
    m_Flag2 = nil,
    m_Carrier1 = nil,
    m_Carrier2 = nil,
    m_Base1 = nil,
    m_Base2 = nil,
    
    m_LastPlayerCraftHandle = {}, -- [MAX_TEAMS]
    
    StopScript = false,
}

-- Forward Declarations
local BuildBotCraft
local SetupAnimal
local ObjectifyFlag
local CrunchEmptyVehicleList
local UpdateEmptyVehicles
local AddEmptyVehicle
local ObjectifyRabbit
local SetNewRabbit
local ObjectifyRacePoint
local ExecuteRabbit
local ExecuteRace
local ExecuteWeenie
local ExecuteTrackPlayers
local UpdateGameTime
local UpdateAIUnits


-- Init Tables
for i = 0, MAX_TEAMS - 1 do
    Mission.m_SpawnedAtTime[i] = 0
    Mission.m_NextRaceCheckpoint[i] = 1
    Mission.m_TotalCheckpointsCompleted[i] = 0
    Mission.m_LapNumber[i] = 0
    Mission.m_Flying[i] = false
    Mission.m_TeamIsSetUp[i] = false
    Mission.m_TeamPos[i] = SetVector(0,0,0)
    Mission.m_LastPlayerCraftHandle[i] = nil
end

for i = 1, MAX_AI_UNITS do
    Mission.m_AICraftHandles[i] = nil
    Mission.m_AITargetHandles[i] = nil
    Mission.m_PowerupGotoTime[i] = 0
    Mission.m_AILastWentForPowerup[i] = false
end

for i = 1, MAX_ANIMALS do
    Mission.m_AnimalHandles[i] = nil
end

for i = 1, MAX_VEHICLES_TRACKED do
    Mission.m_EmptyVehicles[i] = nil
end

-- Helper Functions

local function GetRaceOfTeam(Team)
    -- In Lua we might have to reimplement this or assume it's bound.
    -- Calling C++: char GetRaceOfTeam(int)
    -- If it returns char, Lua handles it as number or string. 
    -- Assuming global function exists. If character code (int), convert to string?
    -- Actually GetRaceOfTeam seems to be a global C++ helper wrapped.
    -- If it returns number (ascii), we might need string.char.
    local r = _G.GetRaceOfTeam(Team)
    if type(r) == "number" then return string.char(r) end
    return r
end


function Save()
    Mission.PUPMgrData = _PUPMgr.Save()
    return Mission
end

function Load(data)
    if data then
        for k,v in pairs(data) do
            Mission[k] = v
        end
        if Mission.PUPMgrData then
            _PUPMgr.Load(Mission.PUPMgrData)
        end
    end
end

function InitialSetup()
    Mission.m_DidOneTimeInit = false
    Mission.m_FirstTime = true
    Mission.m_DMSetup = false
    
    -- Defaults (from C++ Init)
    Mission.m_RaceIsSetup = false
    Mission.m_GameTPS = 20
end

-- Helper: GetInitialFlagODF
local function GetInitialFlagODF(Race)
    local TempODFName = "ioflag01"
    if Race then TempODFName = Race .. string.sub(TempODFName, 2) end
    return TempODFName
end

-- Helper: GetInitialFlagStandODF
local function GetInitialFlagStandODF(Race)
    local TempODFName = "iostand01"
    if Race then TempODFName = Race .. string.sub(TempODFName, 2) end
    return TempODFName
end

-- Helper: GetInitialPlayerPilotODF
local function GetInitialPlayerPilotODF(Race)
    local TempODFName = "isuser"
    if Race then TempODFName = Race .. string.sub(TempODFName, 2) end
    return TempODFName
end

-- Helper: GetNextVehicleODF
local function GetNextVehicleODF(TeamNum, Randomize)
    local RType = 0 -- Randomize_None
    if Randomize then
        if Mission.m_RespawnType == 1 then RType = 1 -- Randomize_ByRace
        elseif Mission.m_RespawnType == 2 then RType = 2 -- Randomize_Any
        end
    end
    return GetPlayerODF(TeamNum, RType)
end

-- Helper: CreateObjectives
local function CreateObjectives()
    ClearObjectives()
    if Mission.m_MissionType == DMSubtype_Normal or Mission.m_MissionType == DMSubtype_Normal2 then
        AddObjective("mpobjective_dm.otf", "WHITE", -1.0)
    elseif Mission.m_MissionType == DMSubtype_CTF then
        AddObjective("mpobjective_dmctf.otf", "WHITE", -1.0)
    elseif Mission.m_MissionType == DMSubtype_KOH then
        AddObjective("mpobjective_dmkoth.otf", "WHITE", -1.0)
    elseif Mission.m_MissionType == DMSubtype_Loot then
        AddObjective("mpobjective_dmloot.otf", "WHITE", -1.0)
    elseif Mission.m_MissionType == DMSubtype_Race1 or Mission.m_MissionType == DMSubtype_Race2 then
        AddObjective("mpobjective_dmrace.otf", "WHITE", -1.0)
    else
        AddObjective("mpobjective_dm.otf", "WHITE", -1.0)
    end
end

-- Helper function for SetupTeam(), returns an appropriate spawnpoint.
function GetSpawnpointForTeam(Team)
    local spawnpointPosition = SetVector(0,0,0)
    
    -- Pick a random, ideally safe spawnpoint.
    local pSpawnPointInfo = GetAllSpawnpoints(Team)
    local count = #pSpawnPointInfo
    
    -- Designer didn't seem to put any spawnpoints on the map :(
    if count == 0 then
        return spawnpointPosition
    end
    
    -- First pass: see if a spawnpoint exists with this team #
    --
    -- Note: using a temporary array allocated on stack to keep track
    -- of indices.
    local pIndices = {}
    local indexCount = 0
    for i = 1, count do
        if pSpawnPointInfo[i].Team == Team then
            indexCount = indexCount + 1
            pIndices[indexCount] = i
        end
    end
    
    -- Did we find any spawnpoints in the above search? If so,
    -- randomize out of that list and return that
    if indexCount > 0 then
        local index = math.floor(GetRandomFloat(indexCount)) + 1
        return pSpawnPointInfo[pIndices[index]].Position
    end
    
    -- Second pass: build up a list of spawnpoints that appear to have
    -- allies close, randomly pick one of those.
    indexCount = 0
    for i = 1, count do
        if ((pSpawnPointInfo[i].DistanceToClosestSameTeam < Mission.m_FRIENDLY_SPAWNPOINT_MAX_ALLY) or 
            (pSpawnPointInfo[i].DistanceToClosestAlly < Mission.m_FRIENDLY_SPAWNPOINT_MAX_ALLY)) and 
           (pSpawnPointInfo[i].DistanceToClosestEnemy >= Mission.m_FRIENDLY_SPAWNPOINT_MIN_ENEMY) then
             indexCount = indexCount + 1
             pIndices[indexCount] = i
        end
    end
    
    -- Did we find any spawnpoints in the above search? If so,
    -- randomize out of that list and return that
    if indexCount > 0 then
        local index = math.floor(GetRandomFloat(indexCount)) + 1
        return pSpawnPointInfo[pIndices[index]].Position
    end
    
    -- Third pass: Make up a list of spawnpoints that appear to have
    -- no enemies close.
    indexCount = 0
    for i = 1, count do
        if pSpawnPointInfo[i].DistanceToClosestEnemy >= Mission.m_RANDOM_SPAWNPOINT_MIN_ENEMY then
             indexCount = indexCount + 1
             pIndices[indexCount] = i
        end
    end
    
    -- Did we find any spawnpoints in the above search? If so,
    -- randomize out of that list and return that
    if indexCount > 0 then
        local index = math.floor(GetRandomFloat(indexCount)) + 1
        return pSpawnPointInfo[pIndices[index]].Position
    end
    
    -- If here, all spawnpoints have an enemy within
    -- RANDOM_SPAWNPOINT_MIN_ENEMY.  Fallback to old code.
    return GetRandomSpawnpoint(Team)
end

function Init()
    -- Init Tables
    Mission.m_NextRaceCheckpoint = {}
    for i= 1, MAX_TEAMS do Mission.m_NextRaceCheckpoint[i] = 1 end
    
    Mission.RaceSetObjective = false
    
    -- Read from the map's .trn file whether we respawn at altitude or
    -- not.
    local mapName = GetMapTRNFilename()
    if mapName and mapName ~= "" then
        Mission.m_RespawnAtLowAltitude = GetODFBool(mapName, "DLL", "RespawnAtLowAltitude", false)
        Mission.m_RaceCheckpointRadius = GetODFFloat(mapName, "DLL", "CheckpointRadius", 35.0)
        Mission.m_FRIENDLY_SPAWNPOINT_MAX_ALLY = GetODFFloat(mapName, "DLL", "FriendlySpawnpointMaxAllyRange", FRIENDLY_SPAWNPOINT_MAX_ALLY)
        Mission.m_FRIENDLY_SPAWNPOINT_MIN_ENEMY = GetODFFloat(mapName, "DLL", "FriendlySpawnpointMinEnemyRange", FRIENDLY_SPAWNPOINT_MIN_ENEMY)
        Mission.m_RANDOM_SPAWNPOINT_MIN_ENEMY = GetODFFloat(mapName, "DLL", "RandomSpawnpointMinEnemyRange", RANDOM_SPAWNPOINT_MIN_ENEMY)
    end
    
    -- InitTaunts... (Not needed in Lua or implemented differently?)
    
    -- In EDITOR build, fill in some defaults
    -- (Skipped Editor block, assuming Network/Live logic)
    
    Mission.m_LastTeamInLead = -1 -- DPID_UNKNOWN
    
    Mission.m_KillLimit = GetVarItemInt("network.session.ivar0")
    Mission.m_TotalGameTime = GetVarItemInt("network.session.ivar1")
    -- Skip ivar2-- player limit. Assume the netmgr takes care of that.
    local MissionTypePrefs = GetVarItemInt("network.session.ivar7")
    Mission.m_TotalRaceLaps = GetVarItemInt("network.session.ivar9") -- Just in case we're using this
    Mission.m_Gravity = GetVarItemInt("network.session.ivar31")
    Mission.m_ScoreLimit = GetVarItemInt("network.session.ivar35")
    
    -- Set this for the server now. Clients get this set from Load().
    SetGravity(Mission.m_Gravity * 0.5)
    
    Mission.m_bIsFriendlyFireOn = (GetVarItemInt("network.session.ivar32") ~= 0)
    Mission.m_MaxSpawnKillTime = Mission.m_GameTPS * GetVarItemInt("network.session.ivar13") -- convert seconds to 1/10 ticks
    if Mission.m_MaxSpawnKillTime < 0 then Mission.m_MaxSpawnKillTime = 0 end -- sanity check
    
    Mission.m_MissionType = bit32.band(MissionTypePrefs, 0xFF)
    Mission.m_RespawnType = bit32.band(bit32.rshift(MissionTypePrefs, 8), 0xFF) -- (MissionTypePrefs>>8) & 0xFF
    
    Mission.m_NumAIUnits = 0
    Mission.m_MaxAIUnits = 0
    if not DMIsRaceSubtype[Mission.m_MissionType] then
        Mission.m_MaxAIUnits = GetVarItemInt("network.session.ivar9")
        if Mission.m_MaxAIUnits >= MAX_AI_UNITS then Mission.m_MaxAIUnits = MAX_AI_UNITS end
        
        -- #if 0//def _DEBUG
        -- if Mission.m_MaxAIUnits > 0 then Mission.m_MaxAIUnits = 8 end
        -- #endif
        
        -- If the network is not on, this map was probably started from the
        -- commandline, and therefore, ivars are not at the defaults expected.
        -- Switch to some sane defaults.
        if not IsNetworkOn() then
            Mission.m_MaxAIUnits = 0
            Mission.m_Gravity = 25 -- default
            SetGravity(Mission.m_Gravity * 0.5)
        end
    end
    
    Mission.m_AIUnitSkill = GetVarItemInt("network.session.ivar22")
    if (Mission.m_AIUnitSkill < 0) or (Mission.m_AIUnitSkill > 4) then Mission.m_AIUnitSkill = 3 end
    
    if not IsNetworkOn() then Mission.m_AIUnitSkill = 3 end
    
    Mission.m_HumansVsBots = (GetVarItemInt("network.session.ivar16") ~= 0)
    
    -- If it's vs bots, make all humans allied (but not with animals (team 13))
    if Mission.m_HumansVsBots then
        for i = 1, 11 do
            for j = 1, 11 do
                if i ~= j then Ally(i, j) end
            end
        end
    end
    
    Mission.m_RabbitMode = (GetVarItemInt("network.session.ivar23") ~= 0)
    Mission.m_WeenieMode = (GetVarItemInt("network.session.ivar19") ~= 0)
    Mission.m_ShipOnlyMode = (GetVarItemInt("network.session.ivar25") ~= 0)
    
    Mission.m_NumAnimals = 0
    Mission.m_MaxAnimals = GetVarItemInt("network.session.ivar27")
    if Mission.m_MaxAnimals >= MAX_ANIMALS then Mission.m_MaxAnimals = MAX_ANIMALS end
    
    if Mission.m_MaxAnimals > 0 then
        -- pAnimalConfig = DLLUtils::GetCheckedNetworkSvar...
        -- Assuming fixed for now or port GetCheckedNetworkSvar
        Mission.m_AnimalConfig = "mcjak01" 
    end
    
    local PlayerEntryH = GetPlayerHandle()
    -- As the .bzn has a vehicle which may not be appropriate, we
    -- must zap that player object and recreate them the way we want
    -- them when the game starts up.
    if PlayerEntryH then RemoveObject(PlayerEntryH) end
    
    -- Do One-time server side init of varbs for everyone
    if ImServer() or (not IsNetworkOn()) then
        if Mission.m_RemainingGameTime <= 0 then
             Mission.m_RemainingGameTime = Mission.m_TotalGameTime * 60 * Mission.m_GameTPS -- convert minutes to 1/10 seconds
        end
        
        -- And build local player
        local LocalTeamNum = GetLocalPlayerTeamNumber() -- Query this from game
        local PlayerH = SetupPlayer(LocalTeamNum)
        SetAsUser(PlayerH, LocalTeamNum)
        AddPilotByHandle(PlayerH)
        
        -- First player becomes the rabbit target
        if Mission.m_RabbitMode and (not Mission.m_RabbitTargetHandle) then
             SetNewRabbit(PlayerH) -- Need to ensure SetNewRabbit is defined before this or declared global
        end
    end
    
    -- Throw up Objectives.
    CreateObjectives()
    
    _PUPMgr.Init()

    Mission.m_FirstTime = false
    Mission.m_DidOneTimeInit = true
end

-- Sets up the side's commander's extra vehicles, such a recycler or
-- more. Does *not* create the player vehicle for them, 
-- however. [That's to be done in SetupPlayer.] Safe to be called
-- multiple times for each player on that team. 
--
-- If Teamplay is off, this function is called once per player.
--
-- If Teamplay is on, this function is called only on the
-- _defensive_ team number for an alliance. 
function SetupTeam(Team)
    -- Sanity checks: don't do anything that looks invalid
    if (Team < 0) or (Team >= MAX_TEAMS) then return end

    -- Also, if we've already set up this team group, don't do anything
    if IsTeamplayOn() and Mission.m_TeamIsSetUp[Team] then return end
    
    local TeamRace = GetRaceOfTeam(Team)
    
    if IsTeamplayOn() then
        SetMPTeamRace(WhichTeamGroup(Team), TeamRace) -- Lock this down to prevent changes.
    end
    
    local Where = SetVector(0,0,0)
    
    if DMIsRaceSubtype[Mission.m_MissionType] then
        -- Race-- everyone starts off at spawnpoint 0's position
        Where = GetSpawnpoint(0)
    elseif Mission.m_MissionType == DMSubtype_CTF then
        -- CTF-- find spawnpoint by team # 
        Where = GetSpawnpointForTeam(Team)
        -- And randomize around the spawnpoint slightly so we'll
        -- hopefully never spawn in two pilots in the same place
        Where = GetPositionNear(Where, AllyMinRadiusAway, AllyMaxRadiusAway)
    else
        Where = GetSpawnpointForTeam(Team)
        -- And randomize around the spawnpoint slightly so we'll
        -- hopefully never spawn in two pilots in the same place
        Where = GetPositionNear(Where, AllyMinRadiusAway, AllyMaxRadiusAway)
    end
    
    -- Store position we created them at for later
    Mission.m_TeamPos[Team] = Where -- Copy vector
    
    -- Find location to place flag at
    if Mission.m_MissionType == DMSubtype_CTF then
         -- CTF
         -- Find place to drop flag from AIPaths list
         local DesiredName = string.format("base%d", Team)
         local DesiredName2 = string.format("m_base%d", Team)
         
         local pathNames = GetAiPaths() or {}
         for i = 1, #pathNames do
             local label = pathNames[i]
             if label == DesiredName then
                 local FlagH = nil
                 local BaseH = GetHandle(DesiredName2) -- First look for an existing base. -GBD
                 if not BaseH then
                     BaseH = BuildObject(GetInitialFlagStandODF(TeamRace), Team, label) -- Build race specific base. -GBD
                 end
                 SetAnimation(BaseH, "loop", 0)
                 
                 if BaseH then
                     FlagH = BuildObject(GetInitialFlagODF(TeamRace), Team, BaseH) -- Place directly ontop of flag stand. -GBD
                 else
                     FlagH = BuildObject(GetInitialFlagODF(TeamRace), Team, label)
                 end
                 SetAnimation(FlagH, "loop", 0)
                 
                 if Team == 1 then
                     Mission.m_Base1 = BaseH
                     Mission.m_Flag1 = FlagH
                 elseif Team == 6 then
                     Mission.m_Base2 = BaseH
                     Mission.m_Flag2 = FlagH
                 end
             end
         end
    elseif DMIsRaceSubtype[Mission.m_MissionType] and (not Mission.m_RaceIsSetup) then
        -- Race. Gotta grab spawnpoint locations
        -- #if 0 Logic skipped
        local intCheckpointCount = 0
        local hdlCheckpoint = nil
        repeat
            intCheckpointCount = intCheckpointCount + 1
            local cpName = string.format("checkpoint%d", intCheckpointCount)
            hdlCheckpoint = GetHandle(cpName)
        until (not hdlCheckpoint)
        Mission.m_TotalCheckpoints = intCheckpointCount - 1
        Mission.m_RaceIsSetup = true
    end
    
    if IsTeamplayOn() then
        local first = GetFirstAlliedTeam(Team)
        local last = GetLastAlliedTeam(Team)
        for i = first, last do
            if i ~= Team then
                 -- Get a new position near the team's central position
                 local NewPosition = GetPositionNear(Where, AllyMinRadiusAway, AllyMaxRadiusAway)
                 -- In teamplay, store where offense players were created for respawns later
                 Mission.m_TeamPos[i] = NewPosition
            end
        end
    end
    
    Mission.m_TeamIsSetUp[Team] = true
end

function SetupPlayer(Team)
    local PlayerH = nil
    local Where = SetVector(0,0,0)
    
    if (Team < 0) or (Team >= MAX_TEAMS) then return nil end -- Sanity check... do NOT proceed
    
    Mission.m_SpawnedAtTime[Team] = Mission.m_ElapsedGameTime -- Note when they spawned in.
    
    local TeamBlock = WhichTeamGroup(Team)
    
    if (not IsTeamplayOn()) or (TeamBlock < 0) then
        if DMIsRaceSubtype[Mission.m_MissionType] then
            Where = GetSpawnpoint(0) -- Start at spawnpoint 0
        else
            Where = GetRandomSpawnpoint()
        end
        
        -- And randomize around the spawnpoint slightly so we'll
        -- hopefully never spawn in two pilots in the same place
        Where = GetPositionNear(Where, AllyMinRadiusAway, AllyMaxRadiusAway)
        Where.y = Where.y + 1.0
        
        -- This player is their own commander; set up their equipment.
        SetupTeam(Team)
    else
        -- Teamplay. Gotta put them near their commander. Also, always
        -- ensure the recycler/etc has been set up for this team if we
        -- know who they are
        SetupTeam(GetCommanderTeam(Team))
        
        -- SetupTeam will fill in the m_TeamPos[] array of positions
        -- for both the commander and offense players, so read out the
        -- results
        Where = Mission.m_TeamPos[Team]
        Where.y = TerrainFindFloor(Where.x, Where.z) + 1.0
    end
    
    if DMIsRaceSubtype[Mission.m_MissionType] then
        -- Race. Start off near spawnpoint 0
        Where = GetSpawnpoint(0)
        Where = GetPositionNear(Where, AllyMinRadiusAway, AllyMaxRadiusAway)
        Where.y = Where.y + 1.0
        Mission.m_NextRaceCheckpoint[Team] = 1 -- Heading towards sp 1
        Mission.m_TotalCheckpointsCompleted[Team] = 0 -- None so far
        Mission.m_LapNumber[Team] = 0 -- None so far
        Mission.m_RaceWinerCount = 0 -- None so far
        Mission.RaceSetObjective = false
    end
    
    PlayerH = BuildObject(GetPlayerODF(Team), Team, Where)
    if not DMIsRaceSubtype[Mission.m_MissionType] then
        SetRandomHeadingAngle(PlayerH)
    end
    SetNoScrapFlagByHandle(PlayerH)
    -- Added to make your starting pilot match respawning pilot. -GBD
    SetPilotClass(PlayerH, GetInitialPlayerPilotODF(GetRaceOfTeam(Team)))
    
    -- If on team 0 (dedicated server team), make this object gone from the world
    if Team == 0 then MakeInert(PlayerH) end
    
    if IsTeamplayOn() and (TeamBlock >= 0) then
        -- Also set up the other side too now, in case it wasn't done earlier.
        -- This puts both CTF flags on the map when the first player joins.
        SetupTeam(7 - GetCommanderTeam(Team))
    end
    
    return PlayerH
end

function Start()
    InitialSetup()
end

function AddObject(h)
    if not Mission.StopScript then
        -- LuaMission::AddObject(h); -- Implicit in Lua setup usually
    end

    -- Changed NM 11/22/01 - all AI is at skill 3 now by default.
    if not IsPlayer(h) then
        -- Always get a random # to keep things in sync
        local UseSkill = math.floor(GetRandomFloat(4)) -- 0 to 3.99 -> 0,1,2,3
        if UseSkill == 4 then UseSkill = 3 end
        
        if Mission.m_AIUnitSkill < 4 then
            UseSkill = Mission.m_AIUnitSkill
        end
        
        SetSkill(h, UseSkill)
        
        -- #if 0//def _DEBUG
        -- local t = GetTeamNum(h)
        -- if t > 1 then
        --    SetCurHealth(h, GetCurHealth(h) * 0.5) -- GetCurHealth(h) >> 1
        --    SetMaxHealth(h, GetCurHealth(h) * 0.5)
        -- end
        -- #endif
    end
end

function DeleteObject(h)
    if not Mission.StopScript then
        -- LuaMission::DeleteObject(h); -- Implicit
    end
end

function AddPlayer(id, Team, IsNewPlayer)
    if IsNewPlayer then
        local PlayerH = SetupPlayer(Team)
        SetAsUser(PlayerH, Team)
        AddPilotByHandle(PlayerH)
        SetNoScrapFlagByHandle(PlayerH)
    end
end

function DeletePlayer(id)
end

function RespawnPilot(DeadObjectHandle, Team)
    local Where = SetVector(0,0,0)
    local RespawnInVehicle = GetRespawnInVehicle() or (Mission.m_RabbitMode and (DeadObjectHandle == Mission.m_RabbitTargetHandle))
    
    if Mission.m_RabbitMode and (DeadObjectHandle == Mission.m_RabbitTargetHandle) then
        Mission.m_ForbidRabbitTeam = Mission.m_RabbitTeam
        Mission.m_RabbitTargetHandle = nil
    end
    
    if DMIsRaceSubtype[Mission.m_MissionType] then
        local LastSpawnAt = Mission.m_NextRaceCheckpoint[Team] - 1
        if LastSpawnAt > 0 then
            local cpName = string.format("checkpoint%d", LastSpawnAt)
            local hCp = GetHandle(cpName)
            if hCp then
                Where = GetPosition(hCp)
            else
                Where = GetSpawnpoint(0)
            end
        else
            Where = GetSpawnpoint(0)
        end
    elseif (not IsTeamplayOn()) or (Team < 1) then
        Where = GetRandomSpawnpoint()
        Where = GetPositionNear(Where, AllyMinRadiusAway, AllyMaxRadiusAway)
    else
        Where = Mission.m_TeamPos[Team]
        Where = GetPositionNear(Where, AllyMinRadiusAway, AllyMaxRadiusAway)
    end
    
    if (Team > 0) and (Team < MAX_TEAMS) then
        Mission.m_SpawnedAtTime[Team] = Mission.m_ElapsedGameTime
    end
    
    Where = GetPositionNear(Where, RespawnMinRadiusAway, RespawnMaxRadiusAway)
    
    if (not RespawnInVehicle) and (not Mission.m_RespawnAtLowAltitude) then
        Where.y = Where.y + RespawnPilotHeight
    end
    
    local NewPerson = nil
    if RespawnInVehicle then
        NewPerson = BuildObject(GetNextVehicleODF(Team, true), Team, Where)
    else
        local NextVehicle = GetNextVehicleODF(Team, true)
        if string.sub(NextVehicle, 2, 2):lower() == "s" then
            NewPerson = BuildObject(NextVehicle, Team, Where)
        else
            local Race = GetRaceOfTeam(Team)
            NewPerson = BuildObject(GetInitialPlayerPilotODF(Race), Team, Where)
        end
    end
    
    SetAsUser(NewPerson, Team)
    SetNoScrapFlagByHandle(NewPerson)
    AddPilotByHandle(NewPerson)
    SetRandomHeadingAngle(NewPerson)
    
    if not RespawnInVehicle then
        Mission.m_Flying[Team] = true
    end
    
    if Team == 0 then MakeInert(NewPerson) end
end

function DeadObject(DeadObjectHandle, KillersHandle, WasDeadPerson, WasDeadAI)
    -- local ODFName = GetODF(DeadObjectHandle) -- removed unused
    
    local KilledRabbit = false
    local UseRabbitScoring = false
    local Wasm_RabbitShooterHandle = (DeadObjectHandle == Mission.m_RabbitShooterHandle)
    
    if Mission.m_RabbitMode and (KillersHandle ~= Mission.m_RabbitTargetHandle) then
        UseRabbitScoring = true
        KilledRabbit = (DeadObjectHandle == Mission.m_RabbitTargetHandle)
        if KilledRabbit then
            SetObjectiveOff(Mission.m_RabbitTargetHandle)
            local RabbitH = KillersHandle
            if IsAlive(RabbitH) then
                -- SetNewRabbit handles it later/elsewhere? 
                -- C++ calls SetNewRabbit here. I need to define it or call it.
                -- I'll define SetNewRabbit later and assume it works.
                SetNewRabbit(RabbitH) 
            else
                RabbitH = Mission.m_RabbitShooterHandle
                if IsAlive(RabbitH) then SetNewRabbit(RabbitH) end 
            end
        end
    end
    
    local DeadTeam = GetTeamNum(DeadObjectHandle)
    local IsSpawnKill = false
    local SpawnKillMultiplier = 1
    local KillerIsAI = not IsPlayer(KillersHandle)
    
    if (DeadObjectHandle ~= KillersHandle) and (DeadTeam > 0) and (DeadTeam < MAX_TEAMS) and (Mission.m_SpawnedAtTime[DeadTeam] > 0) then
         if (Mission.m_ElapsedGameTime - Mission.m_SpawnedAtTime[DeadTeam]) < Mission.m_MaxSpawnKillTime then
             IsSpawnKill = true
         end
    end
    
    if UseRabbitScoring and (not KilledRabbit) then
        SpawnKillMultiplier = -1
    elseif UseRabbitScoring and KilledRabbit then
        SpawnKillMultiplier = -1
    elseif IsSpawnKill then
        SpawnKillMultiplier = -1
    end
    
    local ObjClass = GetClassLabel(DeadObjectHandle)
    local isTorpedo = (ObjClass == "CLASS_TORPEDO")
    
    if (DeadTeam ~= 0) and (not IsPowerup(DeadObjectHandle)) and (not isTorpedo) then
         if (DeadObjectHandle ~= KillersHandle) and (not IsAlly(DeadObjectHandle, KillersHandle)) then
             if (not WasDeadAI) or KillForAIKill then
                 AddKills(KillersHandle, 1 * SpawnKillMultiplier)
             end
             
             if Mission.m_MissionType == DMSubtype_Normal or Mission.m_MissionType == DMSubtype_Normal2 then
                 if (not WasDeadAI) or PointsForAIKill then
                     if WasDeadPerson then
                         AddScore(KillersHandle, ScoreForKillingPerson * SpawnKillMultiplier)
                     else
                         AddScore(KillersHandle, ScoreForKillingCraft * SpawnKillMultiplier)
                     end
                 end
             end
         else
             if (not WasDeadAI) or KillForAIKill then
                 AddKills(KillersHandle, -1 * SpawnKillMultiplier)
             end
             
             if UseRabbitScoring and (not KilledRabbit) then
                 SpawnKillMultiplier = 0
             end
             
             if Mission.m_MissionType == DMSubtype_Normal or Mission.m_MissionType == DMSubtype_Normal2 then
                 if (not WasDeadAI) or PointsForAIKill then
                     if WasDeadPerson then
                         AddScore(KillersHandle, -ScoreForKillingPerson * SpawnKillMultiplier)
                     else
                         AddScore(KillersHandle, -ScoreForKillingCraft * SpawnKillMultiplier)
                     end
                 end
             end
         end
         
         if not WasDeadAI then
             if UseRabbitScoring and (not KilledRabbit) then SpawnKillMultiplier = 0 end
             AddDeaths(DeadObjectHandle, 1 * SpawnKillMultiplier)
             
             if Mission.m_MissionType == DMSubtype_Normal or Mission.m_MissionType == DMSubtype_Normal2 then
                 if WasDeadPerson then
                     AddScore(DeadObjectHandle, ScoreForDyingAsPerson * SpawnKillMultiplier)
                 else
                     AddScore(DeadObjectHandle, ScoreForDyingAsCraft * SpawnKillMultiplier)
                 end
             end
             
             if KillerIsAI and (Mission.m_NumAIUnits > 0) then
                 DoTaunt(TAUNTS_HumanShipDestroyed)
             end
         end
         
         if (Mission.m_KillLimit > 0) and (GetKills(KillersHandle) >= Mission.m_KillLimit) then
             NoteGameoverByKillLimit(KillersHandle)
             DoGameover(10.0)
         end
    else
        return EJECTKILLRETCODES_DOEJECTPILOT
    end
    
    if WasDeadAI then
        for i = 1, Mission.m_NumAIUnits do
            if DeadObjectHandle == Mission.m_AICraftHandles[i] then
                Mission.m_AICraftHandles[i] = nil
                -- BuildBotCraft(i) -- Will be called in Update or here?
                -- C++ handles it by checking in UpdateAIUnits. But here specifically in DeadObject:
                -- C++: m_AICraftHandles[i] = 0; BuildBotCraft(i); bFoundAI = true;
                BuildBotCraft(i) 
                -- if WasRabbitShooterHandle... handled automatically?
                if Wasm_RabbitShooterHandle then -- use local computed earlier or check now?
                       Mission.m_RabbitShooterHandle = Mission.m_AICraftHandles[i]
                   end
                    return EJECTKILLRETCODES_DLLHANDLED
                end
            end
        -- Animals logic if needed
        for i = 1, Mission.m_NumAnimals do
             if DeadObjectHandle == Mission.m_AnimalHandles[i] then
                 SetupAnimal(i)
                 return EJECTKILLRETCODES_DLLHANDLED
             end
        end
        
        return EJECTKILLRETCODES_DLLHANDLED 
    else
        if WasDeadPerson or (Mission.m_RabbitMode and KilledRabbit) then
            RespawnPilot(DeadObjectHandle, DeadTeam)
            return EJECTKILLRETCODES_DLLHANDLED
        else
            Mission.m_Flying[DeadTeam] = true
            return EJECTKILLRETCODES_DOEJECTPILOT
        end
    end
end

-- Helper: GetCanEject (C++ lines 151-170)
function GetCanEject(h)
    if Mission.m_ShipOnlyMode then
        return false
    end
    
    -- Can't eject if the rabbit
    if Mission.m_RabbitMode and (h == Mission.m_RabbitTargetHandle) then
        return false
    end
    
    if (Mission.m_MissionType == DMSubtype_Normal) or
       (Mission.m_MissionType == DMSubtype_KOH) or
       (Mission.m_MissionType == DMSubtype_Loot) then
       return true
    end
    
    return false
end

function PlayerEjected(DeadObjectHandle)
    local WasDeadAI = not IsPlayer(DeadObjectHandle)
    local DeadTeam = GetTeamNum(DeadObjectHandle)
    if DeadTeam == 0 then return EJECTKILLRETCODES_DLLHANDLED end
    
    if GetCanEject(DeadObjectHandle) then
        Mission.m_Flying[DeadTeam] = true
        return DeadObject(DeadObjectHandle, DeadObjectHandle, false, WasDeadAI)
    else
        return DeadObject(DeadObjectHandle, DeadObjectHandle, true, WasDeadAI)
    end
end

function GetRespawnInVehicle()
    if Mission.m_ShipOnlyMode then
        return true
    end
    
    if (Mission.m_MissionType == DMSubtype_Race2) or (Mission.m_MissionType == DMSubtype_Normal2) then
        return true
    end
    
    return false
end

function ObjectKilled(DeadObjectHandle, KillersHandle)
    local WasDeadAI = not IsPlayer(DeadObjectHandle)
    local WasDeadPerson = IsPerson(DeadObjectHandle)
    if GetRespawnInVehicle() then WasDeadPerson = true end
    
    return DeadObject(DeadObjectHandle, KillersHandle, WasDeadPerson, WasDeadAI)
end

function ObjectSniped(DeadObjectHandle, KillersHandle)
    local WasDeadAI = not IsPlayer(DeadObjectHandle)
    return DeadObject(DeadObjectHandle, KillersHandle, true, WasDeadAI)
end

-- Re-implement FindGoodAITarget based on C++ lines 497-671
function FindGoodAITarget(index)
    local MyCraft = Mission.m_AICraftHandles[index]
    -- Sanity check
    if not IsAliveAndPilot(MyCraft) then
        Mission.m_AICraftHandles[index] = nil
        return
    end
    
    -- Rabbit mode handling
    if Mission.m_RabbitMode and (MyCraft ~= Mission.m_RabbitTargetHandle) then
        local TargetH = Mission.m_RabbitTargetHandle
        if IsAlive(TargetH) then
            Attack(MyCraft, Mission.m_RabbitTargetHandle)
        end
        return
    end
    
    local nearestEnemy = GetNearestEnemy(MyCraft)
    -- Check if nearestEnemy is a pilot (human) and ignore if so (C++ logic)
    -- C++ lines 518-524 loop over players, check if nearestEnemy == PlayerH and IsAliveAndPilot(PlayerH) -> nearestEnemy = 0.
    if nearestEnemy then
        if IsPlayer(nearestEnemy) and IsAliveAndPilot(nearestEnemy) then
            nearestEnemy = nil -- Ignore pilots
        end
    end
    
    -- Powerup logic (lines 527-563)
    if nearestEnemy and (not Mission.m_AILastWentForPowerup[index]) then
        -- Nearest Person
        local nearestPerson = GetNearestPerson(MyCraft) -- Assuming default range or use GetNearestPerson(MyCraft, 100.0) if binding supports
        if nearestPerson then
            local distToEnemy = GetDistance(MyCraft, nearestEnemy)
            local distToPerson = GetDistance(MyCraft, nearestPerson)
            if distToPerson < (distToEnemy * 1.2) then
                Goto(MyCraft, nearestPerson)
                Mission.m_AILastWentForPowerup[index] = true
                Mission.m_PowerupGotoTime[index] = 0
                Mission.m_AITargetHandles[index] = nearestPerson
                return
            end
        end
        
        -- Nearest Powerup
        local nearestPowerup = GetNearestPowerup(MyCraft)
        if nearestPowerup then
            local distToEnemy = GetDistance(MyCraft, nearestEnemy)
            local distToPowerup = GetDistance(MyCraft, nearestPowerup)
             if distToPowerup < (distToEnemy * 1.2) then
                Goto(MyCraft, nearestPowerup)
                Mission.m_AILastWentForPowerup[index] = true
                Mission.m_PowerupGotoTime[index] = 0
                Mission.m_AITargetHandles[index] = nearestPowerup
                return
            end
        end
    end
    
    -- Final Target Selection
    local BestDist = 1e10
    local BestHandle = nearestEnemy -- Default to GetNearestEnemy result if valid
    
    if not BestHandle then
        -- Find closest valid target manually
        if not Mission.m_HumansVsBots then
            -- Scan bots
            for i = 1, Mission.m_NumAIUnits do
                 if i ~= index and Mission.m_AICraftHandles[i] and IsAlive(Mission.m_AICraftHandles[i]) then
                     if not IsAlly(MyCraft, Mission.m_AICraftHandles[i]) then
                         local d = GetDistance(MyCraft, Mission.m_AICraftHandles[i])
                         if d > 0.01 and d < BestDist then
                             BestDist = d
                             BestHandle = Mission.m_AICraftHandles[i]
                         end
                     end
                 end
            end
        end
        
        -- Scan humans
        for i = 1, MAX_TEAMS - 1 do
            local pH = GetPlayerHandle(i)
            if pH and IsAlive(pH) and (not IsAliveAndPilot(pH)) then -- Ignore pilots here too? C++ says "Skip human pilots in this phase"
                 local d = GetDistance(MyCraft, pH)
                 if d > 0.01 and d < BestDist then
                     BestDist = d
                     BestHandle = pH
                 end
            end
        end
    end
    
    Mission.m_AITargetHandles[index] = BestHandle
    if BestHandle then
        Attack(MyCraft, BestHandle)
    end
    Mission.m_AILastWentForPowerup[index] = false
end

-- Helper: BuildBotCraft (C++ lines 674-725)
function BuildBotCraft(index)
    -- _ASSERTE(m_AICraftHandles[index] == 0)
    
    local theirTeam = 0
    if Mission.m_RabbitMode then
        theirTeam = 14
    elseif Mission.m_HumansVsBots then
        theirTeam = 15
    else
        local NUM_AI_TEAMS = LAST_AI_TEAM - FIRST_AI_TEAM + 1
        theirTeam = FIRST_AI_TEAM + (index % NUM_AI_TEAMS)
    end
    
    local APlayerTeam = 1
    for i = 1, MAX_TEAMS - 1 do
        if Mission.m_TeamIsSetUp[i] and GetPlayerHandle(i) then
            APlayerTeam = i
        end
    end
    
    local Where = GetRandomSpawnpoint(theirTeam)
    Where = GetPositionNear(Where, BotMinRadiusAway, BotMaxRadiusAway)
    Where.y = Where.y + (2 + GetRandomFloat(4))
    
    local NewCraftsODF = GetPlayerODF(APlayerTeam, 2) -- Randomize_Any
    
    Mission.m_AICraftHandles[index] = BuildObject(NewCraftsODF, theirTeam, Where)
    local h = Mission.m_AICraftHandles[index]
    SetRandomHeadingAngle(h)
    SetNoScrapFlagByHandle(h)
    AddPilotByHandle(h)
    
    FindGoodAITarget(index)
end

-- Helper: SetupAnimal (C++ lines 728-755)
function SetupAnimal(index)
    local AnimalTeam = 8 + math.floor(GetRandomFloat(6))
    if Mission.m_HumansVsBots or Mission.m_RabbitMode then
        AnimalTeam = 13
    end
    
    local Where = GetRandomSpawnpoint()
    Where = GetPositionNear(Where, AllyMinRadiusAway, AllyMaxRadiusAway)
    Where.y = Where.y + (2 + GetRandomFloat(4))
    
    local AnimalODF = Mission.m_AnimalConfig -- Using single config for now
    
    Mission.m_AnimalHandles[index] = BuildObject(AnimalODF, AnimalTeam, Where)
    SetRandomHeadingAngle(Mission.m_AnimalHandles[index])
    SetNoScrapFlagByHandle(Mission.m_AnimalHandles[index])
end

-- Helper: ObjectifyFlag (C++ lines 759-783)
function ObjectifyFlag()
    local PlayerH = GetPlayerHandle()
    if not PlayerH then return end
    
    local team = GetTeamNum(PlayerH)
    local TeamBlock = WhichTeamGroup(team)
    
    if IsTeamplayOn() and (TeamBlock >= 0) then
        local myFlag = (TeamBlock == 0) and Mission.m_Flag1 or Mission.m_Flag2
        local opponentFlag = (TeamBlock == 0) and Mission.m_Flag2 or Mission.m_Flag1
        
        if myFlag then
             SetObjectiveOff(myFlag)
             SetObjectiveOn(myFlag)
             -- Need localized string for "Defend Flag!"
             SetObjectiveName(myFlag, "Defend Flag!")
        end
        if opponentFlag then
             SetObjectiveOff(opponentFlag)
             SetObjectiveOn(opponentFlag)
             SetObjectiveName(opponentFlag, "Capture Flag!")
        end
    end
end


-- Helper: CrunchEmptyVehicleList
function CrunchEmptyVehicleList()
    local j = 1
    for i = 1, MAX_VEHICLES_TRACKED do
        if Mission.m_EmptyVehicles[i] then
            Mission.m_EmptyVehicles[j] = Mission.m_EmptyVehicles[i]
            j = j + 1
        end
    end
    
    -- Zero out the rest
    for k = j, MAX_VEHICLES_TRACKED do
        Mission.m_EmptyVehicles[k] = nil
    end
    Mission.m_NumVehiclesTracked = j - 1
end

-- Helper: UpdateEmptyVehicles
function UpdateEmptyVehicles()
    if Mission.m_NumVehiclesTracked == 0 then return end
    
    local anyChanges = false
    for i = 1, MAX_VEHICLES_TRACKED do
        local h = Mission.m_EmptyVehicles[i]
        if h then
            -- Note: In Lua, checking IsAround(nil) is safe? usually yes or handled by binding.
            -- But h is verified not nil by 'if h'.
            if not IsAround(h) then
                Mission.m_EmptyVehicles[i] = nil
                anyChanges = true
            elseif IsPlayer(h) then
                Mission.m_EmptyVehicles[i] = nil -- Human entered
                anyChanges = true
            elseif IsAliveAndPilot(h) then
                Mission.m_EmptyVehicles[i] = nil -- AI pilot entered
                anyChanges = true
            end
        end
    end
    
    if anyChanges then
        CrunchEmptyVehicleList()
        anyChanges = false
    end
    
    local CurNumPlayers = CountPlayers()
    local MaxEmpties = CurNumPlayers + math.floor(CurNumPlayers / 2) + 1
    
    if Mission.m_NumVehiclesTracked > MaxEmpties then
        -- Kill oldest (index 1)
        if Mission.m_EmptyVehicles[1] then
            SelfDamage(Mission.m_EmptyVehicles[1], 1e20)
            Mission.m_EmptyVehicles[1] = nil
            anyChanges = true
        end
    end
    
    if anyChanges then
        CrunchEmptyVehicleList()
    end
end

-- Helper: AddEmptyVehicle
function AddEmptyVehicle(NewCraft)
    if not NewCraft then return end
    
    if Mission.m_NumVehiclesTracked >= MAX_VEHICLES_TRACKED then
        UpdateEmptyVehicles()
        
        -- If still full, kill oldest
        if Mission.m_NumVehiclesTracked >= MAX_VEHICLES_TRACKED then
            if Mission.m_EmptyVehicles[1] then
                SelfDamage(Mission.m_EmptyVehicles[1], 1e20)
                Mission.m_EmptyVehicles[1] = nil
                CrunchEmptyVehicleList()
            end
        end
    end
    
    if Mission.m_NumVehiclesTracked < MAX_VEHICLES_TRACKED then
        Mission.m_NumVehiclesTracked = Mission.m_NumVehiclesTracked + 1
        Mission.m_EmptyVehicles[Mission.m_NumVehiclesTracked] = NewCraft
    end
end

-- Helper: ObjectifyRabbit
function ObjectifyRabbit()
    if Mission.m_RabbitTargetHandle then
        SetObjectiveOn(Mission.m_RabbitTargetHandle)
        -- SetObjectiveName might need binding check or wrapper
        SetObjectiveName(Mission.m_RabbitTargetHandle, "Rabbit")
    end
end

-- Define SetNewRabbit globally (or local if used inside same scope block, but DeadObject uses it 
-- and DeadObject was defined above. Wait, if DeadObject calls SetNewRabbit, and SetNewRabbit is defined HERE, 
-- then DeadObject (which is local) won't see this local SetNewRabbit unless I forward declared it.
-- OPTION: Define SetNewRabbit as a global function (no local).
-- Forward declared above
function SetNewRabbit(h)
    if not h then return end
    if not IsAround(h) then 
        -- Error trace
        return 
    end
    
    Mission.m_RabbitMissingTurns = 0
    
    if Mission.m_RabbitTargetHandle then
        SetObjectiveOff(Mission.m_RabbitTargetHandle)
    end
    
    Mission.m_RabbitTargetHandle = h
    Mission.m_RabbitShooterHandle = nil
    
    if not IsPlayer(h) then
        Mission.m_RabbitWasHuman = false
        Mission.m_RabbitTeam = 0
        SetTeamNum(h, 15) -- Force specialized team
    else
        Mission.m_RabbitWasHuman = true
        Mission.m_RabbitTeam = GetTeamNum(h)
    end
    
    local foundIt = false
    -- Check if human (debug print logic)
    
    -- Reset AI targets logic (FindGoodAITarget needed)
    for i = 1, Mission.m_NumAIUnits do
        if Mission.m_AICraftHandles[i] == h then
            -- skip
        else
            -- FindGoodAITarget(i) -- Impl pending
        end
    end
    
    local PlayerH = GetPlayerHandle()
    if PlayerH == Mission.m_RabbitTargetHandle then
        AddToMessagesBox("It's wabbit hunting season. Do you feel lucky?")
    else
        ObjectifyRabbit()
    end
end

-- Helper: ObjectifyRacePoint
function ObjectifyRacePoint()
    -- Clear previous
    for i = 1, Mission.m_TotalCheckpoints do
        local cpName = string.format("checkpoint%d", i)
        local h = GetHandle(cpName)
        if h then SetObjectiveOff(h) end
    end
    
    local Idx = GetLocalPlayerTeamNumber()
    if Idx >= 0 then
        -- Note: m_LapNumber initialized to 0. C++: if lap < total.
        if (Mission.m_TotalRaceLaps == 0) or (Mission.m_LapNumber[Idx] < Mission.m_TotalRaceLaps) then
            local nextCP = Mission.m_NextRaceCheckpoint[Idx]
            local cpName = string.format("checkpoint%d", nextCP)
            local h = GetHandle(cpName)
            if h then SetObjectiveOn(h) end
        end
    end
end

-- ExecuteRabbit (C++ lines 1323-1490)
-- Rabbit-specific execute stuff. Kill da wabbit! Kill da wabbit!
function ExecuteRabbit()
    -- Rebuild the rabbit if they're missing for more than a half
    -- second...
    local RabbitH = Mission.m_RabbitTargetHandle
    if IsAround(RabbitH) then
        Mission.m_RabbitMissingTurns = 0
        -- Account for human hopping out of craft (which would keep the
        -- rabbit designation, while the pilot is the true rabbit)
        if Mission.m_RabbitWasHuman and (RabbitH ~= GetPlayerHandle(Mission.m_RabbitTeam)) then
            -- Unobjectify the old craft.
            -- SetObjectiveOff(RabbitH);
            SetNewRabbit(GetPlayerHandle(Mission.m_RabbitTeam))
        end
    else
        -- BZTrace(("Rabbit (%08X) has gone missing :(\n", RabbitH));
        Mission.m_RabbitMissingTurns = Mission.m_RabbitMissingTurns + 1
    end
    
    -- Track the rabbit shooter in case they died/switched vehicles, etc
    if Mission.m_RabbitShooterWasHuman and (Mission.m_RabbitShooterHandle ~= GetPlayerHandle(Mission.m_RabbitShooterTeam)) then
        Mission.m_RabbitShooterHandle = GetPlayerHandle(Mission.m_RabbitShooterTeam)
        -- BZTrace(("Resetting shooter to be handle %08X on team %d\n", m_RabbitShooterHandle, m_RabbitShooterTeam));
    end
    
    if Mission.m_RabbitMissingTurns > 1 then
        -- Do the in-depth search for a new target
        RabbitH = Mission.m_RabbitTargetHandle
        if not IsAround(RabbitH) then
            -- Uhoh. Lost the target. :(
            if Mission.m_RabbitWasHuman and (Mission.m_RabbitTeam ~= Mission.m_ForbidRabbitTeam) then
                -- Move to current vehicle on that team.
                SetNewRabbit(GetPlayerHandle(Mission.m_RabbitTeam))
            end
        end
        
        RabbitH = Mission.m_RabbitTargetHandle
        if not IsAround(RabbitH) then
            -- Still gone? Gotta rebuild target.
            RabbitH = Mission.m_RabbitShooterHandle -- last person to shoot them...
            if IsAround(RabbitH) then
                SetNewRabbit(Mission.m_RabbitShooterHandle)
            else
                -- Gone, no known shooter. Pick a semi-random human to take
                -- over. The timestep at which this occurrs should be fairly
                -- random
                local foundNewRabbit = false
                for i = 0, MAX_TEAMS - 1 do
                    local T2 = (Mission.m_ElapsedGameTime + i) % MAX_TEAMS
                    local PlayerH = GetPlayerHandle(T2)
                    if (T2 > 0) and PlayerH and (T2 ~= Mission.m_ForbidRabbitTeam) then
                        SetNewRabbit(PlayerH)
                        foundNewRabbit = true
                        Mission.m_ForbidRabbitTeam = 0
                        break -- out of this for loop
                    end
                end
                
                -- If we didn't find a human, pick a random AI
                if not foundNewRabbit then
                    for i = 0, MAX_AI_UNITS - 1 do
                        local index2 = ((Mission.m_ElapsedGameTime + i) % MAX_AI_UNITS) + 1
                        if Mission.m_AICraftHandles[index2] then
                            SetNewRabbit(Mission.m_AICraftHandles[index2])
                            foundNewRabbit = true
                            Mission.m_ForbidRabbitTeam = 0
                            break -- out of this for loop
                        end
                    end
                end
                
                AddToMessagesBox(TranslateString("mission", "Reset the rabbit... it's hunting season!"))
                -- BZTrace(("Reset the rabbit... it's hunting season!"));
            end
        end
    end
    
    -- If the rabbit's MIA, skip this.
    RabbitH = Mission.m_RabbitTargetHandle
    if not IsAround(RabbitH) then return end -- Can't do a thing here.
    
    -- Update the last *other* person to hit me, only overriding if
    -- valid data
    local LastShooter = GetWhoShotMe(Mission.m_RabbitTargetHandle)
    if LastShooter and (LastShooter ~= Mission.m_RabbitTargetHandle) and (LastShooter ~= Mission.m_RabbitShooterHandle) then
        -- Workaround- if player (craft) was rabbit shooter, but they
        -- died as a pilot, LastShooter will the craft that did the
        -- shooting. So, reassign to player if they're still around.
        local LastShooterTeam = GetTeamNum(LastShooter)
        if (LastShooterTeam == Mission.m_RabbitShooterTeam) or (Mission.m_RabbitShooterTeam == 0) then
            local temph = GetPlayerHandle(Mission.m_RabbitShooterTeam)
            if temph then LastShooter = temph end
        end
        
        Mission.m_RabbitShooterHandle = LastShooter
        
        -- Preclear this...
        Mission.m_RabbitShooterWasHuman = false
        Mission.m_RabbitShooterTeam = 0
        
        for i = 1, MAX_TEAMS do
            local PlayerH = GetPlayerHandle(i)
            if PlayerH == Mission.m_RabbitShooterHandle then
                Mission.m_RabbitShooterWasHuman = true
                Mission.m_RabbitShooterTeam = i
                -- BZTrace(("Rabbit shooter is human, team %d\n", i));
            end
        end
    end
    
    -- Have a known rabbit. Update scores for them, 1 point every 5 seconds
    if (math.fmod(Mission.m_ElapsedGameTime, 5 * Mission.m_GameTPS) == 0) and ((CountPlayers() > 1) or (Mission.m_NumAIUnits > 0)) then
        AddScore(Mission.m_RabbitTargetHandle, 1) -- Staying alive....
    end
    
    if math.fmod(Mission.m_ElapsedGameTime, Mission.m_GameTPS) == 0 then
        ObjectifyRabbit()
    end
end

-- ExecuteRace (C++ lines 1493-1627)
function ExecuteRace()
    if (not Mission.RaceSetObjective) or (math.fmod(Mission.m_ElapsedGameTime, Mission.m_GameTPS) == 0) then
        -- Race. Gotta set objectives properly
        Mission.RaceSetObjective = true
        ObjectifyRacePoint()
    end
    
    -- Also, check if everyone's near their next checkpoint
    local Advanced = {} -- [MAX_TEAMS]
    local AnyAdvanced = false
    
    for i = 0, MAX_TEAMS - 1 do
        Advanced[i] = false
        local PlayerH = GetPlayerHandle(i)
        if PlayerH then
            local cpName = string.format("checkpoint%d", Mission.m_NextRaceCheckpoint[i])
            local NextCheckpoint = GetHandle(cpName)
            if NextCheckpoint then
                -- Player is close enough AND (0 laps OR not finished already)
                if (GetDistance(PlayerH, NextCheckpoint) < Mission.m_RaceCheckpointRadius) and ((Mission.m_TotalRaceLaps == 0) or (Mission.m_LapNumber[i] < Mission.m_TotalRaceLaps)) then
                    Mission.m_NextRaceCheckpoint[i] = Mission.m_NextRaceCheckpoint[i] + 1
                    if Mission.m_NextRaceCheckpoint[i] > Mission.m_TotalCheckpoints then
                        Mission.m_NextRaceCheckpoint[i] = 1
                        Mission.m_LapNumber[i] = Mission.m_LapNumber[i] + 1
                    end
                    ObjectifyRacePoint()
                    Advanced[i] = true
                    AnyAdvanced = true
                    Mission.m_TotalCheckpointsCompleted[i] = Mission.m_TotalCheckpointsCompleted[i] + 1
                    
                    -- Print out a message for local player upon lap completion
                    if (Mission.m_NextRaceCheckpoint[i] == 1) and (i == GetLocalPlayerTeamNumber()) then
                         local msg = ""
                         if Mission.m_TotalRaceLaps > 0 then
                             msg = string.format(TranslateString("mission", "Lap %d/%d Completed"), Mission.m_LapNumber[i], Mission.m_TotalRaceLaps)
                         else
                             msg = string.format(TranslateString("mission", "Lap %d Completed"), Mission.m_LapNumber[i])
                         end
                         AddToMessagesBox(msg)
                    end
                end
            end
        end
    end
    
    -- Give a point to someone if they made it to a checkpoint before anyone else did.
    if AnyAdvanced then
        for i = 0, MAX_TEAMS - 1 do
            if Advanced[i] then
                local PlayerH = GetPlayerHandle(i)
                local LeadingPlayer = true
                for j = 0, MAX_TEAMS - 1 do
                    if (i ~= j) and (Mission.m_TotalCheckpointsCompleted[i] <= Mission.m_TotalCheckpointsCompleted[j]) then
                        LeadingPlayer = false
                    end
                end
                
                if LeadingPlayer then
                    if i ~= Mission.m_LastTeamInLead then
                        local msg = string.format(TranslateString("mission", "%s takes the lead"), GetPlayerName(PlayerH))
                        AddToMessagesBox(msg)
                        Mission.m_LastTeamInLead = i
                    end
                end
                
                -- Also check if leader completed a full lap
                LeadingPlayer = true
                for j = 0, MAX_TEAMS - 1 do
                     if (i ~= j) and (Mission.m_TotalCheckpointsCompleted[i] < Mission.m_TotalCheckpointsCompleted[j]) then
                         LeadingPlayer = false
                     end
                end
                
                if LeadingPlayer and (Mission.m_NextRaceCheckpoint[i] == 1) then
                    AddScore(PlayerH, 1) -- Add score to show lap completion. -GBD
                    local msg = ""
                    if Mission.m_TotalRaceLaps > 0 then
                        if Mission.m_RaceWinerCount == 0 then
                            msg = string.format(TranslateString("mission", "Lap %d/%d completed by %s"), Mission.m_LapNumber[i], Mission.m_TotalRaceLaps, GetPlayerName(PlayerH))
                        end
                    else
                        if Mission.m_RaceWinerCount == 0 then
                            msg = string.format(TranslateString("mission", "Lap %d completed by %s"), Mission.m_LapNumber[i], GetPlayerName(PlayerH))
                        end
                    end
                    AddToMessagesBox(msg)
                    
                    if Mission.m_LapNumber[i] == Mission.m_TotalRaceLaps then
                        Mission.m_RaceWinerCount = Mission.m_RaceWinerCount + 1
                        if Mission.m_RaceWinerCount == 1 then
                            msg = string.format(TranslateString("mission", "%s finished in 1st place"), GetPlayerName(PlayerH))
                            AddScore(PlayerH, 100)
                        elseif Mission.m_RaceWinerCount == 2 then
                            msg = string.format(TranslateString("mission", "%s finished in 2nd place"), GetPlayerName(PlayerH))
                            AddScore(PlayerH, 75)
                        elseif Mission.m_RaceWinerCount == 3 then
                            msg = string.format(TranslateString("mission", "%s finished in 3rd place"), GetPlayerName(PlayerH))
                            AddScore(PlayerH, 50)
                        else
                            msg = string.format(TranslateString("mission", "%s finished in %dth place"), GetPlayerName(PlayerH), Mission.m_RaceWinerCount)
                            AddScore(PlayerH, 25)
                        end
                        
                        if Mission.m_RaceWinerCount <= 1 then
                            NoteGameoverWithCustomMessage(msg)
                            msg = TranslateString("mission", "10 seconds left...")
                        else
                            AddToMessagesBox(msg)
                        end
                        DoGameover(10.0)
                    end
                end
            end
        end
    end
end

-- ExecuteWeenie (C++ lines 1629-1682)

function ExecuteWeenie()
    -- Go over all humans first
    for i = 1, MAX_TEAMS - 1 do
        local p = GetPlayerHandle(i)
        if p then
            -- self-fire doesn't count (and possibly friendly fire doesn't either)
            local h = GetWhoShotMe(p)
            if h and (h ~= p) and ((GetLastEnemyShot(p) >= 0.0) or Mission.m_bIsFriendlyFireOn) then
                Damage(p, MAX_FLOAT)
            end
        end
    end
    
    for i = 1, Mission.m_NumAIUnits do
        local p = Mission.m_AICraftHandles[i]
        if p then
            local h = GetWhoShotMe(p)
            if h and (h ~= p) and ((GetLastEnemyShot(p) >= 0.0) or Mission.m_bIsFriendlyFireOn) then
                Damage(p, MAX_FLOAT)
            end
        end
    end
    
    for i = 1, Mission.m_NumAnimals do
        local p = Mission.m_AnimalHandles[i]
        if p then
            local h = GetWhoShotMe(p)
            if h and (h ~= p) and ((GetLastEnemyShot(p) >= 0.0) or Mission.m_bIsFriendlyFireOn) then
                Damage(p, MAX_FLOAT)
            end
        end
    end
    
    for i = 1, Mission.m_NumVehiclesTracked do
        local p = Mission.m_EmptyVehicles[i]
        if p then
            local h = GetWhoShotMe(p)
            if h and (h ~= p) and ((GetLastEnemyShot(p) >= 0.0) or Mission.m_bIsFriendlyFireOn) then
                Damage(p, MAX_FLOAT)
            end
        end
    end
end

-- Notices what ships all the human players are currently in. If they
-- hop out, then their old craft is pushed onto the empties list. If
-- this is 'ship only' mode, then other penalties are applied.
function ExecuteTrackPlayers()
    for i = 1, MAX_TEAMS - 1 do
        local p = GetPlayerHandle(i)
        if p then
            SetLifespan(p, -1.0) -- Ensure there's no lifespan killing this craft
            
            if IsAliveAndPilot(p) then
                -- Make sure the 'spawn kill' doesn't get triggered.
                if Mission.m_ShipOnlyMode then
                    Mission.m_SpawnedAtTime[i] = -4096
                    
                    -- AddKills(p, -1); // Ouch. Don't do that!
                    if (Mission.m_MissionType == DMSubtype_Normal) or (Mission.m_MissionType == DMSubtype_Normal2) then -- Only in Normal DM. -GBD
                        AddScore(p, -ScoreForKillingCraft)
                    end
                    SelfDamage(p, 1e+20) -- 1e+20f
                end
                
                -- Did they just hop out, leaving that craft w/o a pilot? Nuke that craft too.
                local lastp = Mission.m_LastPlayerCraftHandle[i]
                if IsAround(lastp) then
                    if not IsAliveAndPilot(lastp) then
                        if Mission.m_ShipOnlyMode then
                            SelfDamage(Mission.m_LastPlayerCraftHandle[i], 1e+20)
                        else
                            -- Not ship-only mode. Add this to empties list
                            if Mission.m_NumVehiclesTracked < MAX_VEHICLES_TRACKED then
                                Mission.m_NumVehiclesTracked = Mission.m_NumVehiclesTracked + 1
                                Mission.m_EmptyVehicles[Mission.m_NumVehiclesTracked] = Mission.m_LastPlayerCraftHandle[i]
                            end
                        end
                        Mission.m_LastPlayerCraftHandle[i] = nil -- 'forget' about this
                    end
                end
            else
                -- Must be in a craft. Store it.
                Mission.m_LastPlayerCraftHandle[i] = p
            end
        end
    end
end

-- UpdateGameTime (C++ lines 1745-1817)
-- Called via execute, m_GameTPS of a second has elapsed. Update everything.
function UpdateGameTime()
    Mission.m_ElapsedGameTime = Mission.m_ElapsedGameTime + 1
    
    -- Are we in a time limited game?
    if Mission.m_RemainingGameTime > 0 then
        Mission.m_RemainingGameTime = Mission.m_RemainingGameTime - 1
        
        if math.fmod(Mission.m_RemainingGameTime, Mission.m_GameTPS) == 0 then
            -- Convert tenth-of-second ticks to hour/minutes/seconds format.
            local Seconds = math.floor(Mission.m_RemainingGameTime / Mission.m_GameTPS)
            local Minutes = math.floor(Seconds / 60)
            local Hours = math.floor(Minutes / 60)
            
            -- Lop seconds and minutes down to 0..59
            Seconds = math.fmod(Seconds, 60)
            Minutes = math.fmod(Minutes, 60)
            
            local TempMsgString = ""
            if Hours > 0 then
                TempMsgString = string.format(TranslateString("mission", "Time Left %d:%02d:%02d"), Hours, Minutes, Seconds)
            else
                TempMsgString = string.format(TranslateString("mission", "Time Left %d:%02d"), Minutes, Seconds)
            end
            SetTimerBox(TempMsgString)
            
            -- Also print this out more visibly at important times....
            if Hours == 0 then
                -- Every 5 minutes down to 10 minutes, then every minute thereafter.
                if (Seconds == 0) and ((Minutes <= 10) or (math.fmod(Minutes, 5) == 0)) then
                    AddToMessagesBox(TempMsgString)
                else
                    -- Every 5 seconds when under a minute is remaining.
                    if (Minutes == 0) and (math.fmod(Seconds, 5) == 0) then
                        AddToMessagesBox(TempMsgString)
                    end
                end
            end
        end
        
        -- Game over due to timeout?
        if Mission.m_RemainingGameTime == 0 then
            NoteGameoverByTimelimit()
            DoGameover(10.0)
        end
    else
        -- Infinite time game. Periodically update ingame clock.
        if math.fmod(Mission.m_ElapsedGameTime, Mission.m_GameTPS) == 0 then
            local Seconds = math.floor(Mission.m_ElapsedGameTime / Mission.m_GameTPS)
            local Minutes = math.floor(Seconds / 60)
            local Hours = math.floor(Minutes / 60)
            
            Seconds = math.fmod(Seconds, 60)
            Minutes = math.fmod(Minutes, 60)
            
            local TempMsgString = ""
            if Hours > 0 then
                TempMsgString = string.format(TranslateString("mission", "Mission Time %d:%02d:%02d"), Hours, Minutes, Seconds)
            else
                TempMsgString = string.format(TranslateString("mission", "Mission Time %d:%02d"), Minutes, Seconds)
            end
            SetTimerBox(TempMsgString)
        end
    end
end

-- UpdateAIUnits (C++ lines 1819-1944)
-- UpdateAIUnits (C++ lines 1819-1944)
function UpdateAIUnits()
    -- Need to spawn in a new craft at the start of the game
    -- (staggered every second)
    local InitialSpawnInFrequency = 5 -- 10 ticks per second (C++ #ifdef _DEBUG 1 else 5)
    if IsNetworkOn() then InitialSpawnInFrequency = 5 else InitialSpawnInFrequency = 1 end
    
    if math.fmod(Mission.m_ElapsedGameTime, InitialSpawnInFrequency) == 0 then
        -- #ifdef _DEBUG
        -- Spam units logic skipped
        -- #endif
        
        if Mission.m_NumAIUnits < Mission.m_MaxAIUnits then
            Mission.m_NumAIUnits = Mission.m_NumAIUnits + 1
            BuildBotCraft(Mission.m_NumAIUnits) 
        else
            for i = 1, Mission.m_NumAIUnits do
                -- Fix for mantis #400 - if a bot craft is sniped,
                -- 'forget' about it and build another in its slot.
                if Mission.m_AICraftHandles[i] then
                    -- IsNotDeadAndPilot2: In Lua, IsAliveAndPilot might suffice or we need specific IsNotDead check?
                    -- C++: IsNotDeadAndPilot2 checks (!IsDead and !IsPilot) ? No, "IsNotDead" means health > 0?
                    -- Assuming IsAlive checks both existence and health > 0.
                    -- C++ function IsNotDeadAndPilot2 likely checks (IsAlive(h) && IsPilot(h))
                    -- Wait, "sniped" usually means pilot killed but craft remains?
                    -- If craft remains but pilot dead -> IsAlive is true (craft is alive object), IsPilot is false.
                    -- So we want to replace if NOT (Alive AND Pilot).
                    local h = Mission.m_AICraftHandles[i]
                    if not IsAliveAndPilot(h) then
                        -- _ASSERTE(0);
                        SetLifespan(h, SNIPED_AI_LIFESPAN)
                        Mission.m_AICraftHandles[i] = nil
                    end
                end
                
                if not Mission.m_AICraftHandles[i] then
                    BuildBotCraft(i)
                    break
                end
            end
        end
    end
    
    -- Periodically, update all the AI tasks. This is set to 3.2
    -- seconds by default. It rotates thru all bots, one per tick.
    for i = 1, Mission.m_NumAIUnits do
        if bit32.band(Mission.m_ElapsedGameTime + i, 0x1F) == 0 then
            if Mission.m_AILastWentForPowerup[i] then
                local Target = Mission.m_AITargetHandles[i]
                Mission.m_PowerupGotoTime[i] = Mission.m_PowerupGotoTime[i] + 1
                -- Max of 15 seconds to pick up a powerup, then we go again
                if (not IsAlive(Target)) or (Mission.m_PowerupGotoTime[i] > 150) or (GetDistance(Mission.m_AICraftHandles[i], Target) < 2.0) then
                    -- Need to retarget.
                    FindGoodAITarget(i)
                end
            else
                -- Code disabled NM 7/28/07 - this is not multiworld friendly.
                -- (C++ lines 1895-1939 disabled #if 0)
            end
        end
    end
end

-- UpdateAnimals (C++ lines 1946-1999)
function UpdateAnimals()
    -- Have to manually check on animals; they won't trigger a call to
    -- DeadObject(). If any died, note that.
    for i = 1, Mission.m_NumAnimals do
        if Mission.m_AnimalHandles[i] then
            if not IsAlive(Mission.m_AnimalHandles[i]) then
                Mission.m_AnimalHandles[i] = nil
            end
        end
    end
    
    -- Spawn in animals at the start of the game (staggered every 4
    -- seconds)
    local InitialSpawnInFrequency = 4 * Mission.m_GameTPS -- m_GameTPS ticks per second
    
    if math.fmod(Mission.m_ElapsedGameTime, InitialSpawnInFrequency) == 0 then
        if Mission.m_NumAnimals < Mission.m_MaxAnimals then
            Mission.m_NumAnimals = Mission.m_NumAnimals + 1
            SetupAnimal(Mission.m_NumAnimals)
        else
            -- 'Full' set of animals. Do respawns as needed.
            for i = 1, Mission.m_NumAnimals do
                if not Mission.m_AnimalHandles[i] then
                    SetupAnimal(i)
                    break
                end
            end
        end
    end
    
    -- #if 0 // debug kill animals
    -- #endif
end

-- Update Function (Execute)
function Update()
    if Mission.StopScript then return end
    
    -- if (!m_DidOneTimeInit) Init();
    if not Mission.m_DidOneTimeInit then Init() end
    
    -- #if 0 // def _DEBUG AI testing loop skipped #endif
    
    -- Always see if any empties are filled or need to be killed
    UpdateEmptyVehicles()
    
    if DMIsRaceSubtype[Mission.m_MissionType] then ExecuteRace() end
    
    if Mission.m_RabbitMode and (Mission.m_MissionType == DMSubtype_Normal or Mission.m_MissionType == DMSubtype_Normal2) then
        ExecuteRabbit()
    end
    
    if Mission.m_WeenieMode then ExecuteWeenie() end
    
    -- CTF - periodically re-objectify the opponent's flag
    if Mission.m_MissionType == DMSubtype_CTF then
        if math.fmod(Mission.m_ElapsedGameTime, Mission.m_GameTPS) == 0 then
            ObjectifyFlag()
        end
    end
    
    ExecuteTrackPlayers()
    
    -- Do this as well...
    UpdateGameTime()
    
    if Mission.m_MaxAIUnits > 0 then UpdateAIUnits() end
    if Mission.m_MaxAnimals > 0 then UpdateAnimals() end
    
    -- Keep powerups going, etc
    -- Keep powerups going, etc
    _PUPMgr.Execute()
    
    -- Check to see if someone was flagged as flying, and if they've
    -- landed, build a new craft for them
    for i = 1, MAX_TEAMS - 1 do
        if Mission.m_Flying[i] then
            local PlayerH = GetPlayerHandle(i)
            if PlayerH and (not IsFlying(PlayerH)) then
                Mission.m_Flying[i] = false -- clear flag so we don't check until they're dead
                local ODF = GetNextVehicleODF(i, true)
                local h = BuildEmptyCraftNear(PlayerH, ODF, i, RespawnMinRadiusAway, RespawnMaxRadiusAway)
                if h then
                    SetTeamNum(h, 0) -- flag as neutral so AI won't immediately hit it
                    AddEmptyVehicle(h) -- Clean things up if there are too many around
                end
            end
        end
    end
    
    -- Mission scoring for KOH/CTF now done in main game, so we
    -- don't need to do anything here. Except gameover
    
    -- Score Limit Check
    if (Mission.m_ScoreLimit > 0) and (not Mission.m_bDidGameOverByScore) then
        local Teamplay = IsTeamplayOn()
        local Teamscore = {} -- [MAX_MULTIPLAYER_TEAMS]
        local TeamplayHandles = {}
        for k=0,15 do Teamscore[k]=0; TeamplayHandles[k]=nil end -- Init tables
        
        for i = 1, MAX_TEAMS - 1 do
            local playerH = GetPlayerHandle(i)
            if playerH then
                if Teamplay then
                    local teamGroup = WhichTeamGroup(i)
                    if (teamGroup >= 0) and (teamGroup < 16) then -- MAX_MULTIPLAYER_TEAMS usually 16?
                        Teamscore[teamGroup] = Teamscore[teamGroup] + GetScore(playerH)
                        if not TeamplayHandles[teamGroup] then TeamplayHandles[teamGroup] = playerH end
                    end
                else
                    if GetScore(playerH) >= Mission.m_ScoreLimit then
                        NoteGameoverByScore(playerH)
                        DoGameover(5.0)
                        Mission.m_bDidGameOverByScore = true
                        break
                    end
                end
            end
        end
        
        if Teamplay and (not Mission.m_bDidGameOverByScore) then
            for i = 0, 15 do
                if Teamscore[i] >= Mission.m_ScoreLimit then
                    if TeamplayHandles[i] then
                         NoteGameoverByScore(TeamplayHandles[i])
                         DoGameover(5.0)
                         Mission.m_bDidGameOverByScore = true
                         break
                    end
                end
            end
        end
    end
end



