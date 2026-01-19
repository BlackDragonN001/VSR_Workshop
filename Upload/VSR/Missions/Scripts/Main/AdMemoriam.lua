--[[
    BZCC Ad Memoriam Script
    Written by AI_Unit

    To honour the memory of zoners we have lost along the way.

    A tribute to
    - TimeVirus
    - MrJuggs
    - Slaor
    - Judge_Mental
--]]

-- Fix for finding files outside of this script directory.
assert(load(assert(LoadFile("_requirefix.lua")), "_requirefix.lua"))()

-- Standard file for BZCC global variables that can be used between modes.
require("_GlobalVariables")

local _PUPMgr = require("_PUPMgr")
local _SaveLoad = require("_SaveLoad")

-- Custom modules for this mode.
local _Zoner = require("_Zoner")
local _AnimalController = require("_AnimalController")
local _AIController = require("_AIController")

-- Default BZCC TPS is always 20.
local BZCC_DEFAULT_TPS = 20

local MAX_FLOAT = 3.4028e+38
local MAX_VEHICLES_TRACKED = 32

local SNIPED_AI_LIFESPAN = 300.0

local RespawnMinRadiusAway = 10.0
local RespawnMaxRadiusAway = 20.0
local RespawnPilotHeight = 200.0

local AllyMinRadiusAway = 10.0
local AllyMaxRadiusAway = 30.0

local FRIENDLY_SPAWNPOINT_MAX_ALLY = 100.0
local FRIENDLY_SPAWNPOINT_MIN_ENEMY = 300.0
local RANDOM_SPAWNPOINT_MIN_ENEMY = 150.0

local ScoreForKillingCraft = 5
local ScoreForKillingPerson = 5
local ScoreForDyingAsCraft = -1
local ScoreForDyingAsPerson = -1

local PointsForAIKill = true
local KillForAIKill = true

local m_GameTPS = BZCC_DEFAULT_TPS

local Mission = {
    m_TotalGameTime = 0,
    m_ElapsedGameTime = 0,
    m_RemainingGameTime = 0,
    m_KillLimit = 0, -- As specified from the shell
    m_RespawnType = 0,
    m_NumVehiclesTracked = 0,
    m_SpawnedAtTime = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },

    m_Gravity = 0, -- from ivar30

    m_TeamPos = {},
    m_Flying = {},                -- Flag saying we need to keep track of a specific player to build a craft when they land
    m_TeamIsSetUp = {},
    m_EmptyVehicles = {},         -- Index is 0 based.
    m_LastPlayerCraftHandle = {}, -- for ShipOnly mode

    m_GameWon = false,
    m_RespawnAtLowAltitude = false,
    m_bIsFriendlyFireOn = false,
    m_bDidGameOverByScore = false, -- Goes true when we have noted a winner by score
}

---------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------- Event Driven Functions -------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------

function InitialSetup()
    SetAutoGroupUnits(false)

    -- Always do this to hook up clients with the taunt engine as well.
    SetTauntCPUTeamName("Vets")

    -- We're a 1.3 DLL.
    WantBotKillMessages()
end

function Start()
    m_GameTPS = GetTPS()

    -- Read from the map's .trn file whether we respawn at altitude or not.
    local mapTrnFile = GetMapTRNFilename()
    Mission.m_RespawnAtLowAltitude = GetODFBool(mapTrnFile, "DLL", "RespawnAtLowAltitude", false)

    Mission.m_KillLimit = GetVarItemInt("network.session.ivar0")
    Mission.m_TotalGameTime = GetVarItemInt("network.session.ivar1")
    Mission.m_Gravity = GetVarItemInt("network.session.ivar31")

    -- Set this for the server now. Clients get this set from Load().
    SetGravity(Mission.m_Gravity * 0.5)

    Mission.m_bIsFriendlyFireOn = (GetVarItemInt("network.session.ivar32") ~= 0)
    Mission.m_MaxSpawnKillTime = m_GameTPS * GetVarItemInt("network.session.ivar13") -- convert seconds to 1/10 ticks

    _AIController.Setup()
    _AnimalController.Setup()
    _Zoner.Spawn()

    if (Mission.m_MaxSpawnKillTime < 0) then
        Mission.m_MaxSpawnKillTime = 0 -- sanity check
    end

    -- If the network is not on, this map was probably started from the
    -- commandline, and therefore, ivars are not at the defaults expected.
    -- Switch to some sane defaults.
    if (not IsNetworkOn()) then
        Mission.m_Gravity = 25 -- default
        SetGravity(Mission.m_Gravity * 0.5)
    end

    local PlayerEntryH = GetPlayerHandle()

    if (PlayerEntryH ~= nil) then
        RemoveObject(PlayerEntryH)
    end

    -- Do One-time server side init of varbs for everyone
    if (ImServer() or not IsNetworkOn()) then
        local LocalTeamNum = GetLocalPlayerTeamNumber()
        local PlayerH = SetupPlayer(LocalTeamNum)
        SetAsUser(PlayerH, LocalTeamNum)
        AddPilotByHandle(PlayerH)
    end

    -- Throw up Objectives.
    CreateObjectives()

    _PUPMgr:Start()
end

function Update()
    -- Always see if any empties are filled or need to be killed
    UpdateEmptyVehicles()

    -- Keep track of active players in the session
    ExecuteTrackPlayers()

    -- Do this as well...
    UpdateGameTime()

    -- For non-important bots, do this.
    _AIController.Update(Mission.m_ElapsedGameTime)
    _AnimalController.Update(Mission.m_ElapsedGameTime, m_GameTPS)
    _Zoner.RunLogic()

    -- Keep powerups going, etc
    _PUPMgr:Update()

    -- Check to see if someone was flagged as flying, and if they've
    -- landed, build a new craft for them
    for i = 1, MAX_TEAMS - 1 do
        if (Mission.m_Flying[i]) then
            local PlayerH = GetPlayerHandle(i)

            if (PlayerH ~= nil and not IsFlying(PlayerH)) then
                Mission.m_Flying[i] = false -- clear flag so we don't check until they're dead

                local ODF = GetNextVehicleODF(i, true)
                local h = BuildEmptyCraftNear(PlayerH, ODF, i, RespawnMinRadiusAway, RespawnMaxRadiusAway)

                if (h ~= nil) then
                    SetTeamNum(h, 0)   -- flag as neutral so AI won't immediately hit it
                    AddEmptyVehicle(h) -- Clean things up if there are too many around
                end
            end
        end
    end
end

function AddObject(Handle)
    if (IsPlayer(Handle)) then return end

    SetNoScrapFlagByHandle(Handle)
    SetSkill(Handle, 3)
end

function AddPlayer(id, Team, IsNewPlayer)
    -- Server does all building  client doesn't need to do anything
    if (IsNewPlayer) then
        local PlayerH = SetupPlayer(Team)
        SetAsUser(PlayerH, Team)
        AddPilotByHandle(PlayerH)
        SetNoScrapFlagByHandle(PlayerH)
    end

    return 1 -- BOGUS: always assume successful
end

function Save()
    return _SaveLoad.Save(), _PUPMgr:Save(), Mission
end

function Load(ModuleData, PUPMgrData, MissionData)
    m_GameTPS = GetTPS()

    SetAutoGroupUnits(false)

    -- Always do this to hook up clients with the taunt engine as well.
    SetTauntCPUTeamName("Vets")

    -- We're a 1.3 DLL.
    WantBotKillMessages()

    -- Load mission data.
    if (MissionData) then
        for k, v in pairs(MissionData) do
            Mission[k] = v
        end
    end

    if (ModuleData) then
		_SaveLoad.Load(ModuleData)
	else
		print("WARNING: No ModuleData provided to _SaveLoad.Load()")
	end

    CreateObjectives()
    SetGravity(Mission.m_Gravity * 0.5)

    _PUPMgr.Load()
end

function PlayerEjected(DeadObjectHandle)
    local WasDeadAI = not IsPlayer(DeadObjectHandle)
    local DeadTeam = GetTeamNum(DeadObjectHandle)

    if (DeadTeam == 0) then
        return DLLHandled -- Invalid team. Do nothing
    end

    -- Flags saying if they can eject or not
    Mission.m_Flying[DeadTeam] = true -- They're flying  create craft when they land
    return DeadObject(DeadObjectHandle, DeadObjectHandle, false, WasDeadAI)
end

function ObjectKilled(DeadObjectHandle, KillersHandle)
    local WasDeadAI = not IsPlayer(DeadObjectHandle)

    -- We don't care about dead craft, only dead pilots, and also only
    -- care about things in the lockstep world
    if (GetCurWorld() ~= 0) then
        return DoEjectPilot
    end

    return DeadObject(DeadObjectHandle, KillersHandle, IsPerson(DeadObjectHandle), WasDeadAI)
end

function ObjectSniped(DeadObjectHandle, KillersHandle)
    local WasDeadAI = not IsPlayer(DeadObjectHandle)

    -- We don't care about dead craft, only dead pilots, and also only
    -- care about things in the lockstep world
    if (GetCurWorld() ~= 0) then
        return DoRespawnSafest
    end

    -- Dead person means we must always respawn a new person
    return DeadObject(DeadObjectHandle, KillersHandle, true, WasDeadAI)
end

---------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------- Mission Related Logic --------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------

function GetInitialPlayerPilotODF(Race)
    return Race .. "spilo"
end

function GetNextVehicleODF(TeamNum, Randomize)
    local RType = Randomize_None -- Default

    if (Randomize) then
        if (Mission.m_RespawnType == 1) then
            RType = Randomize_ByRace
        elseif (Mission.m_RespawnType == 2) then
            RType = Randomize_Any
        end
    end

    return GetPlayerODF(TeamNum, RType)
end

function GetNextRandomVehicleODF(Team)
    return GetPlayerODF(Team)
end

function GetSpawnpointForTeam(Team)
    local spawnpointPosition = SetVector(0, 0, 0)
    local pSpawnPointInfo = GetAllSpawnpoints(Team)
    local count = #pSpawnPointInfo

    if (pSpawnPointInfo == nil) then
        return spawnpointPosition
    end

    local pIndices = {}
    local indexCount = 0

    for i = 1, count do
        if (pSpawnPointInfo[i].Team == Team) then
            pIndices[indexCount] = i
            indexCount = indexCount + 1
        end
    end

    if (indexCount > 0) then
        local index = math.min(math.floor(GetRandomFloat(indexCount)), indexCount - 1)
        return pSpawnPointInfo[pIndices[index]].Position
    end

    if (not IsTeamplayOn()) then
        indexCount = 0

        for i = 1, count do
            if ((pSpawnPointInfo[i].DistanceToClosestSameTeam >= FRIENDLY_SPAWNPOINT_MAX_ALLY) and
                    (pSpawnPointInfo[i].DistanceToClosestAlly >= FRIENDLY_SPAWNPOINT_MAX_ALLY) and
                    (pSpawnPointInfo[i].DistanceToClosestEnemy >= FRIENDLY_SPAWNPOINT_MIN_ENEMY)) then
                pIndices[indexCount] = i
                indexCount = indexCount + 1
            end
        end

        if (indexCount > 0) then
            local index = math.min(math.floor(GetRandomFloat(indexCount)), indexCount - 1)
            return pSpawnPointInfo[pIndices[index]].Position
        end
    end

    indexCount = 0
    for i = 1, count do
        if (((pSpawnPointInfo[i].DistanceToClosestSameTeam < FRIENDLY_SPAWNPOINT_MAX_ALLY) or
                    (pSpawnPointInfo[i].DistanceToClosestAlly < FRIENDLY_SPAWNPOINT_MAX_ALLY)) and
                (pSpawnPointInfo[i].DistanceToClosestEnemy >= FRIENDLY_SPAWNPOINT_MIN_ENEMY)) then
            pIndices[indexCount] = i
            indexCount = indexCount + 1
        end
    end

    if (indexCount > 0) then
        local index = math.min(math.floor(GetRandomFloat(indexCount)), indexCount - 1)
        return pSpawnPointInfo[pIndices[index]].Position
    end

    indexCount = 0
    for i = 1, count do
        if (pSpawnPointInfo[i].DistanceToClosestEnemy >= RANDOM_SPAWNPOINT_MIN_ENEMY) then
            pIndices[indexCount] = i
            indexCount = indexCount + 1
        end
    end

    if (indexCount > 0) then
        local index = math.min(math.floor(GetRandomFloat(indexCount)), indexCount - 1)
        return pSpawnPointInfo[pIndices[index]].Position
    end

    return GetRandomSpawnpoint(Team)
end

function SetupPlayer(Team)
    if (Team < 0 or Team >= MAX_TEAMS) then
        return nil -- Sanity check... do NOT proceed
    end

    -- Note when they spawned in.
    Mission.m_SpawnedAtTime[Team] = Mission.m_ElapsedGameTime

    local PlayerH = nil
    local Where = SetVector(0, 0, 0)
    local TeamBlock = WhichTeamGroup(Team)

    if (not IsTeamplayOn() or TeamBlock < 0) then
        Where = GetRandomSpawnpoint()

        -- And randomize around the spawnpolocal slightly so we'll
        -- hopefully never spawn in two pilots in the same place
        Where = GetPositionNear(Where, AllyMinRadiusAway, AllyMaxRadiusAway)
        Where.y = Where.y + 1.0

        -- This player is their own commander  set up their equipment.
        SetupTeam(Team)
    else
        -- Teamplay. Gotta put them near their commander. Also, always
        -- ensure the recycler/etc has been set up for this team if we
        -- know who they are
        SetupTeam(GetCommanderTeam(Team))

        -- SetupTeam will fill in the Mission.m_TeamPos[] array of positions
        -- for both the commander and offense players, so read out the
        -- results
        Where = Mission.m_TeamPos
        Where.y = TerrainFindFloor(Where.x, Where.z) + 1.0
    end

    PlayerH = BuildObject(GetPlayerODF(Team), Team, Where)
    SetRandomHeadingAngle(PlayerH)
    SetNoScrapFlagByHandle(PlayerH)

    -- If on team 0 (dedicated server team), make this object gone from the world
    if (Team == 0) then
        MakeInert(PlayerH)
    end

    if (IsTeamplayOn() and TeamBlock >= 0) then
        -- Also set up the other side too now, in case it wasn't done earlier.
        -- This puts both CTF flags on the map when the first player joins.
        SetupTeam(7 - GetCommanderTeam(Team))
    end

    return PlayerH
end

function SetupTeam(Team)
    -- Sanity checks: don't do anything that looks invalid
    if (Team < 0 or Team >= MAX_TEAMS) then
        return
    end

    -- Also, if we've already set up this team group, don't do anything
    if (IsTeamplayOn() and Mission.m_TeamIsSetUp[Team]) then
        return
    end

    local TeamRace = GetRaceOfTeam(Team)

    if (IsTeamplayOn()) then
        SetMPTeamRace(WhichTeamGroup(Team), TeamRace) -- Lock this down to prevent changes.
    end

    local Where = GetSpawnpointForTeam(Team)
    Where = GetPositionNear(Where, AllyMinRadiusAway, AllyMaxRadiusAway)

    -- Store position we created them at for later
    Mission.m_TeamPos[Team] = Where

    if (IsTeamplayOn()) then
        for i = GetFirstAlliedTeam(Team), GetLastAlliedTeam(Team) do
            if (i ~= Team) then
                Mission.m_TeamPos[i] = GetPositionNear(Where, AllyMinRadiusAway, AllyMaxRadiusAway)
            end
        end
    end

    Mission.m_TeamIsSetUp[Team] = true
end

function UpdateGameTime()
    Mission.m_ElapsedGameTime = Mission.m_ElapsedGameTime + 1

    -- Are we in a time limited game?
    if (Mission.m_RemainingGameTime > 0) then
        Mission.m_RemainingGameTime = Mission.m_RemainingGameTime - 1

        if (Mission.m_RemainingGameTime % m_GameTPS == 0) then
            -- Convert tenth-of-second ticks to hour/minutes/seconds format.
            local Seconds = Mission.m_RemainingGameTime / m_GameTPS
            local Minutes = Seconds / 60
            local Hours = Minutes / 60

            -- Lop seconds and minutes down to 0..59 once we've grabbed non-remainder out.
            Seconds = Seconds % 60
            Minutes = Minutes % 60

            if (Hours ~= 0) then
                TempMsgString = TranslateString("mission", ("Time Left %d:%02d:%02d\n"):format(Hours, Minutes, Seconds))
            else
                TempMsgString = TranslateString("mission", ("Time Left %d:%02d\n"):format(Minutes, Seconds))
            end

            SetTimerBox(TempMsgString)

            -- Also print this out more visibly at important times....
            if (Hours == 0) then
                -- Every 5 minutes down to 10 minutes, then every minute
                -- thereafter.
                if (Seconds == 0 and (Minutes <= 10 or Minutes % 5 == 0)) then
                    AddToMessagesBox(TempMsgString)
                else
                    -- Every 5 seconds when under a minute is remaining.
                    if (Minutes == 0 and (Seconds % 5 == 0)) then
                        AddToMessagesBox(TempMsgString)
                    end
                end
            end
        end

        -- Game over due to timeout?
        if (Mission.m_RemainingGameTime == 0) then
            NoteGameoverByTimelimit()
            DoGameover(10.0)
        end
    else
        -- Infinite time game. Periodically update ingame clock.
        if (Mission.m_ElapsedGameTime % m_GameTPS == 0) then
            -- Convert tenth-of-second ticks to hour/minutes/seconds format.
            local Seconds = Mission.m_ElapsedGameTime / m_GameTPS
            local Minutes = Seconds / 60
            local Hours = Minutes / 60

            -- Lop seconds and minutes down to 0..59 once we've grabbed
            -- non-remainder out.
            Seconds = Seconds % 60
            Minutes = Minutes % 60

            if (Hours ~= 0) then
                TempMsgString = TranslateString("mission", ("Mission Time %d:%02d:%02d"):format(Hours, Minutes, Seconds))
            else
                TempMsgString = TranslateString("mission", ("Mission Time %d:%02d"):format(Minutes, Seconds))
            end

            SetTimerBox(TempMsgString)
        end
    end
end

function UpdateEmptyVehicles()
    -- Early-exit if no vehicles tracked.
    if (Mission.m_NumVehiclesTracked == 0) then
        return
    end

    local anyChanges = false

    for i = 0, MAX_VEHICLES_TRACKED - 1 do
        if (Mission.m_EmptyVehicles[i] ~= nil) then
            local TempH = Mission.m_EmptyVehicles[i]
            if (not IsAround(Mission.m_EmptyVehicles[i])) then
                Mission.m_EmptyVehicles[i] = nil
                anyChanges = true
            elseif (IsPlayer(Mission.m_EmptyVehicles[i])) then
                Mission.m_EmptyVehicles[i] = nil
                anyChanges = true
            elseif (IsAliveAndPilot(TempH)) then
                Mission.m_EmptyVehicles[i] = nil
                anyChanges = true
            end
        end
    end

    -- Tweak the list if needed.
    if (anyChanges) then
        CrunchEmptyVehicleList()
        anyChanges = false
    end

    local CurNumPlayers = CountPlayers()
    local MaxEmpties = CurNumPlayers + bit32.rshift(CurNumPlayers, 1) + 1

    if (Mission.m_NumVehiclesTracked > MaxEmpties) then
        SelfDamage(Mission.m_EmptyVehicles[0], 1e+20)
        Mission.m_EmptyVehicles[0] = nil
        anyChanges = true
    end

    -- Tweak the list if needed.
    if (anyChanges) then
        CrunchEmptyVehicleList()
        anyChanges = false
    end
end

function CrunchEmptyVehicleList()
    local j = 0

    for i = 0, MAX_VEHICLES_TRACKED - 1 do
        if (Mission.m_EmptyVehicles[i] ~= nil) then
            Mission.m_EmptyVehicles[j] = Mission.m_EmptyVehicles[i]
            j = j + 1
        end
    end

    Mission.m_NumVehiclesTracked = j

    for j = Mission.m_NumVehiclesTracked, MAX_VEHICLES_TRACKED - 1 do
        Mission.m_EmptyVehicles[j] = nil
    end
end

function AddEmptyVehicle(NewCraft)
    if (NewCraft == nil) then
        return
    end

    if (Mission.m_NumVehiclesTracked >= MAX_VEHICLES_TRACKED) then
        UpdateEmptyVehicles()

        if (Mission.m_EmptyVehicles[0]) then
            SelfDamage(Mission.m_EmptyVehicles[0], 1e+20)
            Mission.m_EmptyVehicles[0] = nil
            CrunchEmptyVehicleList()
        end
    end

    if (Mission.m_NumVehiclesTracked < MAX_VEHICLES_TRACKED) then
        Mission.m_EmptyVehicles[Mission.m_NumVehiclesTracked] = NewCraft
        Mission.m_NumVehiclesTracked = Mission.m_NumVehiclesTracked + 1
    end
end

function CreateObjectives()
    ClearObjectives()
    AddObjective("mpobjective_dm.otf", "WHITE", -1.0) -- negative time means don't change display to show it
end

function ExecuteTrackPlayers()
    -- Go over all humans first
    for i = 1, MAX_TEAMS - 1 do
        local p = GetPlayerHandle(i)

        if (p ~= nil) then
            SetLifespan(p, -1.0) -- Ensure there's no lifespan killing this craft

            if (IsAliveAndPilot(p)) then
                -- Did they just hop out, leaving that craft w/o a pilot? Nuke that craft too.
                local lastp = Mission.m_LastPlayerCraftHandle[i]

                if (IsAround(lastp)) then
                    if (not IsAliveAndPilot(lastp)) then
                        SelfDamage(Mission.m_LastPlayerCraftHandle[i], 1e+20)
                    else
                        -- Not ship-only mode. Add this to empties list
                        if (Mission.m_NumVehiclesTracked < MAX_VEHICLES_TRACKED) then
                            Mission.m_EmptyVehicles[Mission.m_NumVehiclesTracked] = Mission.m_LastPlayerCraftHandle[i]
                            Mission.m_NumVehiclesTracked = Mission.m_NumVehiclesTracked + 1
                        end
                    end

                    Mission.m_LastPlayerCraftHandle[i] = nil
                end
            end
        else
            Mission.m_LastPlayerCraftHandle[i] = p
        end
    end
end

function RespawnPilot(DeadObjectHandle, Team)
    local Where

    if (not IsTeamplayOn() or Team < 1) then
        Where = GetRandomSpawnpoint()
        Where = GetPositionNear(Where, AllyMinRadiusAway, AllyMaxRadiusAway)
    else
        Where = Mission.m_TeamPos
        Where = GetPositionNear(Where, AllyMinRadiusAway, AllyMaxRadiusAway)
    end

    if (Team > 0 and Team < MAX_TEAMS) then
        Mission.m_SpawnedAtTime[Team] = Mission.m_ElapsedGameTime
    end

    -- Randomize starting position somewhat
    Where = GetPositionNear(Where, RespawnMinRadiusAway, RespawnMaxRadiusAway)

    if (not Mission.m_RespawnAtLowAltitude) then
        Where.y = Where.y + RespawnPilotHeight -- Bounce them in the air to prevent multi-kills
    end

    local Race = GetRaceOfTeam(Team)
    local NewPerson = BuildObject(GetInitialPlayerPilotODF(Race), Team, Where)

    SetAsUser(NewPerson, Team)
    SetNoScrapFlagByHandle(NewPerson)
    AddPilotByHandle(NewPerson)
    SetRandomHeadingAngle(NewPerson)

    Mission.m_Flying[Team] = true -- build a craft when they land.

    -- If on team 0 (dedicated server team), make this object gone from the world
    if (Team == 0) then
        MakeInert(NewPerson)
    end

    return DLLHandled -- Dead pilots get handled by DLL
end

function DeadObject(DeadObjectHandle, KillersHandle, WasDeadPerson, WasDeadAI)
    -- Get team number of who got waxed.
    local DeadTeam = GetTeamNum(DeadObjectHandle)
    local IsSpawnKill = false

    -- Flip scoring if this is a spawn kill.
    local SpawnKillMultiplier = 1
    local KillerIsAI = not IsPlayer(KillersHandle)

    -- Spawnkill is a non-suicide, on a human by another human.
    if (DeadObjectHandle ~= KillersHandle and DeadTeam > 0 and DeadTeam < MAX_TEAMS and Mission.m_SpawnedAtTime[DeadTeam] > 0) then
        IsSpawnKill = (Mission.m_ElapsedGameTime - Mission.m_SpawnedAtTime[DeadTeam]) < Mission.m_MaxSpawnKillTime
    end

    if (IsSpawnKill) then
        SpawnKillMultiplier = -1
        TempMsgString = TranslateString("mission",
            ("Spawn kill by %s on %s\n"):format(GetPlayerName(KillersHandle), GetPlayerName(DeadObjectHandle)))
        AddToMessagesBox(TempMsgString)
    end

    if (DeadTeam ~= 0) then
        if (DeadObjectHandle ~= KillersHandle and not IsAlly(DeadObjectHandle, KillersHandle)) then
            if (not WasDeadAI) then
                if (KillForAIKill) then
                    AddKills(KillersHandle, 1 * SpawnKillMultiplier)
                end

                if (PointsForAIKill) then
                    if (WasDeadPerson) then
                        AddScore(KillersHandle, ScoreForKillingPerson * SpawnKillMultiplier)
                    else
                        AddScore(KillersHandle, ScoreForKillingCraft * SpawnKillMultiplier)
                    end
                end
            end
        else
            if (not WasDeadAI) then
                if (KillForAIKill) then
                    AddKills(KillersHandle, -1 * SpawnKillMultiplier)
                end

                if (PointsForAIKill) then
                    if (WasDeadPerson) then
                        AddScore(KillersHandle, -ScoreForKillingPerson * SpawnKillMultiplier)
                    else
                        AddScore(KillersHandle, -ScoreForKillingCraft * SpawnKillMultiplier)
                    end
                end
            end
        end

        if (not WasDeadAI) then
            AddDeaths(DeadObjectHandle, 1 * SpawnKillMultiplier)

            if (WasDeadPerson) then
                AddScore(DeadObjectHandle, ScoreForDyingAsPerson * SpawnKillMultiplier)
            else
                AddScore(DeadObjectHandle, ScoreForDyingAsCraft * SpawnKillMultiplier)
            end

            if (KillerIsAI) then
               _AIController.HandleHumanKilled()
            end
        end

        if (Mission.m_KillLimit > 0 and GetKills(KillersHandle) >= Mission.m_KillLimit) then
            NoteGameoverByKillLimit(KillersHandle)
            DoGameover(10.0)
        end
    else
        return DoEjectPilot
    end

    if (WasDeadAI) then
        _AIController.HandleDeadObject(DeadObjectHandle)
        return DLLHandled
    else
        if (WasDeadPerson) then
            return RespawnPilot(DeadObjectHandle, DeadTeam)
        else
            Mission.m_Flying[DeadTeam] = true
            return DoEjectPilot
        end
    end
end

function PreSnipe(curWorld, shooterHandle, victimHandle, ordnanceTeam, pOrdnanceODF)
    -- If Friendly Fire is off, then see if we should disallow the snipe
    if (not Mission.m_bIsFriendlyFireOn) then
        local relationship = GetTeamRelationship(shooterHandle, victimHandle)

        if (relationship == TEAMRELATIONSHIP_SAMETEAM or relationship == TEAMRELATIONSHIP_ALLIEDTEAM) then
            -- Allow snipes of items on team 0/perceived team 0, as long
            -- as they're not a local/remote player
            if (IsPlayer(victimHandle) or (GetTeamNum(victimHandle) ~= 0)) then
                return PRESNIPE_ONLYBULLETHIT
            end
        end

        -- Friendly fire is off, and we're about to kill the pilot of the hit object.
        -- Set its team to 0
        SetPerceivedTeam(victimHandle, 0)
    end

    -- If we got here, allow the pilot to be killed
    return PRESNIPE_KILLPILOT
end
