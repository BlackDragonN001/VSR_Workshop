-- Strategy02.lua
-- Converted from Strategy02.cpp

-- Required Support Files
require('_GlobalHandler');
require('_GlobalVariables');
require('_DLLUtils');
local _StartingVehicles = require('_StartingVehicles');

local Vector = SetVector

local function clamp(val, min, max)
	return math.max(min, math.min(val, max))
end

local MAX_HARDPOINTS = 5

-- Constants
local VEHICLE_SPACING_DISTANCE = 20.0
-- ---------- Scoring Values-- these are delta scores, added to current score --------
local ScoreDecrementForSpawnKill = 500
local ScoreForWinning = 100
local MAX_AI_TEAMS = 5
-- MAX_TEAMS is defined in _GlobalVariables (16)

-- How long a "spawn" kill lasts, in tenth of second ticks. If the
-- time since they were spawned to current is less than this, it's a
-- spawn kill, and not counted. Todo - Make this an ivar for dm?
local MaxSpawnKillTime = 15
-- -----------------------------------------------

-- Max distance (in x,z dimensions) on a pilot respawn. Actual value
-- used will vary with random numbers, and will be +/- this value
local RespawnDistanceAwayXZRange = 32.0
-- Max distance (in y dimensions) on a pilot respawn. Actual value
-- used will vary with random numbers, and will be [0..this value)
local RespawnDistanceAwayYRange = 8.0

-- How high up to respawn a pilot
local RespawnPilotHeight = 200.0

-- How far allies will be from the commander's position
local AllyMinRadiusAway = 30.0
local AllyMaxRadiusAway = 60.0

-- How long (in seconds) from noticing gameover, to the actual kicking
-- out back to the shell.
local endDelta = 10.0

-- Tuning distances for GetSpawnpointForTeam()

-- Friendly spawnpoint: Max distance away for ally
local FRIENDLY_SPAWNPOINT_MAX_ALLY = 100.0
-- Friendly spawnpoint: Min distance away for enemy
local FRIENDLY_SPAWNPOINT_MIN_ENEMY = 400.0

-- Random spawnpoint: min distance away for enemy
local RANDOM_SPAWNPOINT_MIN_ENEMY = 450.0

-- Mission Table
Mission = {
	-- Member Variables
	ThugScavengerList = {}, -- { {ThugScavengerObject = h, ScavengerTeam = int}, ... }
	ThugPilotList = {},     -- { {ThugPilotObject = h, SwitchTickTimer = int}, ... }
	EmptyShipList = {},     -- { {EmptyShipObject = h, InvulnerabilityTime = int, SavedHealth = int}, ... }
	MorphTankList = {},		-- { {MorphTankObject = h, CmdSet = bool }, ... }
	CommBunkerList = {},	-- { {CommBunkerObject = h, CommBunkerBaseSlot = int}, ... }
	
	PlayerShipODF = {},         -- [1..MAX_TEAMS]
	SavedPilotODF = {},         
	PlayerSavedName = {},       
	PlayerShipWeapons = {},     -- [1..MAX_TEAMS][0..4]
	PlayerPilotWeapons = {},    
	PlayerPilotLocalAmmo = {},  -- [1..MAX_TEAMS][0..4]
	PlayerMatrix = {},          
	PlayerVelocity = {},        
	PlayerOmega = {},           
	
	MapAmbientSound = "",
	EmptyShipODF = {},          
	
	m_GameTPS = 20,
	
	m_TotalGameTime = 0,
	m_RemainingGameTime = 0,
	m_ElapsedGameTime = 0,
	m_KillLimit = 0,
	m_PointsForAIKill = false,
	m_KillForAIKill = false,
	m_RespawnWithSniper = 0,
	m_TurretAISkill = 0,
	m_NonTurretAISkill = 0,
	m_StartingVehiclesMask = 0,
	m_SpawnedAtTime = {}, 
	m_AllyTeams = {},     
	m_RecyInvulnerabilityTime = 0,
	
	m_NumSpawnPoints = 0,
	NumCommanders = 0,
	NextAutoAssignTeam = 0,
	CommanderTeam = {},   
	ThugCounter = {},     
	
	m_AIRace = {},        
	m_HumanForce = 0,
	m_CPUForce = 0,
	m_CPUTurretAISkill = 0,
	m_CPUNonTurretAISkill = 0,
	m_LastTauntPrintedAt = 0,
	m_PlayersSpawned = 0,
	
	m_NumCaptureGoals = 0,
	m_CaptureGoalTime = {},         
	m_CaptureGoalTeam = {},         
	m_GoalBeingCaptured = {},       
	m_CaptureTime = 0,
	m_GameType = 0,
	
	m_PilotInvunerability = 0,
	m_PilotInvTime = {},            
	m_SavedPilotInvHealth = {},     
	m_PilotInvUser = {},            
	
	m_SavedPlayerHealth = {},       
	m_SavedPlayerAmmo = {},         
	m_SavedPlayerTeamGroup = {},    
	m_SavedPlayerScrap = {},        
	m_RestorePlayers = 0,
	
	BuildEmpty = {},                
	
	m_MorphTankAutoDeployType = 0,
	
	m_DidInit = false,
	StopScript = false,
	m_HadMultipleFunctioningTeams = false,
	m_TeamIsSetUp = {},             
	m_NotedRecyclerLocation = {},   
	m_HasAllies = {},               
	m_GameOver = false,
	m_CreatingStartingVehicles = false,
	m_RespawnAtLowAltitude = false,
	m_bIsFriendlyFireOn = false,
	m_ThugFlag = {},                
	m_TeamHasCommander = {},        
	m_SetThugPilotFlag = false,
	CheckedSVar3 = false,
	m_IsMPI = false,
	m_SetFirstAIP = false,
	SpawnAI = false,
	
	m_CaptureGoalObjectify = {},    
	m_CaptureGoalIsSwitching = {},  -- Matrix [MAX_TEAMS][MAX_GOALS]
	m_DualCapture = {},             
	m_TeamIsCapturing = {},         
	
	m_GiveWeaponsBack = {},         
	m_SavedPlayerDeployed = {},     
	IsCameraPod = {},               
	
	m_SpawnFacingCenter = false,
	
	m_TeamPos = {},                 -- [1..MAX_TEAMS] -> Vector
	m_FRIENDLY_SPAWNPOINT_MAX_ALLY = FRIENDLY_SPAWNPOINT_MAX_ALLY,
	m_FRIENDLY_SPAWNPOINT_MIN_ENEMY = FRIENDLY_SPAWNPOINT_MIN_ENEMY,
	m_RANDOM_SPAWNPOINT_MIN_ENEMY = RANDOM_SPAWNPOINT_MIN_ENEMY,
	m_SavedPlayerLocalAmmo = {},    
	
	m_RecyclerHandles = {},         
	m_CaptureGoals = {},            
	UserTarget = {}, 
	
	CustomAIPNameBase = "",
	CaptureTarget = {},
	NumCaptureTargetODFs = 0,
	CaptureRandom = false
}

-- Temporary strings for blasting stuff into for output. NOT to be
-- used to store anything you care about.
local TempMsgString = ""

-- Temporary name for blasting ODF names into while building
-- them. *not* saved, do *not* count on its contents being valid
-- next time the dll is called.
local TempODFName = ""

-- Special Handle for Audio. -GBD
local EasterEggSound = nil

-- Helper: Initialize Arrays
for i = 1, MAX_TEAMS - 1 do
	Mission.PlayerShipODF[i] = ""
	Mission.SavedPilotODF[i] = ""
	Mission.PlayerSavedName[i] = ""
	Mission.PlayerShipWeapons[i] = {} 
	Mission.PlayerPilotWeapons[i] = {}
	Mission.PlayerPilotLocalAmmo[i] = {}
	Mission.EmptyShipODF[i] = ""
	Mission.m_SpawnedAtTime[i] = 0
	Mission.m_AllyTeams[i] = 0
	Mission.CommanderTeam[i] = 0
	Mission.ThugCounter[i] = 0
	Mission.m_CaptureGoalTime[i] = 0
	Mission.m_CaptureGoalTeam[i] = 0
	Mission.m_GoalBeingCaptured[i] = 0
	Mission.m_PilotInvTime[i] = 0
	Mission.m_SavedPilotInvHealth[i] = 0
	Mission.m_SavedPlayerHealth[i] = 0
	Mission.m_SavedPlayerAmmo[i] = 0
	Mission.m_SavedPlayerTeamGroup[i] = 0
	Mission.m_SavedPlayerScrap[i] = 0
	Mission.BuildEmpty[i] = 0
	Mission.m_TeamIsSetUp[i] = false
	Mission.m_NotedRecyclerLocation[i] = false
	Mission.m_HasAllies[i] = false
	Mission.m_ThugFlag[i] = false
	Mission.m_TeamHasCommander[i] = false
	Mission.m_CaptureGoalObjectify[i] = false
	Mission.m_CaptureGoalIsSwitching[i] = {} 
	for k=0, 16 do Mission.m_CaptureGoalIsSwitching[i][k] = false end
	Mission.m_DualCapture[i] = false
	Mission.m_TeamIsCapturing[i] = false
	Mission.m_GiveWeaponsBack[i] = false
	Mission.m_SavedPlayerDeployed[i] = false
	Mission.IsCameraPod[i] = false
	Mission.m_SavedPlayerLocalAmmo[i] = {}
	Mission.m_RecyclerHandles[i] = nil
	Mission.m_CaptureGoals[i] = nil
	Mission.UserTarget[i] = nil
	Mission.m_PilotInvUser[i] = nil
	
	Mission.m_TeamPos[i] = Vector(0,0,0)
	
	for j = 0, 5 do
		Mission.PlayerShipWeapons[i][j] = ""
		Mission.PlayerPilotWeapons[i][j] = ""
		Mission.PlayerPilotLocalAmmo[i][j] = 0.0
		Mission.m_SavedPlayerLocalAmmo[i][j] = 0.0
	end
end
for i = 0, 5 do
	Mission.m_AIRace[i] = 0
end


-- Save/Load
function Save()
	-- Make sure we always call this
	return _StartingVehicles.Save(), Mission
end

function Load(StartingVehicleData, MissionData)
	Mission.m_GameTPS = EnableHighTPS()
	SetAutoGroupUnits(false)
	-- Make sure we always call this
	-- We're a 1.3 DLL.
	AllowRandomTracks(true)
	WantBotKillMessages()
	
	_StartingVehicles.Load(StartingVehicleData)
	
	if MissionData then
		for k, v in pairs(MissionData) do
			Mission[k] = v
		end
	end

	-- Start playing the musics.
	if (Mission.m_DidInit) and (DoesFileExist(Mission.MapAmbientSound)) then
		StopAudio(EasterEggSound)
		EasterEggSound = StartAudio2D(Mission.MapAmbientSound, -1, 0.0, 44100.0, true, false)
	end

	UpdateObjectives()
end

function GetNextRandomVehicleODF(Team)
	return GetPlayerODF(Team)
end

function UpdateObjectives()
	ClearObjectives()
	if Mission.m_GameType == 4 then -- Capture mode.
		AddObjective("mpobjective_stcap.otf", "WHITE", -1.0)
	else
		AddObjective("mpobjective_st.otf", "WHITE", -1.0)
	end
end



function AddObject(h)
	local ODFName = GetCfg(h) or ""

	-- Cutoff :# at the end.
	if not DoesODFExist(ODFName) then
		local colonPos = string.find(ODFName, ":")
		if colonPos then
			ODFName = string.sub(ODFName, 1, colonPos - 1)
		end
	end

	-- Testing gameover logic (commented out in C++)
	-- SetCurHealth(h, 1)
	-- SetMaxHealth(h, 1)

	local UseTurretSkill = Mission.m_TurretAISkill
	local UseNonTurretSkill = Mission.m_NonTurretAISkill
	
	-- Note: this is the proper way to determine if a handle points to a
	-- turret. NM 1/29/05
	local ObjClass = GetClassLabel(h) or ""
	local isTurret = (string.lower(ObjClass) == "class_turrettank")

	-- Start of game, remove scrap flag.
	if Mission.m_ElapsedGameTime == 0 then
		local RemoveScrap = GetVarItemInt("network.session.ivar117")
		if (RemoveScrap ~= 0) and (string.lower(ObjClass) == "class_scrap") then
			RemoveObject(h)
			return -- done here.
		end
	end

	local Team = GetTeamNum(h)

	-- If this is MPI, and not a human team. -GBD
	if Mission.m_IsMPI and (Team > 10) then
		AddToDispatch(h, 15.0, false, 0, false) -- Tie into DispatchHelper. -GBD

		UseTurretSkill = Mission.m_CPUTurretAISkill
		UseNonTurretSkill = Mission.m_CPUNonTurretAISkill
	elseif not Mission.m_IsMPI then -- NOT MPI
		-- Remove NAV cameras outside map bounds.
		if string.lower(ObjClass) == "class_navbeacon" then
			local Pos = GetPosition(h)
			local mapInfo = GetMapInfo() -- Assuming GetMapInfo returns a table with Min/Max Width/Depth
			if (Pos.x > mapInfo.MaxWidth) or
				(Pos.x < mapInfo.MinWidth) or
				(Pos.z > mapInfo.MaxDepth) or
				(Pos.z < mapInfo.MinDepth) then
				RemoveObject(h)
			end
		end
	end

	-- See if this is a turret, 
	if isTurret then
		SetSkill(h, UseTurretSkill)
	else
		-- Not a turret. Use regular skill level
		SetSkill(h, UseNonTurretSkill)
	end

	-- Count all spawnpoints on the map
	if (Mission.m_ElapsedGameTime < 1) and (string.lower(ObjClass) == "class_spawnbuoy") then
		Mission.m_NumSpawnPoints = Mission.m_NumSpawnPoints + 1
	end

	-- Also see if this is a new recycler vehicle
	local lowerObjClass = string.lower(ObjClass)
	local IsRecyVehicle = (lowerObjClass == "class_recyclervehicle") or (lowerObjClass == "class_recyclervehicleh") or (lowerObjClass == "class_recycler")
	
	if IsRecyVehicle then
		-- If we're not tracking a recycler vehicle for this team right now, store it.
		if (not Mission.m_RecyclerHandles[Team]) or (not IsAround(Mission.m_RecyclerHandles[Team])) then
			Mission.m_RecyclerHandles[Team] = h
		end

		-- Now crack her open, check the Empty Vehicle ODF for empty invulnerability.
		if (Mission.BuildEmpty[Team] == 0) and (lowerObjClass == "class_recycler") then
			Mission.BuildEmpty[Team] = GetODFInt(h, "FactoryClass", "buildEmptyItem", 0)
			if Mission.BuildEmpty[Team] > 0 then
				local DesiredValue = "BuildItem" .. Mission.BuildEmpty[Team]
				Mission.EmptyShipODF[Team] = GetODFString(h, "FactoryClass", DesiredValue)
			end
		end
	end

	local AddToList = true
	-- Special things for FFA Mode with Thugs. -GBD
	if (not IsTeamplayOn()) or (Mission.m_IsMPI) then
		-- Scavenger code: added to handle thug scavs in FFA Alliance mode. -GBD
		if (lowerObjClass == "class_scavenger") or (lowerObjClass == "class_scavengerh") then
			for _, v in ipairs(Mission.ThugScavengerList) do
				if v.ThugScavengerObject == h then
					AddToList = false
					break
				end
			end
			if AddToList then
				table.insert(Mission.ThugScavengerList, {ThugScavengerObject = h, ScavengerTeam = Team})
			end
		-- Thug code, adding thugs to be thugified.
		elseif (lowerObjClass == "class_person") and (not IsPlayer(h)) then
			for _, v in ipairs(Mission.ThugPilotList) do
				if v.ThugPilotObject == h then
					AddToList = false
					break
				end
			end
			if AddToList then
				table.insert(Mission.ThugPilotList, {ThugPilotObject = h, SwitchTickTimer = (15 * Mission.m_GameTPS)})
			end
		end
	end

	-- VSR Empty Ship Invulnerability code. -GBD
	if Mission.m_PilotInvunerability > 0 then
		if (IsAround(Mission.m_RecyclerHandles[Team])) and (Mission.BuildEmpty[Team] > 0) then
			-- Checking ODFName Match from earlier GetObjInfo
			if string.lower(ODFName) == string.lower(Mission.EmptyShipODF[Team]) then
				AddToList = true
				for _, v in ipairs(Mission.EmptyShipList) do
					if v.EmptyShipObject == h then
						AddToList = false
						break
					end
				end
				if AddToList then
					local savedHealth = GetMaxHealth(h)
					SetMaxHealth(h, 0)
					table.insert(Mission.EmptyShipList, {EmptyShipObject = h, InvulnerabilityTime = Mission.m_PilotInvunerability, SavedHealth = savedHealth})
				end
			end
		end
	end


	-- Default morphtank behavior
	if Mission.m_MorphTankAutoDeployType > 0 then
	
		if (lowerObjClass == "class_morphtank") then
			for _, v in ipairs(Mission.MorphTankList) do
				if v.MorphTankObject == h then
					AddToList = false
					break
				end
			end
			if AddToList then
				table.insert(Mission.MorphTankList, {MorphTankObject = h, CmdSet = false})
			end

	end

	-- Find which baseSlot# this is.
	local TeamSlot = 0;
	local CategoryType = GetCategoryTypeOverride(h)
	if (CategoryType == -1) then
		CategoryType = GetCategoryType(h)
	end
	if (CategoryType > 0 and CategoryType < 10) then
		TeamSlot = CategoryType
	end

	-- Commbunker teamslot re-assignment.
	if (TeamSlot > 0 and -- Base Slot.
	(lowerObjClass == "class_commbunker") or
	(lowerObjClass == "class_commtower")) then
		for _, v in ipairs(Mission.CommBunkerList) do
			if v.CommBunkerObject == h then
				AddToList = false
				break
			end
		end
		if AddToList then
			table.insert(Mission.CommBunkerList, {CommBunkerObject = h, CommBunkerBaseSlot = TeamSlot})
		end
	end
end



function DeleteObject(h)

	local Team = GetTeamNum(h)
	if (Mission.m_RestorePlayers ~= 0) and (IsPlayer(h)) and (not GetPlayerHandle(Team)) then
		SetNoScrapFlagByHandle(h)
	end

	-- If this was a commbunker that was remote activated...
	local PrevSlot = 0
	for _, iter in ipairs(Mission.CommBunkerList) do
		if (h == iter.CommBunkerObject) then
			PrevSlot = iter.CommBunkerBaseSlot
			break -- found it.
		end
	end
	-- Find a potential replacement slot.
	for _, iter in ipairs(Mission.CommBunkerList) do
		if ((h ~= iter.CommBunkerObject) and (iter.CommBunkerBaseSlot == PrevSlot)) then
			ResetTeamSlot(iter.CommBunkerObject)
			break -- found it.
		end
	end

	--[[ !! Temp buggery. -GBD
	// Special Scav stuff for MPI:
	if((m_IsMPI) && (IsTeamplayOn()))
	{
		for (std::vector<ThugScavengerClass>::iterator iter = ThugScavengerList.begin(); iter != ThugScavengerList.end(); ++iter)
		{
			// This is before our clean up, make sure it's still around first.
			if(h == iter->ThugScavengerObject)
			{
				//int Team = GetTeamNum(iter->ThugScavengerObject);

				if((Team == 6) && (iter->ScavengerTeam > 6) && (iter->ScavengerTeam < 11)) // This is an AI Team on "TeamPlay" Team 2.
				{
					char ObjClass[MAX_ODF_LENGTH] = {0};
					GetObjInfo(iter->ThugScavengerObject, Get_GOClass, ObjClass);

					// This deployed, it automatically switched to Team 6. Swap it back.
					if((Team != iter->ScavengerTeam) && (_stricmp(ObjClass, "CLASS_EXTRACTOR") == 0) || (_stricmp(ObjClass, "CLASS_SILO") == 0))
					{
						// Get ScrapHold value.
						int TempHold = 0;
						char TempODF[MAX_ODF_LENGTH] = {0};
						char TempODF2[MAX_ODF_LENGTH] = {0};
						GetObjInfo(iter->ThugScavengerObject, Get_ODF, TempODF);

						if (OpenODF2(TempODF))
						{
							// Grab out the next ODF, if present.
							GetODFString(TempODF, "GameObjectClass", "classlabel", MAX_ODF_LENGTH, TempODF2); // Grab the sound file, with allowance for a large filename.
							CombineStrings2(TempODF2, TempODF2, ".odf"); // Add .odf to the end.

							while ((_stricmp(TempODF, TempODF2) != 0) &&
								(!GetODFInt(TempODF, "ExtractorClass", "scrapHold", &TempHold)) &&
								(!GetODFInt(TempODF, "SiloClass", "scrapHold", &TempHold)) &&
								(OpenODF2(TempODF2))) // Go all the way until you can't go any further.
							{
								strcpy_s(TempODF, TempODF2); // Copy TempODF2 into TempODF, then re-grab TempODF2 to try again.
								GetODFString(TempODF, "GameObjectClass", "classlabel", MAX_ODF_LENGTH, TempODF2); // Grab the sound file, with allowance for a large filename.
								CombineStrings2(TempODF2, TempODF2, ".odf"); // Add .odf to the end.
							}
						}

						int TempMaxTeam = GetMaxScrap(Team);
						int TempMaxScav = GetMaxScrap(iter->ScavengerTeam);

						SetTeamNum(iter->ThugScavengerObject, iter->ScavengerTeam); // Set it to the correct Team.
						// Correct scraphold.
						AddMaxScrap(iter->ScavengerTeam, -TempHold);
						AddMaxScrap(Team, TempHold);

						// Lets log how much scrap to see if we need to mess with that manually.
						sprintf_s(TempMsgString, "DESTROYED SCAV Team: %d to Team: %d. OldMax: %d, %d NewMax: %d, %d, Curr: %d, %d", Team, iter->ScavengerTeam, TempMaxTeam, TempMaxScav, GetMaxScrap(Team), GetMaxScrap(iter->ScavengerTeam), GetScrap(Team), GetScrap(iter->ScavengerTeam));
						PrintConsoleMessage(TempMsgString);

					}
				}
				break; // We found it.
			}
		}
	}
	]]
end



function SetCPUAIPlan(Team, NameOverride)
	if not Mission.CheckedSVar3 then
		Mission.CheckedSVar3 = true
		local pContents = GetCheckedNetworkSvar(3, NETLIST_AIPs)
		if (pContents == nil) or (pContents == "") then
			-- Use the default 1.3 naming scheme if not specified.
			Mission.CustomAIPNameBase = "VSR_"
		else
			Mission.CustomAIPNameBase = pContents
		end
	end

	local AIPFile = ""
	local Random = math.floor(GetRandomFloat(3.0))
	if Random > 2 then
		Random = 2
	end
	-- sprintf_s(AIPFile, "%s%c%d_%d.aip", CustomAIPNameBase, GetRace(m_RecyclerHandles[Team]), NameOverride, Random); //-6
	local cpuRace = GetRace(Mission.m_RecyclerHandles[Team])
	if type(cpuRace) == "number" then cpuRace = string.char(cpuRace) end
	AIPFile = string.format("%s%s%d_%d.aip", Mission.CustomAIPNameBase, cpuRace, NameOverride, Random)

	if not DoesFileExist(AIPFile) then
		AIPFile = string.format("%s%s%d_0.aip", Mission.CustomAIPNameBase, cpuRace, NameOverride) -- -6
	end
	SetAIP(AIPFile, Team)

	if Mission.m_SetFirstAIP then
		DoTaunt(TAUNTS_Random)
	end

	Mission.m_SetFirstAIP = true
end



-- Gets the initial player vehicle as selected in the shell
function GetInitialPlayerVehicleODF(Team)
	return GetPlayerODF(Team)
end

-- Given a race identifier, get the pilot back (used during a respawn)
function GetInitialPlayerPilotODF(Race, Team, IsRespawning)
	Team = Team or 0
	if IsRespawning == nil then IsRespawning = true end
	local TempODFName = ""
	if Team > 0 then
		if IsTeamplayOn() then
			Team = GetCommanderTeam(Team)
		end

		local TempODF = GetOdf(Mission.m_RecyclerHandles[Team])
		local TempODF2 = ""

		if (TempODF ~= nil) and (TempODF ~= "") then
			-- Grab the classlabel.
			local classLabel = GetODFString(TempODF, "GameObjectClass", "classlabel")
			if classLabel and (classLabel ~= "") then
				TempODF2 = classLabel .. ".odf"
			end
		end

		-- 0 = Start w/ sniper, No respawn, 
		-- 1 = Start w/ sniper, Respawn w/ sniper, 
		-- 2 = Start No sniper, No respawn.
		local KeyName = "PilotRespawnWithOutSniper"
		if ((not IsRespawning) and (Mission.m_RespawnWithSniper < 2)) or
			((IsRespawning) and (Mission.m_RespawnWithSniper == 1)) then
			KeyName = "PilotRespawnWithSniper"
		end

		TempODFName = GetODFString(TempODF, "GameObjectClass", KeyName)
		if (TempODFName == "") and (TempODF2 ~= "") then
			TempODFName = GetODFString(TempODF2, "GameObjectClass", KeyName)
		end
	end

	if (TempODFName == "") or (Team == 0) then
		if ((not IsRespawning) and (Mission.m_RespawnWithSniper < 2)) or
			((IsRespawning) and (Mission.m_RespawnWithSniper == 1)) then
			TempODFName = "ispilo" -- With sniper.
		else
			TempODFName = "isuser_m" -- Note-- this is the sniper-less variant for a respawn
		end

		if Race then
			if type(Race) == "number" then
				Race = string.char(Race)
			end
			-- Replace first char with Race char
			-- Lua strings are immutable, need concatenation
			TempODFName = Race .. string.sub(TempODFName, 2)
		end
		
		if not DoesODFExist(TempODFName) then
			local TempMsgString = string.format("ERROR: '%s' does not exist. Giving you pilot DEFAULT ISDF! FIX IT!", TempODFName)
			PrintConsoleMessage(TempMsgString)

			TempODFName = "i" .. string.sub(TempODFName, 2)
		end
	end
	return TempODFName
end



-- Given a race identifier, get the recycler ODF back
function GetInitialRecyclerODF(Race)
	local TempODFName = ""
	local pContents = GetCheckedNetworkSvar(5, NETLIST_Recyclers)

	if (pContents ~= nil) and (pContents ~= "") then
		TempODFName = pContents
	else
		TempODFName = "ivrecy_m"
	end
	
	if Race then
		TempODFName = Race .. string.sub(TempODFName, 2)
	end
	return TempODFName
end

-- Given a race identifier, get the scavenger ODF back
function GetInitialScavengerODF(Race)
	local TempODFName = "ivscav"
	if Race then
		TempODFName = Race .. string.sub(TempODFName, 2)
	end
	return TempODFName
end

-- Given a race identifier, get the constructor ODF back
function GetInitialConstructorODF(Race)
	local TempODFName = "ivcons"
	if Race then
		TempODFName = Race .. string.sub(TempODFName, 2)
	end
	return TempODFName
end

-- Given a race identifier, get the healer (service truck) ODF back
function GetInitialHealerODF(Race)
	local TempODFName = "ivserv"
	if Race then
		TempODFName = Race .. string.sub(TempODFName, 2)
	end
	return TempODFName
end







-- Sees if this is a m_HumanRecycler vehicle ODF, and returns the race
-- ('a'..'z') if true. Returns 0 if not a m_HumanRecycler.
function IsRecyclerODF(h)
	if not h then return 0 end

	if IsRecycler(h) then
		local ODFName = GetCfg(h) or ""
		if ODFName ~= "" then
			-- return first char
			return string.sub(ODFName, 1, 1)
		end
	end

	-- fallback: not a m_HumanRecycler.
	return 0
end

-- Builds a starting vehicle on the specified team with either ODF1
-- (preferred, if found) or ODF2 as its name, modified by the
-- race. Sets group, if specified. Returns the handle
-- Consolidated vector/char* overloads into one function
function BuildStartingVehicle(aTeam, aRace, ODF1, ODF2, Where, aGrp)
	aGrp = aGrp or -1
	local TempODF = ODF1
	
	-- Ensure aRace is a character
	if type(aRace) == "number" then
		aRace = string.char(aRace)
	end
	
	-- Apply race char
	if aRace then
		TempODF = aRace .. string.sub(TempODF, 2)
	end
	
	if not DoesODFExist(TempODF) then
		-- fallback to ODF2
		TempODF = ODF2
		if aRace then
			TempODF = aRace .. string.sub(TempODF, 2)
		end
	end

	local h = BuildObject(TempODF, aTeam, Where)
	if h and (aGrp >= 0) then
		SetGroup(h, aGrp)
	end
	return h
end




-- Sets up the side's commander's extra vehicles, such a recycler or
-- more.  Does *not* create the player vehicle for them, 
-- however. [That's to be done in SetupPlayer.]  Safe to be called
-- multiple times for each player on that team
--
-- If Teamplay is off, this function is called once per player.
--
-- If Teamplay is on, this function is called only on the
-- _defensive_ team number for an alliance.
function SetupTeam(Team)
	if (Team < 1) or (Team >= MAX_TEAMS) then return end
	if Mission.m_TeamIsSetUp[Team] then return end

	if (Team == 1) and (Mission.m_IsMPI) then
		DoTaunt(TAUNTS_GameStart)
	end
	
	local TeamRaceH = GetRaceOfTeam(Team)
	if IsTeamplayOn() then
		SetMPTeamRace(WhichTeamGroup(Team), TeamRaceH) -- Lock this down to prevent changes.
	end

	local spawnpointPosition = Vector(0, 0, 0)
	
	if not Mission.m_IsMPI then
		-- First pass: see if a spawnpoint exists with this team #
		spawnpointPosition = GetSpawnpointForTeam(Team, Mission.m_AllyTeams[Team], FRIENDLY_SPAWNPOINT_MAX_ALLY, FRIENDLY_SPAWNPOINT_MIN_ENEMY, RANDOM_SPAWNPOINT_MIN_ENEMY)
	else -- We Are MPI!
		local PathName = string.format("Player_%d", Mission.m_PlayersSpawned + 1)
		local pathPoints = GetPathPoints(PathName)
		
		if pathPoints and (#pathPoints > 0) then
			-- Assuming pathPoints is a list of points with x,z or x,y,z
			spawnpointPosition = Vector(pathPoints[1].x, TerrainFindFloor(pathPoints[1].x, pathPoints[1].z), pathPoints[1].z)
		end
		
		Mission.m_PlayersSpawned = Mission.m_PlayersSpawned + 1

		-- If this is a null vector, use old method.
		if ((spawnpointPosition.x^2) + (spawnpointPosition.y^2) + (spawnpointPosition.z^2)) < 0.1 then
			spawnpointPosition = GetSpawnpointForTeam(Team, Mission.m_AllyTeams[Team], FRIENDLY_SPAWNPOINT_MAX_ALLY, FRIENDLY_SPAWNPOINT_MIN_ENEMY, RANDOM_SPAWNPOINT_MIN_ENEMY)
		end
	end

	-- Store position we created them at for later
	Mission.m_TeamPos[Team] = spawnpointPosition

	-- Build recycler some distance away, if it's not preplaced on the map.
	if not GetObjectByTeamSlot(Team, DLL_TEAM_SLOT_RECYCLER) then
		local VehicleH = nil
		if Mission.m_SpawnFacingCenter then
			-- Spawn Directly on Spawn, facing Center.
			local Center = GetCenterOfMap()
			local Front = GetFacingDrection2D(spawnpointPosition, Center)
			local Pos = Build_Directinal_Matrix(spawnpointPosition, Front)
			VehicleH = BuildObject(GetInitialRecyclerODF(TeamRaceH), Team, Pos)
		else
			local RecyPos = GetPositionNear(spawnpointPosition, VEHICLE_SPACING_DISTANCE, 2 * VEHICLE_SPACING_DISTANCE)
			VehicleH = BuildObject(GetInitialRecyclerODF(TeamRaceH), Team, RecyPos)
			SetRandomHeadingAngle(VehicleH)
		end

		Mission.m_RecyclerHandles[Team] = VehicleH
		SetGroup(VehicleH, 0)
	end

	-- Build all optional vehicles for this team.
	spawnpointPosition = Mission.m_TeamPos[Team]

	-- Look for an _ in there, and copy everything after it into the RecyVariant tag. -GBD
	local TempODF = GetInitialRecyclerODF(TeamRaceH)
	local TempODF2 = ""
	local VariantName = ""
	
	-- Logic to find variant name
	-- 1. Try checking GameObjectClass::startingVariant in ODF
	-- 2. Try checking parent class
	-- 3. Fallback tounderscore parsing
	
	local ODFFile = TempODF .. ".odf"
	-- In Lua we can't easily "OpenODF". We use GetODFString on the ODF name directly.
	-- Check ClassLabel
	local classLabel = GetODFString(ODFFile, "GameObjectClass", "classlabel")
	if classLabel and classLabel ~= "" then
		TempODF2 = classLabel .. ".odf"
	end
	
	VariantName = GetODFString(ODFFile, "GameObjectClass", "startingVariant")
	if VariantName == "" and TempODF2 ~= "" then
		VariantName = GetODFString(TempODF2, "GameObjectClass", "startingVariant")
	end
	
	if VariantName == "" then
		-- Fallback underscore parsing
		-- C++: strchr(Name, '_')
		local pUnderscore = string.find(TempODF, "_")
		if pUnderscore then
			local pUnderscore2 = string.find(TempODF, "_", pUnderscore + 1)
			if not pUnderscore2 then
				-- Only 1 underscore
				VariantName = string.sub(TempODF, pUnderscore + 1)
			else
				-- 2 underscores
				VariantName = string.sub(TempODF, pUnderscore2 + 1)
			end
		end
	end

	-- Drop skill level while we build things.
	Mission.m_CreatingStartingVehicles = true
	_StartingVehicles.CreateVehicles(Team, TeamRaceH, VariantName, Mission.m_StartingVehiclesMask, spawnpointPosition)
	Mission.m_CreatingStartingVehicles = false

	SetScrap(Team, 40)

	if IsTeamplayOn() then
		local first = GetFirstAlliedTeam(Team)
		local last = GetLastAlliedTeam(Team) -- C++ loop i <= last, Lua loop inclusive
		for i = first, last do
			-- Make thier Pilots match the VSR ones, if present. -GBD
			local pH = GetPlayerHandle(i)
			if pH then
				SetPilotClass(pH, GetInitialPlayerPilotODF(TeamRaceH, i, false))
			end

			if i ~= Team then
				if Mission.m_SpawnFacingCenter then
					-- Use directly on Spawns.
					Mission.m_TeamPos[i] = spawnpointPosition
				else -- Old Method.
					-- Get a new position near the team's central position
					local NewPosition = GetPositionNear(spawnpointPosition, AllyMinRadiusAway, AllyMaxRadiusAway)

					-- In teamplay, store where offense players were created for respawns later
					Mission.m_TeamPos[i] = NewPosition
				end
			end -- Loop over allies not the commander
		end
	else
		-- Setup based on allies position. -GBD
		for i = 1, MAX_TEAMS - 1 do
			if (i ~= Team) and (Mission.m_AllyTeams[Team] == Mission.m_AllyTeams[i]) and (Mission.m_ThugFlag[i]) and (not Mission.m_ThugFlag[Team]) then
				if Mission.m_SpawnFacingCenter then
					-- Use directly on Spawns.
					Mission.m_TeamPos[i] = spawnpointPosition
				else -- Old method.
					local NewPosition = GetPositionNear(spawnpointPosition, AllyMinRadiusAway, AllyMaxRadiusAway)
					Mission.m_TeamPos[i] = NewPosition
				end
			end
		end
	end

	if Team == GetLocalPlayerTeamNumber() then
		UpdateObjectives()
	end

	Mission.m_TeamIsSetUp[Team] = true
end



-- Given an index into the Player list, build everything for a given
-- single player (i.e. a vehicle of some sorts), and set up the team
-- as well as necessary
function SetupPlayer(Team)
	local PlayerH = nil
	local Where = Vector(0, 0, 0)

	if (Team < 1) or (Team >= MAX_TEAMS) then return 0 end -- Sanity check... do NOT proceed

	Mission.m_SpawnedAtTime[Team] = Mission.m_ElapsedGameTime -- Note when they spawned in.
	local TeamBlock = WhichTeamGroup(Team)
	
	local Center = Vector(0, 0, 0)
	if Mission.m_SpawnFacingCenter then
		Center = GetCenterOfMap()
	end

	-- Find out who the commander is for this team.
	-- If Teamplay is off, the commander is the player himself
	local Commander = Team
	if IsTeamplayOn() then
		Commander = GetCommanderTeam(Team)
	end

	-- Make sure the team is set up (force it if not already).
	if not Mission.m_TeamIsSetUp[Commander] then
		SetupTeam(Commander)
	end
	
	-- SetupTeam will fill in the m_TeamPos[] array of positions
	-- for both the commander and offense players, so read out the results
	Where = Mission.m_TeamPos[Team]
	-- Adjust Y for floor? C++ did TerrainFindFloor + 2.5f
	Where.y = TerrainFindFloor(Where.x, Where.z) + 2.5

	-- If not team play, do some fun stuff. -GBD
	if (not IsTeamplayOn()) or (TeamBlock < 0) then
		-- This person is a commander.
		if Mission.m_AllyTeams[Team] == 0 then
			Mission.ThugCounter[Team] = 0 -- Reset this.

			if not Mission.m_ThugFlag[Team] then
				if Mission.NumCommanders < Mission.m_NumSpawnPoints then
					-- Still base slot available
					if not Mission.m_TeamIsSetUp[Team] then
						Mission.m_CommanderTeam[Mission.m_AllyTeams[Team]] = Team
						Mission.NumCommanders = Mission.NumCommanders + 1
					end
					SetupTeam(Team)
					
					Where = Mission.m_TeamPos[Team]
					Where.y = TerrainFindFloor(Where.x, Where.z) + 2.5
				else
					-- Uh Oh, this map can't support any more commanding Teams.
					-- Remove previous alliances
					for t = 1, MAX_TEAMS - 1 do
						if t ~= Team then
							UnAlly(Team, t)
							UnAlly(t, Team)
						end
					end
					
					Mission.m_ThugFlag[Team] = true
					
					local HighestTeam = -1
					for s = 1, MAX_TEAMS - 1 do
						if Mission.m_CommanderTeam[s] > HighestTeam then
							HighestTeam = Mission.m_CommanderTeam[s]
						end
					end
					
					local NextAssignTeam = 0
					for n = Mission.NextAutoAssignTeam, MAX_TEAMS - 1 do
						if Mission.m_CommanderTeam[n] > 0 then
							NextAssignTeam = n
							Mission.NextAutoAssignTeam = n + 1
							if Mission.NextAutoAssignTeam > HighestTeam then
								Mission.NextAutoAssignTeam = 0
							end
							break
						end
					end
					
					Mission.m_AllyTeams[Team] = Mission.m_AllyTeams[NextAssignTeam]
					
					for x = 1, MAX_TEAMS - 1 do
						if (Mission.m_AllyTeams[x] > 0) and (x ~= Team) and (Mission.m_AllyTeams[x] == Mission.m_AllyTeams[Team]) then
							Ally(x, Team)
							Ally(Team, x)
							Mission.m_HasAllies[x] = true
							Mission.m_HasAllies[Team] = true
						end
					end
					
					-- Re-initialize starting position
					local allyCmdTeam = Mission.m_CommanderTeam[Mission.m_AllyTeams[Team]]
					Where = Mission.m_TeamPos[allyCmdTeam]
					Where.y = TerrainFindFloor(Where.x, Where.z) + 2.5
					
					local NewPosition = Vector(0,0,0)
					Mission.ThugCounter[allyCmdTeam] = (Mission.ThugCounter[allyCmdTeam] or 0) + 1
					
					if Mission.m_SpawnFacingCenter then
						local Front = GetFacingDrection2D(Where, Center)
						Front = HRotateFront(Front, (15.0 * Mission.ThugCounter[allyCmdTeam]) * DEG_2_RAD)
						NewPosition = Where + (Front * 50.0)
					else
						NewPosition = GetPositionNear(Where, AllyMinRadiusAway, AllyMaxRadiusAway)
					end
					
					Mission.m_TeamPos[Team] = NewPosition
					Where = NewPosition -- Update local Where for later use
				end
			end
		else
			-- Is a Thug
			local allyCmdTeam = Mission.m_CommanderTeam[Mission.m_AllyTeams[Team]]
			Mission.ThugCounter[allyCmdTeam] = (Mission.ThugCounter[allyCmdTeam] or 0) + 1
			
			Where = Mission.m_TeamPos[allyCmdTeam]
			Where.y = TerrainFindFloor(Where.x, Where.z) + 2.5
			
			if Mission.m_SpawnFacingCenter then
				local Front = GetFacingDrection2D(Where, Center)
				Front = HRotateFront(Front, (15.0 * Mission.ThugCounter[allyCmdTeam]) * DEG_2_RAD)
				Where = Where + (Front * 50.0)
			else
				-- Put near recycler (already set to allyCmdTeam pos above)
				Where.x = Mission.m_TeamPos[Team].x
				Where.z = Mission.m_TeamPos[Team].z
				Where.y = TerrainFindFloor(Where.x, Where.z) + 2.5
			end
		end
	else 
		-- TeamPlay
		-- SetupTeam(GetCommanderTeam(Team)) -- Already done above
		-- Pos set above
		
		if Mission.m_SpawnFacingCenter then
			local Front = GetFacingDrection2D(Where, Center)
			local ThugNumber = 0
			if Team < 6 then ThugNumber = Team - 1 else ThugNumber = Team - 7 end
			Front = HRotateFront(Front, (15.0 * ThugNumber) * DEG_2_RAD)
			Where = Where + (Front * 50.0)
		end
	end

	-- Custom code to Respawn the player...
	local PlayerODF = GetPlayerODF(Team)
	local DoOldRespawn = true
	local PlayerName = GetCVarItemStr(Team, 0) -- Reverting to C++ equivalent
	
	if Mission.m_RestorePlayers ~= 0 then
		if string.lower(string.sub(PlayerODF, 2, 10)) == "vcamr_vsr" then
			DoOldRespawn = true
		else
			local Index = 0
			if Mission.m_RestorePlayers == 1 then
				for x = 1, MAX_TEAMS - 1 do
					local nameMatch = (string.lower(PlayerName) == string.lower(Mission.PlayerSavedName[x]))
					local teamMatch = false
					if IsTeamplayOn() then
						teamMatch = (Mission.m_SavedPlayerTeamGroup[x] == (WhichTeamGroup(Team) + 1))
					else
						teamMatch = (Mission.m_SavedPlayerTeamGroup[x] == Team)
					end
					
					if nameMatch and teamMatch and DoesODFExist(Mission.PlayerShipODF[x]) then
						Index = x
						DoOldRespawn = false
						break
					end
				end
				
				if DoOldRespawn then
					for x = 1, MAX_TEAMS - 1 do
						if (Mission.PlayerSavedName[x] == nil) or (Mission.PlayerSavedName[x] == "") then
							Mission.PlayerSavedName[Team] = PlayerName
							break
						end
					end
				end
			elseif Mission.m_RestorePlayers == 2 then
				local teamMatch = false
				if IsTeamplayOn() then
					teamMatch = (Mission.m_SavedPlayerTeamGroup[Team] == (WhichTeamGroup(Team) + 1))
				else
					teamMatch = (Mission.m_SavedPlayerTeamGroup[Team] == Team)
				end
				
				if teamMatch and DoesODFExist(Mission.PlayerShipODF[Team]) then
					DoOldRespawn = false
					Index = Team
				else
					if IsTeamplayOn() then
						Mission.m_SavedPlayerTeamGroup[Team] = WhichTeamGroup(Team) + 1
					else
						Mission.m_SavedPlayerTeamGroup[Team] = Team
					end
				end
			end
			
			if Index ~= 0 then
				PlayerH = BuildObject(Mission.PlayerShipODF[Index], Team, Mission.PlayerMatrix[Index])
				SetPilotClass(PlayerH, Mission.SavedPilotODF[Index])
				
				-- ReplaceWeapons is bound now.
				ReplaceWeapons(PlayerH, Mission.PlayerShipWeapons[Index], Mission.m_SavedPlayerLocalAmmo[Index])
				
				SetCurHealth(PlayerH, Mission.m_SavedPlayerHealth[Index])
				SetCurAmmo(PlayerH, Mission.m_SavedPlayerAmmo[Index])
				SetPosition(PlayerH, Mission.PlayerMatrix[Index])
				SetVelocity(PlayerH, Mission.PlayerVelocity[Index])
				SetOmega(PlayerH, Mission.PlayerOmega[Index])
				
				local ObjClass = GetClassLabel(PlayerH) or ""
				if (string.lower(ObjClass) == "class_scavenger") or (string.lower(ObjClass) == "class_scavengerh") then
					SetScavengerCurScrap(PlayerH, Mission.m_SavedPlayerScrap[Index])
				end
				
				if Mission.m_SavedPlayerDeployed[Index] then
					Deploy(PlayerH)
				end
				
				if IsTeamplayOn() then
					Mission.m_SavedPlayerTeamGroup[Index] = WhichTeamGroup(Team) + 1
				else
					Mission.m_SavedPlayerTeamGroup[Index] = Team
				end
				
				Mission.m_GiveWeaponsBack[Index] = true
			end
		end
	end
	
	if (Mission.m_RestorePlayers == 0) or DoOldRespawn then
		if string.lower(PlayerName) == "krohonus_legs" then
			PlayerH = BuildObject("evlegs_vsr", Team, Where)
		else
			PlayerH = BuildObject(PlayerODF, Team, Where)
		end
		
		if string.lower(string.sub(PlayerODF, 2, 10)) == "vcamr_vsr" then
			SetPerceivedTeam(PlayerH, 0)
			-- m_CameraPodDeployTimer
		end
		
		SetPilotClass(PlayerH, GetInitialPlayerPilotODF(GetRaceOfTeam(Team), Team, false))
		
		if Mission.m_SpawnFacingCenter then
			local Front = GetFacingDrection2D(Where, Center)
			local Pos = Build_Directinal_Matrix(Where, Front)
			SetPosition(PlayerH, Pos)
		else
			SetRandomHeadingAngle(PlayerH)
		end
	end

	-- If on team 0 (dedicated server team), make this object gone from the world
	if Team == 0 then
		MakeInert(PlayerH)
	end

	return PlayerH
end



-- Internal one-time setup
function Start()
	local PlayerH = nil
	
	-- Ensure variables pre-init'd to zero at the start
	-- (Lua Init handles this via Mission table default values)

	-- StartingVehicle file. Set if specified.
	local Contents = GetVarItemStr("network.session.svar6")
	if (Contents ~= nil) and (Contents ~= "") then
		_StartingVehicles.Start() -- Contents handled internally?
	end

	local CaptureTarget = {} -- array of strings
	local NumCaptureTargetODFs = 0
	local CaptureRandom = false

	-- Read from the map's .trn file
	local pMapName = GetVarItemStr("network.session.svar0")
	if pMapName and pMapName ~= "" then
		local mapTrnFile = pMapName
		-- Strip extension and add .trn
		local dotPos = string.find(string.reverse(mapTrnFile), "%.")
		if dotPos then
			mapTrnFile = string.sub(mapTrnFile, 1, #mapTrnFile - dotPos) .. ".trn"
		else
			mapTrnFile = mapTrnFile .. ".trn"
		end
		
		-- In Lua we check file existence or just Try ODF calls
		if DoesFileExist(mapTrnFile) then
			Mission.m_RespawnAtLowAltitude = GetODFBool(mapTrnFile, "DLL", "RespawnAtLowAltitude", false)
			Mission.m_FRIENDLY_SPAWNPOINT_MAX_ALLY = GetODFFloat(mapTrnFile, "DLL", "FriendlySpawnpointMaxAllyRange", Mission.m_FRIENDLY_SPAWNPOINT_MAX_ALLY)
			Mission.m_FRIENDLY_SPAWNPOINT_MIN_ENEMY = GetODFFloat(mapTrnFile, "DLL", "FriendlySpawnpointMinEnemyRange", Mission.m_FRIENDLY_SPAWNPOINT_MIN_ENEMY)
			Mission.m_RANDOM_SPAWNPOINT_MIN_ENEMY = GetODFFloat(mapTrnFile, "DLL", "RandomSpawnpointMinEnemyRange", Mission.m_RANDOM_SPAWNPOINT_MIN_ENEMY)

			for x = 1, 16 do
				local DesiredValue = "CaptureTarget" .. x
				local target = GetODFString(mapTrnFile, "DLL", DesiredValue)
				if target and target ~= "" then
					CaptureTarget[x] = target
					NumCaptureTargetODFs = NumCaptureTargetODFs + 1
				else
					break
				end
			end
			CaptureRandom = GetODFBool(mapTrnFile, "DLL", "CaptureIsRandom", false)

			local MapAmbientSound = GetODFString(mapTrnFile, "VSR", "MapAmbientSound")
			if MapAmbientSound and DoesFileExist(MapAmbientSound) then
				Mission.EasterEggSound = StartAudio2D(MapAmbientSound, -1, 0.0, 44100.0, true, false)
			end
		end
	end

	-- Set up some variables based on how things appear in the world
	Mission.m_DidInit = true
	Mission.m_KillLimit = GetVarItemInt("network.session.ivar0")
	Mission.m_TotalGameTime = GetVarItemInt("network.session.ivar1")
	-- Skip ivar2-- player limit.
	
	Mission.m_StartingVehiclesMask = GetVarItemInt("network.session.ivar7")

	-- Tell if this is an MPI based on ivar12. -GBD
	Mission.m_IsMPI = (GetVarItemInt("network.session.ivar12") ~= 0)
	if Mission.m_IsMPI then
		-- Get AI Team Races
		-- Assuming Mission.m_AIRace table size 5. C++ code uses 0-4.
		-- Lua tables are 1-based, but we can use 0-based keys if we want.
		-- I'll use 1-based keys for Lua consistency.
		Mission.m_AIRace[1] = GetVarItemInt("network.session.ivar13")
		Mission.m_AIRace[2] = GetVarItemInt("network.session.ivar96")
		Mission.m_AIRace[3] = GetVarItemInt("network.session.ivar97")
		Mission.m_AIRace[4] = GetVarItemInt("network.session.ivar98")
		Mission.m_AIRace[5] = GetVarItemInt("network.session.ivar99")

		Mission.m_CPUTurretAISkill = clamp(GetVarItemInt("network.session.ivar21"), 0, 3)
		Mission.m_CPUNonTurretAISkill = clamp(GetVarItemInt("network.session.ivar22"), 0, 3)
		Mission.m_HumanForce = clamp(GetVarItemInt("network.session.ivar23"), 0, 3)
		Mission.m_CPUForce = clamp(GetVarItemInt("network.session.ivar24"), 0, 3)
	end
	
	Mission.m_GameType = GetVarItemInt("network.session.ivar53")

	Mission.m_CaptureTime = clamp(GetVarItemInt("network.session.ivar54"), 30, 120) * Mission.m_GameTPS

	Mission.m_PointsForAIKill = (GetVarItemInt("network.session.ivar14") ~= 0)
	Mission.m_KillForAIKill = (GetVarItemInt("network.session.ivar15") ~= 0)
	Mission.m_RespawnWithSniper = GetVarItemInt("network.session.ivar16")

	Mission.m_bIsFriendlyFireOn = (GetVarItemInt("network.session.ivar32") ~= 0)

	Mission.m_SetThugPilotFlag = (GetVarItemInt("network.session.ivar55") ~= 0)

	Mission.m_SpawnFacingCenter = (GetVarItemInt("network.session.ivar118") ~= 0)

	Mission.m_RestorePlayers = clamp(GetVarItemInt("network.session.ivar119"), 0, 2)

	Mission.m_PilotInvunerability = clamp(GetVarItemInt("network.session.ivar120"), 0, 120) * Mission.m_GameTPS

	Mission.m_MorphTankAutoDeployType = clamp(GetVarItemInt("network.session.ivar121"), 0, 3)

	Mission.m_TurretAISkill = clamp(GetVarItemInt("network.session.ivar17"), 0, 3)
	Mission.m_NonTurretAISkill = clamp(GetVarItemInt("network.session.ivar18"), 0, 3)

	-- Ally code.
	-- Initialize m_AllyTeams to 0
	for i = 1, MAX_TEAMS do Mission.m_AllyTeams[i] = 0 end
	
	if (not IsTeamplayOn()) or Mission.m_IsMPI then
		-- Grab "Team" numbers
		for i = 1, MAX_TEAMS - 1 do
			local varVal = GetVarItemInt("network.session.ivar" .. (34 + i))
			Mission.m_AllyTeams[i] = varVal
			
			if Mission.m_AllyTeams[i] <= 0 then
				Mission.m_AllyTeams[i] = i
			end
			
			local thugVal = GetVarItemInt("network.session.ivar" .. (80 + i))
			Mission.m_ThugFlag[i] = (clamp(thugVal, 0, 1) ~= 0)
		end


		if IsTeamplayOn() then
			-- Default Allies Logic
			
			local R = {}
			local G = {}
			local B = {}

			-- Get Team Colors from Game Prefs
			for x = 1, 5 do
				R[x], G[x], B[x] = GetTeamStratIndividualColor(TEAMCOLOR_TYPE_GAMEPREFS, x)
			end

			DefaultAllies()

			SetFFATeamColors(TEAMCOLOR_TYPE_GAMEPREFS)

			-- Re-ally Team 1-5
			for x = 1, 5 do
				SetTeamColor(x, R[x], G[x], B[x])
				for y = 1, 5 do
					if x ~= y then
						Ally(x, y)
						if x == 1 then
							Mission.m_AllyTeams[y] = Mission.m_AllyTeams[x]
						end
					end
				end
			end
		end
		
		-- Loop over all teams and ally
		for x = 1, MAX_TEAMS - 1 do
			for y = 1, MAX_TEAMS - 1 do
				if (Mission.m_AllyTeams[x] > 0) and (x ~= y) and (Mission.m_AllyTeams[x] == Mission.m_AllyTeams[y]) then
					Ally(x, y)
					Mission.m_HasAllies[x] = true
					
					if IsTeamplayOn() and (x == 1) then
						local first = GetFirstAlliedTeam(x)
						local last = GetLastAlliedTeam(x)
						for j = first, last do
							Ally(j, y)
						end
					end
				end
			end
		end
		
		-- Setup Commander
		for i = 1, MAX_TEAMS - 1 do
			if (not Mission.m_TeamHasCommander[Mission.m_AllyTeams[i]]) then
				-- Find commander
				for x = 1, MAX_TEAMS - 1 do
					if (not Mission.m_ThugFlag[x]) and (Mission.m_AllyTeams[i] == Mission.m_AllyTeams[x]) then
						Mission.m_TeamHasCommander[Mission.m_AllyTeams[i]] = true
						break
					end
				end
				
				if not Mission.m_TeamHasCommander[Mission.m_AllyTeams[i]] then
					-- Pick first player
					for p = 1, MAX_TEAMS - 1 do
						if Mission.m_AllyTeams[p] == Mission.m_AllyTeams[i] then
							Mission.m_ThugFlag[p] = false
							Mission.m_TeamHasCommander[Mission.m_AllyTeams[i]] = true
							break
						end
					end
				end
			end
		end
	end

	Mission.m_RecyInvulnerabilityTime = GetVarItemInt("network.session.ivar25") * 60 * Mission.m_GameTPS

	local PlayerEntryH = GetPlayerHandle()
	if PlayerEntryH then
		RemoveObject(PlayerEntryH)
	end
	
	if ImServer() or (not IsNetworkOn()) then
		Mission.m_ElapsedGameTime = 0
		if Mission.m_RemainingGameTime <= 0 then
			Mission.m_RemainingGameTime = Mission.m_TotalGameTime * 60 * Mission.m_GameTPS
		end
		
		if Mission.m_IsMPI then
			Mission.m_LastTauntPrintedAt = -2000
			-- InitTaunts(&m_ElapsedGameTime...) 
		end
	end
	
	local LocalTeamNum = GetLocalPlayerTeamNumber()
	PlayerH = SetupPlayer(LocalTeamNum)
	SetAsUser(PlayerH, LocalTeamNum)
	AddPilotByHandle(PlayerH)
	
	-- ST: Capture mode
	if Mission.m_GameType == 4 then
		local pathNames = GetAiPaths() or {} 
		local pathCount = #pathNames
		
		local RandomVal = 0.0
		
		for i = 1, pathCount do
			local label = pathNames[i]
			
			if NumCaptureTargetODFs > 0 then
				local s, e, captureNum = string.find(label, "capturegoal(%d+)")
				if captureNum and (Mission.m_NumCaptureGoals < MAX_TEAMS) then
					if CaptureRandom then
						RandomVal = math.floor(GetRandomFloat(NumCaptureTargetODFs))
						if RandomVal >= NumCaptureTargetODFs then RandomVal = NumCaptureTargetODFs - 1 end
					else
						if RandomVal >= NumCaptureTargetODFs then RandomVal = 0 end
					end
					
					local targetODF = CaptureTarget[RandomVal + 1]
					
					if DoesODFExist(targetODF) then
						local h = BuildObject(targetODF, 0, label)
						Mission.m_CaptureGoals[Mission.m_NumCaptureGoals + 1] = h
						
						if IsAround(h) then
							SetObjectiveOn(h)
							Mission.m_NumCaptureGoals = Mission.m_NumCaptureGoals + 1
						end
						
						if not CaptureRandom then
							RandomVal = RandomVal + 1
						end
					else
						PrintConsoleMessage("Error: ODF '" .. targetODF .. "' doesn't exist!")
					end
				end
			else
				PrintConsoleMessage("Error: Map has no Capture ODF's set!")
			end
		end
	end
end



-- Called from Execute, m_GameTPS of a second has elapsed. Update everything.
function UpdateGameTime()
	Mission.m_ElapsedGameTime = Mission.m_ElapsedGameTime + 1

	-- Are we in a time limited game?
	if Mission.m_RemainingGameTime > 0 then
		Mission.m_RemainingGameTime = Mission.m_RemainingGameTime - 1
		if (Mission.m_RemainingGameTime % Mission.m_GameTPS) == 0 then
			-- Convert tenth-of-second ticks to hour/minutes/seconds format.
			local totalSeconds = math.floor(Mission.m_RemainingGameTime / Mission.m_GameTPS)
			local Seconds = totalSeconds % 60
			local Minutes = math.floor(totalSeconds / 60)
			local Hours = math.floor(Minutes / 60)
			Minutes = Minutes % 60

			local TempMsgString = ""
			if Hours > 0 then
				local fmt = TranslateString("mission", "Time Left %d:%02d:%02d\n") or "Time Left %d:%02d:%02d\n"
				TempMsgString = string.format(fmt, Hours, Minutes, Seconds)
			else
				local fmt = TranslateString("mission", "Time Left %d:%02d\n") or "Time Left %d:%02d\n"
				TempMsgString = string.format(fmt, Minutes, Seconds)
			end
			
			SetTimerBox(TempMsgString)

			-- Also print this out more visibly at important times....
			if Hours == 0 then
				-- Every 5 minutes down to 10 minutes, then every minute
				-- thereafter.
				if (Seconds == 0) and ((Minutes <= 10) or ((Minutes % 5) == 0)) then
					AddToMessagesBox(TempMsgString)
				else
					-- Every 5 seconds when under a minute is remaining.
					if (Minutes == 0) and ((Seconds % 5) == 0) then
						AddToMessagesBox(TempMsgString)
					end
				end
			end
		end

		-- Game over due to timeout?
		if Mission.m_RemainingGameTime == 0 then
			NoteGameoverByTimelimit()
			DoGameover(endDelta)
		end

	else
		-- Infinite time game. Periodically update ingame clock.
		if (Mission.m_ElapsedGameTime % Mission.m_GameTPS) == 0 then

			local totalSeconds = math.floor(Mission.m_ElapsedGameTime / Mission.m_GameTPS)
			local Seconds = totalSeconds % 60
			local Minutes = math.floor(totalSeconds / 60)
			local Hours = math.floor(Minutes / 60)
			Minutes = Minutes % 60

			local TempMsgString = ""
			if Hours > 0 then
				local fmt = TranslateString("mission", "Mission Time %d:%02d:%02d") or "Mission Time %d:%02d:%02d"
				TempMsgString = string.format(fmt, Hours, Minutes, Seconds)
			else
				local fmt = TranslateString("mission", "Mission Time %d:%02d") or "Mission Time %d:%02d"
				TempMsgString = string.format(fmt, Minutes, Seconds)
			end
			SetTimerBox(TempMsgString)
		end
	end
end

-- If Recycler invulnerability is on, then does the job of it.
function ExecuteRecyInvulnerability()
	-- No need to do anything more...
	if Mission.m_GameOver or (Mission.m_RecyInvulnerabilityTime == 0) then
		return
	end

	for i = 1, MAX_TEAMS - 1 do
		if Mission.m_TeamIsSetUp[i] then
			-- Check if recycler vehicle still exists.
			local TempH = Mission.m_RecyclerHandles[i]
			local recyHandle = 0
			
			if (not TempH) or (not IsAlive(TempH)) then
				recyHandle = GetObjectByTeamSlot(i, DLL_TEAM_SLOT_RECYCLER)
			else
				recyHandle = Mission.m_RecyclerHandles[i]
			end
			
			-- IsRecycler helper needs to be accessible. _DLLUtils.IsRecycler?
			-- C++ calls DLLUtils::IsRecycler. Assuming I can access it or reimplement.
			-- I implemented a local `IsRecyclerODF` earlier but that takes handle and returns char?
			-- Ah, `_DLLUtils.IsRecycler` takes handle.
			-- But wait, `IsRecycler` in _DLLUtils check class label.
			if (recyHandle) and IsRecycler(recyHandle) then
				SetCurHealth(recyHandle, GetMaxHealth(recyHandle))
			end
		end
	end

	-- Print periodic message about recycler invulnerability time left
	if (Mission.m_RecyInvulnerabilityTime == 1) or
		((Mission.m_RecyInvulnerabilityTime % (60 * Mission.m_GameTPS)) == 0) or
		((Mission.m_RecyInvulnerabilityTime < (60 * Mission.m_GameTPS)) and ((Mission.m_RecyInvulnerabilityTime % (15 * Mission.m_GameTPS)) == 0)) then

		local TempMsgString = ""
		if Mission.m_RecyInvulnerabilityTime == 1 then
			TempMsgString = TranslateString("strat", "recyclersVulnerable") or "Recycler Invulnerability has expired!"
		elseif Mission.m_RecyInvulnerabilityTime > (60 * Mission.m_GameTPS) then
			local fmt = TranslateString("strat", "invulnerableExpiresMin") or "Recycler Invulnerability expires in %d minutes."
			TempMsgString = string.format(fmt, math.floor(Mission.m_RecyInvulnerabilityTime / (60 * Mission.m_GameTPS)))
		else
			local fmt = TranslateString("strat", "invulnerableExpiresSec") or "Recycler Invulnerability expires in %d seconds."
			TempMsgString = string.format(fmt, math.floor(Mission.m_RecyInvulnerabilityTime / Mission.m_GameTPS))
		end

		AddToMessagesBox(TempMsgString, Make_RGB(255, 0, 255))
	end

	-- Reduce timer
	Mission.m_RecyInvulnerabilityTime = Mission.m_RecyInvulnerabilityTime - 1
end



function ExecuteCheckIfGameOver()
	-- No need to do anything more...
	if Mission.m_GameOver or (Mission.m_ElapsedGameTime < Mission.m_GameTPS) then
		return
	end

	-- Check for a gameover by no recycler & factory
	local NumFunctioningTeams = 0
	local TeamIsFunctioning = {} -- [MAX_TEAMS] bool
	local AlliesFunctioning = {} -- [MAX_TEAMS] bool
	local HumansAlive = false -- Assume so for MPI. (Actually logic below sets it true)
	local TeamPlayOn = IsTeamplayOn()

	-- Init tables
	for i = 1, MAX_TEAMS do TeamIsFunctioning[i] = false; AlliesFunctioning[i] = false end

	for i = 1, MAX_TEAMS - 1 do
		if Mission.m_TeamIsSetUp[i] then
			local Functioning = false -- Assume so for now.

			-- Check if recycler vehicle still exists.
			local TempH = Mission.m_RecyclerHandles[i]

			-- Added to allow recycler upgrading?
			if not IsAround(TempH) then
				TempH = GetObjectByTeamSlot(i, DLL_TEAM_SLOT_RECYCLER)
			end

			if (not TempH) or (not IsAlive(TempH)) then
				Mission.m_RecyclerHandles[i] = nil -- Clear this out for later
			else
				Functioning = true
			end

			local RecyH = nil
			-- Check vehicle if it is around, else, check the building
			if IsAlive(TempH) or (TempH) then
				RecyH = TempH
			else
				RecyH = GetObjectByTeamSlot(i, DLL_TEAM_SLOT_RECYCLER)
			end

			-- Check RecyH is around (note that buildings are not "alive"
			if not RecyH then -- Uh oh, no Recycler? Look for Factory. -GBD
				RecyH = GetObjectByTeamSlot(i, DLL_TEAM_SLOT_FACTORY)
			end

			if RecyH then
				if Mission.m_IsMPI and (i < 11) then -- Teams 1-10 are humans?
					HumansAlive = true
				end
				Functioning = true
			end

			local alliedTeam = Mission.m_AllyTeams[i]
			if alliedTeam and alliedTeam > 0 then
				AlliesFunctioning[alliedTeam] = AlliesFunctioning[alliedTeam] or Functioning
			end
			TeamIsFunctioning[i] = Functioning

			-- Moved Respawn check here to look for allies too. -GBD
			-- Note deployed location first time it deploys, also every 25.6 seconds
			if (not Mission.m_NotedRecyclerLocation[i]) or ((Mission.m_ElapsedGameTime % 256) == 0) then -- 0xFF check approximated
				if not TeamPlayOn then -- FFA only.
					-- First pass, look for Commander's Recycler/Factory.
					local cmdTeam = Mission.m_CommanderTeam[Mission.m_AllyTeams[i]]
				if (not RecyH) and cmdTeam and cmdTeam > 0 then
						RecyH = GetObjectByTeamSlot(cmdTeam, DLL_TEAM_SLOT_RECYCLER)
					end
					if (not RecyH) and cmdTeam and cmdTeam > 0 then
						RecyH = GetObjectByTeamSlot(cmdTeam, DLL_TEAM_SLOT_FACTORY)
					end
				end

				-- Grab out allie's Recy for respawn placement if ours is dead.
				if not RecyH then -- Uh oh, your recy+factory are dead. Look for ones on allied teams.
					for x = 1, MAX_TEAMS - 1 do -- Loop through all teams.
						if (i ~= x) and IsTeamAllied(i, x) then
							RecyH = GetObjectByTeamSlot(x, DLL_TEAM_SLOT_RECYCLER)
							if not RecyH then
								RecyH = GetObjectByTeamSlot(x, DLL_TEAM_SLOT_FACTORY)
							end

							if RecyH then
								break -- Found one
							end
						end
					end
				end

				if RecyH then
					Mission.m_NotedRecyclerLocation[i] = true
					local RecyPos = GetPosition(RecyH)
					Mission.m_TeamPos[i] = RecyPos
					
					-- Apply this to thugs also.
					if TeamPlayOn then
						local first = GetFirstAlliedTeam(i)
						local last = GetLastAlliedTeam(i)
						for jj = first, last do
							Mission.m_TeamPos[jj] = RecyPos
						end
					end
				end
			end
		end -- m_TeamIsSetUp[i]
	end -- loop over functioning teams

	for i = 1, MAX_TEAMS - 1 do
		if (not Mission.m_IsMPI) and TeamPlayOn then
			if TeamIsFunctioning[i] then
				NumFunctioningTeams = NumFunctioningTeams + 1
			end
		else
			if AlliesFunctioning[i] then
				NumFunctioningTeams = NumFunctioningTeams + 1
			end
		end
	end

	-- MPI, Special abort early if all humans are dead.
	if Mission.m_IsMPI and (not HumansAlive) then
		NoteGameoverWithCustomMessage(TranslateString("mission", "All Human bases destroyed!") or "All Human bases destroyed!")
		DoGameover(endDelta)
		Mission.m_GameOver = true
	end

	-- Keep track if we ever had several teams playing.
	if NumFunctioningTeams > 1 then
		Mission.m_HadMultipleFunctioningTeams = true
		return -- Exit function early
	end

	-- Easy Gameover case: nobody's got a functioning base. End everything now.
	if (NumFunctioningTeams == 0) and (Mission.m_ElapsedGameTime > (5 * Mission.m_GameTPS)) then
		NoteGameoverByNoBases()
		DoGameover(endDelta)
		Mission.m_GameOver = true
	else
		-- Check winner
		if Mission.m_HadMultipleFunctioningTeams and (NumFunctioningTeams == 1) then
			-- Ok, at one point we had >1 teams playing, now we've got 1. They're the winner.

			if TeamPlayOn then
				local AIWon = {} -- [MAX_TEAMS] bool
				local WinningTeamgroup = -1
				
				for i = 1, MAX_TEAMS - 1 do
					if TeamIsFunctioning[i] then
						if Mission.m_IsMPI then
							if i < 11 then
								DoTaunt(TAUNTS_CPURecyDestroyed)
							else
								DoTaunt(TAUNTS_HumanRecyDestroyed)
							end
						end
						
						if WinningTeamgroup == -1 then
							if Mission.m_IsMPI and (i > 10) then
								local allyT = Mission.m_AllyTeams[i]
								if Mission.m_HasAllies[i] then
									if not AIWon[allyT] then
										AIWon[allyT] = true
										local msg = string.format(TranslateString("mission", "Computer Team %d has won, destroyed all enemy bases.") or "Computer Team %d has won, destroyed all enemy bases.", allyT)
										NoteGameoverWithCustomMessage(msg)
									end
								else
									local msg = string.format(TranslateString("mission", "Computer Team %d has won, destroyed all enemy bases.") or "Computer Team %d has won, destroyed all enemy bases.", i)
									NoteGameoverWithCustomMessage(msg)
								end
							else
								WinningTeamgroup = WhichTeamGroup(i)
								NoteGameoverByLastTeamWithBase(WinningTeamgroup)
							end
						end
					end
				end

				-- Also, give all players on winning team points...
				for i = 1, MAX_TEAMS - 1 do
					if WhichTeamGroup(i) == WinningTeamgroup then
						local h = GetPlayerHandle(i)
						if h then AddScore(h, ScoreForWinning) end
					end
				end
				DoGameover(endDelta)
				Mission.m_GameOver = true
			else 
				-- Non-teamplay, report individual winner
				local AIWon = {}
				
				for i = 1, MAX_TEAMS - 1 do
					if Mission.m_IsMPI then
						if i < 11 then
							DoTaunt(TAUNTS_CPURecyDestroyed)
						else
							DoTaunt(TAUNTS_HumanRecyDestroyed)
						end
					end

					if AlliesFunctioning[Mission.m_AllyTeams[i]] then
						if Mission.m_IsMPI and (i > 10) then
							if Mission.m_HasAllies[i] then
								if not AIWon[Mission.m_AllyTeams[i]] then
									AIWon[Mission.m_AllyTeams[i]] = true
									local msg = string.format(TranslateString("mission", "Computer Team %d has won, destroyed all enemy bases.") or "Computer Team %d has won, destroyed all enemy bases.", Mission.m_AllyTeams[i])
									NoteGameoverWithCustomMessage(msg)
								end
							else
								local msg = string.format(TranslateString("mission", "Computer Team %d has won, destroyed all enemy bases.") or "Computer Team %d has won, destroyed all enemy bases.", i)
								NoteGameoverWithCustomMessage(msg)
							end
						elseif Mission.m_HasAllies[i] then
							-- GetBZCCLocalizedString missing. Use generic.
							local TeamName = string.format("%s %d", TranslateString("cfg", "Team") or "Team", Mission.m_AllyTeams[i])
							-- "HitLastWithBaseStr" usually "%s wins!"
							local msg = string.format(TranslateString("mission", "%s wins!") or "%s wins!", TeamName)
							NoteGameoverWithCustomMessage(msg) -- Fallback

							for j = 1, MAX_TEAMS - 1 do
								if (i ~= j) and IsTeamAllied(i, j) then
									local h = GetPlayerHandle(j)
									if h then AddScore(h, ScoreForWinning) end
								end
							end
						else
							local h = GetPlayerHandle(i)
							if h then NoteGameoverByLastWithBase(h) end
						end
						local h = GetPlayerHandle(i)
						if h then AddScore(h, ScoreForWinning) end
					end
				end
				DoGameover(endDelta)
				Mission.m_GameOver = true
			end 
		end
	end
end



function Update()



	-- If Recycler invulnerability is on, then does the job of it.
	ExecuteRecyInvulnerability()

	-- Check for absence of recycler & factory, gameover if so.
	ExecuteCheckIfGameOver()

	-- Do this as well...
	UpdateGameTime()

	-- watch for winner.
	if Mission.m_GameType == 4 then
		ExecuteST_Capture()
	end

	local TeamPlayOn = IsTeamplayOn()

	-- VSR Specific stuff. -GBD
	for Team = 1, MAX_TEAMS - 1 do

		-- Buggery Stuffs skipped (C++ commented out)
		
		local TempPlayerH = GetPlayerHandle(Team)
		
		if IsAround(TempPlayerH) then
			-- Pilot Invulnerability
			if (Mission.m_PilotInvTime[Team] > 0) and (Mission.m_PilotInvUser[Team] == TempPlayerH) then
				Mission.m_PilotInvTime[Team] = Mission.m_PilotInvTime[Team] - 1
				
				if GetCurAmmo(Mission.m_PilotInvUser[Team]) < GetMaxAmmo(Mission.m_PilotInvUser[Team]) then
					Mission.m_PilotInvTime[Team] = 0
				end
				
				if (Mission.m_PilotInvTime[Team] <= 0) and IsAround(Mission.m_PilotInvUser[Team]) then
					SetMaxHealth(Mission.m_PilotInvUser[Team], Mission.m_SavedPilotInvHealth[Team])
				end
			end
			
			-- Camera Pod Alliance Stuff
			local PlayerODF = GetOdf(TempPlayerH)
			if PlayerODF then
				-- Normalize ODF name (remove :...)
				local colonPos = string.find(PlayerODF, ":")
				if colonPos then
					PlayerODF = string.sub(PlayerODF, 1, colonPos - 1)
				end
				
				-- Check for "vcamr_vsr"
				if string.find(string.lower(PlayerODF), "vcamr_vsr") then
					SetPerceivedTeam(TempPlayerH, 0)
					
					if not Mission.IsCameraPod[Team] then
						for t = 1, MAX_TEAMS - 1 do
							if t ~= Team then
								UnAlly(t, Team)
							end
						end
						Mission.IsCameraPod[Team] = true
					end
				else
					if Mission.IsCameraPod[Team] then
						if TeamPlayOn then
							local first = GetFirstAlliedTeam(Team)
							local last = GetLastAlliedTeam(Team)
							for x = first, last do
								Ally(x, Team)
							end
						else
							for x = 1, MAX_TEAMS - 1 do
								if (Mission.m_AllyTeams[x] > 0) and (x ~= Team) and (Mission.m_AllyTeams[x] == Mission.m_AllyTeams[Team]) then
									Ally(x, Team)
								end
							end
						end
						Mission.IsCameraPod[Team] = false
					end
				end
				
				-- Restore Players code
				if (Mission.m_RestorePlayers > 0) and (not string.find(string.lower(PlayerODF), "vcamr_vsr")) and (not string.find(string.lower(PlayerODF), "vsatview_vsr")) then
					local PlayerName = GetCVarItemStr(Team, 0)
					local ObjClass = GetClassLabel(TempPlayerH)
					local PilotODF = GetPilotClass(TempPlayerH)
					if PilotODF then
						local dot = string.find(string.reverse(PilotODF), "%.")
						if dot then PilotODF = string.sub(PilotODF, 1, #PilotODF - dot) end
					end
					
					local Index = 0
					if Mission.m_RestorePlayers == 1 then
						for x = 1, MAX_TEAMS - 1 do
							if (PlayerName == Mission.PlayerSavedName[x]) then
								Index = x
								break
							end
						end
					elseif Mission.m_RestorePlayers == 2 then
						if (TeamPlayOn and (Mission.m_SavedPlayerTeamGroup[Team] == (WhichTeamGroup(Team) + 1))) or 
						   ((not TeamPlayOn) and (Mission.m_SavedPlayerTeamGroup[Team] == Team)) then
							Index = Team
						end
					end
					
					if Index ~= 0 then
						Mission.PlayerShipODF[Index] = PlayerODF
						Mission.SavedPilotODF[Index] = PilotODF
						Mission.PlayerSavedName[Index] = PlayerName
						
						for i = 1, MAX_HARDPOINTS do
							local w = GetWeaponClass(TempPlayerH, i - 1)
							Mission.PlayerShipWeapons[Index][i] = w or ""
							Mission.m_SavedPlayerLocalAmmo[Index][i] = GetCurLocalAmmo(TempPlayerH, i - 1)
						end
						
						Mission.m_SavedPlayerHealth[Index] = GetCurHealth(TempPlayerH)
						Mission.m_SavedPlayerAmmo[Index] = GetCurAmmo(TempPlayerH)
						Mission.PlayerMatrix[Index] = GetTransform(TempPlayerH)
						Mission.PlayerVelocity[Index] = GetVelocity(TempPlayerH)
						Mission.PlayerOmega[Index] = GetOmega(TempPlayerH)
						
						if (ObjClass == "CLASS_SCAVENGER") or (ObjClass == "CLASS_SCAVENGERH") then
							Mission.m_SavedPlayerScrap[Index] = GetScavengerCurScrap(TempPlayerH)
						end
						
						Mission.m_SavedPlayerDeployed[Index] = IsDeployed(TempPlayerH)
						
						if TeamPlayOn then
							Mission.m_SavedPlayerTeamGroup[Index] = WhichTeamGroup(Team) + 1
						else
							Mission.m_SavedPlayerTeamGroup[Index] = Team
						end
						
						if ObjClass == "CLASS_PERSON" then
							if not Mission.m_GiveWeaponsBack[Index] then
								for i = 1, MAX_HARDPOINTS do
									local w = GetWeaponClass(TempPlayerH, i - 1)
									Mission.PlayerPilotWeapons[Index][i] = w or ""
									Mission.PlayerPilotLocalAmmo[Index][i] = GetCurLocalAmmo(TempPlayerH, i - 1)
								end
							else
								ReplaceWeapons(TempPlayerH, Mission.PlayerPilotWeapons[Index], Mission.PlayerPilotLocalAmmo[Index])
								Mission.m_GiveWeaponsBack[Index] = false
							end
						end
					end
				end
			end
		end -- IsAround
	end -- Team Loop



	-- Empty Ship Invulnerability (Re-inserted)
	if Mission.m_PilotInvunerability > 0 then
		local i = 1
		while i <= #Mission.EmptyShipList do
			local entry = Mission.EmptyShipList[i]
			if (not IsAround(entry.EmptyShipObject)) or (GetTeamNum(entry.EmptyShipObject) ~= 0) then
				table.remove(Mission.EmptyShipList, i)
			else
				i = i + 1
			end
		end
		
		for _, iter in ipairs(Mission.EmptyShipList) do
			if iter.InvulnerabilityTime > 0 then
				iter.InvulnerabilityTime = iter.InvulnerabilityTime - 1
			end
			
			if (iter.InvulnerabilityTime <= 0) or IsAliveAndPilot(iter.EmptyShipObject) or IsPlayer(iter.EmptyShipObject) then
				if GetMaxHealth(iter.EmptyShipObject) == 0 then
					SetMaxHealth(iter.EmptyShipObject, iter.SavedHealth)
				end
			end
		end
	end

		-- MorphTank default behavior
	if (Mission.m_MorphTankAutoDeployType > 0) then
		local i = 1
		while i <= #Mission.MorphTankList do
			local entry = Mission.MorphTankList[i]
			if (not IsAround(entry.MorphTankObject)) or (entry.CmdSet) then
				table.remove(Mission.MorphTankList, i)
			else
				i = i + 1
			end
		end

		-- MoprhTank List
		for _, iter in ipairs(Mission.MorphTankList) do
			SetCommand(iter.MorphTankObject, CMD_CLOSE + Mission.m_MorphTankAutoDeployType)
			iter.CmdSet = true
		end
	end

	-- Clean up dead commbunkers
	local i = 1
	while i <= #Mission.CommBunkerList do
		local entry = Mission.CommBunkerList[i]
		if (not IsAround(entry.CommBunkerObject)) then
			table.remove(Mission.CommBunkerList, i)
		else
			i = i + 1
		end
	end

	-- Scavenger Management
	if (not TeamPlayOn) or Mission.m_IsMPI then
		ScavengerManagementCode()
	end

	-- Spawn MPI AI. -GBD
	if Mission.m_IsMPI then
		if not Mission.SpawnAI then
			
			local MaxAI_Teams = Mission.m_NumSpawnPoints
			local PlayerLimit = GetVarItemInt("network.session.ivar2")
			local numCommanders = PlayerLimit

			if TeamPlayOn then
				MaxAI_Teams = Mission.m_NumSpawnPoints - 1
			else 
				for i = 1, PlayerLimit do
					if Mission.m_ThugFlag[i] then
						numCommanders = numCommanders - 1
					end
				end
				MaxAI_Teams = Mission.m_NumSpawnPoints - numCommanders
			end
			
			local MaxTeams = (MAX_TEAMS - 1) - PlayerLimit
			if MaxAI_Teams > MaxTeams then MaxAI_Teams = MaxTeams end
			MaxAI_Teams = clamp(MaxAI_Teams, 0, 5)
			
			-- Loop over AI
			for i = 0, MAX_AI_TEAMS - 1 do

				local CPUTeam = 11 + i -- Teams 11-15
				
				if (Mission.m_AIRace[i+1] and Mission.m_AIRace[i+1] > 0) then
					if i >= MaxAI_Teams then
						local msg = string.format(TranslateString("mission", "ERROR: CPU %d (Team: %d) spawn skipped: Too many possible Humans (%d) for map Spawns (%d).") or "ERROR: CPU %d (Team: %d) spawn skipped: Too many possible Humans (%d) for map Spawns (%d).", i + 1, CPUTeam, numCommanders, Mission.m_NumSpawnPoints)
						PrintConsoleMessage(msg)
					else
						local CPURecy = ""
						local pContents = GetCheckedNetworkSvar(12, NETLIST_Recyclers)
						local raceChar = Mission.m_AIRace[i+1]
						if type(raceChar) == "number" then raceChar = string.char(raceChar) end

						if pContents and pContents ~= "" then
							CPURecy = pContents
						else
							CPURecy = string.format("%svrecycpu_vsr", raceChar)
						end
						
						local TempH = GetObjectByTeamSlot(CPUTeam, DLL_TEAM_SLOT_RECYCLER)
						if TempH then
							local cpuRace = IsRecyclerODF(TempH)
							if cpuRace ~= 0 then
								Mission.m_AIRace[i+1] = cpuRace
							end
						else
							local PathName = string.format("Enemy_%d", CPUTeam)
							TempH = BuildObject(CPURecy, CPUTeam, PathName)
						end
						
						if TempH then
							SetScrap(CPUTeam, 40)
							SetCPUAIPlan(CPUTeam, CPUTeam - 5)
							
							local AITeamName = string.format(TranslateString("cfg", "Computer Team %d") or "Computer Team %d", CPUTeam)
							SetTeamNameForStat(CPUTeam, AITeamName)
							
							local Where = GetPosition(TempH)
							local VariantName = ""
							
							-- Extract variant
							local u1 = string.find(CPURecy, "_")
							if u1 then
								local u2 = string.find(CPURecy, "_", u1 + 1)
								if u2 then
									VariantName = string.sub(CPURecy, u2)
								else
									VariantName = string.sub(CPURecy, u1)
								end
							end
							
							Mission.m_CreatingStartingVehicles = true
							_StartingVehicles.CreateVehicles(CPUTeam, raceChar, VariantName, Mission.m_StartingVehiclesMask, Where)
							Mission.m_CreatingStartingVehicles = false
							
							-- Build Starting Vehicles
							-- Build Starting Vehicles
							local ScavODF = raceChar .. "vscav" .. VariantName
							local TurretODF = raceChar .. "vturr" .. VariantName
							local GTowODF = raceChar .. "bspir" .. VariantName
							local ScoutODF = raceChar .. "vscout" .. VariantName
							local SentODF = raceChar .. "vsent" .. VariantName
							local TankODF = raceChar .. "vtank" .. VariantName
							
							local posNear = GetPositionNear(Where, AllyMinRadiusAway, AllyMaxRadiusAway)

							for x = 0, 4 do
								if x < 1 then BuildStartingVehicle(CPUTeam, raceChar, ScavODF, ScavODF, posNear) end
								if x < 2 then BuildStartingVehicle(CPUTeam, raceChar, TurretODF, TurretODF, posNear) end
								
								if Mission.m_CPUForce > 0 then
									if x < 2 then
										local path = string.format("%dgtow%d", CPUTeam, x + 1)
										BuildStartingVehicle(CPUTeam, raceChar, GTowODF, TurretODF, path)
										BuildStartingVehicle(CPUTeam, raceChar, SentODF, ScoutODF, posNear)
									end
									if Mission.m_CPUForce > 1 then
										if x < 1 then BuildStartingVehicle(CPUTeam, raceChar, SentODF, ScoutODF, posNear) end
										if x > 1 and x < 4 then
											local path = string.format("%dgtow%d", CPUTeam, x + 1)
											BuildStartingVehicle(CPUTeam, raceChar, GTowODF, TurretODF, path)
										end
										if x < 3 then BuildStartingVehicle(CPUTeam, raceChar, TankODF, TankODF, posNear) end
									end
								end
							end
							
							Mission.m_TeamIsSetUp[CPUTeam] = true
						else
							Mission.m_AIRace[i+1] = 0
						end
					end
				end
			end
			Mission.SpawnAI = true
		end
		
		-- AI Scrap Cheat
		local m_NumHumans = 0
		for i = 1, MAX_TEAMS - 1 do
			local h = GetPlayerHandle(i)
			if IsPlayer(h) then m_NumHumans = m_NumHumans + 1 end
		end
		
		for i = 1, MAX_TEAMS - 1 do
			if (i >= 6) and (Mission.m_CPUForce > 0) then
				local Turns, Amount = 0, 0
				if Mission.m_CPUForce == 0 then Turns = Mission.m_GameTPS * 3; Amount = 1
				elseif Mission.m_CPUForce == 1 then Turns = Mission.m_GameTPS * 2; Amount = 1
				elseif Mission.m_CPUForce == 2 then Turns = Mission.m_GameTPS * 1; Amount = 1
				elseif Mission.m_CPUForce == 3 then Turns = math.floor(Mission.m_GameTPS / 5); Amount = 1
				end
				
				if (Turns > 0) and ((Mission.m_ElapsedGameTime % Turns) == 0) then
					AddScrap(i, Amount)
				end
				
				-- Humans scaling
				if m_NumHumans == 1 then Turns = Mission.m_GameTPS
				elseif m_NumHumans == 2 then Turns = math.floor(Mission.m_GameTPS * 0.9)
				elseif m_NumHumans == 3 then Turns = math.floor(Mission.m_GameTPS * 0.8)
				elseif m_NumHumans == 4 then Turns = math.floor(Mission.m_GameTPS * 0.7)
				elseif m_NumHumans == 5 then Turns = math.floor(Mission.m_GameTPS * 0.6)
				else Turns = 0 end
				
				if (Turns > 0) and ((Mission.m_ElapsedGameTime % Turns) == 0) then
					AddScrap(i, Amount)
				end
			elseif Mission.m_HumanForce > 0 then
				local Turns, Amount = 0, 0
				if Mission.m_HumanForce == 0 then Turns = Mission.m_GameTPS * 10; Amount = 1
				elseif Mission.m_HumanForce == 1 then Turns = Mission.m_GameTPS * 8; Amount = 1
				elseif Mission.m_HumanForce == 2 then Turns = Mission.m_GameTPS * 6; Amount = 1
				elseif Mission.m_HumanForce == 3 then Turns = Mission.m_GameTPS * 4; Amount = 1
				end
				
				if (Turns > 0) and ((Mission.m_ElapsedGameTime % Turns) == 0) then
					AddScrap(i, Amount)
				end
			end
		end
	end
end


function AddPlayer(id, Team, IsNewPlayer)
	if not Mission.m_DidInit then
		Init()
	elseif IsNewPlayer and Mission.m_IsMPI then
		DoTaunt(TAUNTS_NewHuman)
	end
	
	if IsNewPlayer then
		local PlayerH = SetupPlayer(Team)
		SetAsUser(PlayerH, Team)
		AddPilotByHandle(PlayerH)
	end
end

function DeletePlayer(id)
	if Mission.m_IsMPI then
		DoTaunt(TAUNTS_LeftHuman)
	end
end

local function RespawnPilot(DeadObjectHandle, Team)
	local spawnpointPosition = SetVector(0, 0, 0)
	
	if (Team < 1) or (Team >= MAX_TEAMS) then
		spawnpointPosition = GetSafestSpawnpoint()
	else
		spawnpointPosition.x = Mission.m_TeamPos[Team].x
		spawnpointPosition.y = Mission.m_TeamPos[Team].y
		spawnpointPosition.z = Mission.m_TeamPos[Team].z
		Mission.m_SpawnedAtTime[Team] = Mission.m_ElapsedGameTime
	end
	
	local OldPos = GetPosition(DeadObjectHandle)
	local respawnHeight = RespawnPilotHeight
	
	if (math.abs(OldPos.x) > 0.01) and (math.abs(OldPos.z) > 0.01) then
		local dx = OldPos.x - spawnpointPosition.x
		local dz = OldPos.z - spawnpointPosition.z
		local distanceAway = math.sqrt((dx * dx) + (dz * dz))
		
		if distanceAway < 100.0 then
			respawnHeight = 35.0
		else
			local numAllies = CountAlliedPlayers(Team)
			respawnHeight = 30.0 + (math.sqrt(distanceAway) * 1.25)
			local minRespawnHeight = 40.0
			local maxRespawnHeight = 70.0 + (15.0 * numAllies)
			
			if respawnHeight < minRespawnHeight then respawnHeight = minRespawnHeight
			elseif respawnHeight > maxRespawnHeight then respawnHeight = maxRespawnHeight
			end
		end
	end
	
	if Mission.m_RespawnAtLowAltitude then
		respawnHeight = 2.0
	end
	
	spawnpointPosition.x = spawnpointPosition.x + (GetRandomFloat(1.0) - 0.5) * (2.0 * RespawnDistanceAwayXZRange)
	spawnpointPosition.z = spawnpointPosition.z + (GetRandomFloat(1.0) - 0.5) * (2.0 * RespawnDistanceAwayXZRange)
	
	local curFloor = TerrainFindFloor(spawnpointPosition.x, spawnpointPosition.z) + 2.5
	if spawnpointPosition.y < curFloor then
		spawnpointPosition.y = curFloor
	end
	
	spawnpointPosition.y = spawnpointPosition.y + respawnHeight
	spawnpointPosition.y = spawnpointPosition.y + (GetRandomFloat(1.0) * RespawnDistanceAwayYRange)
	
	local NewPerson = BuildObject(GetInitialPlayerPilotODF(GetRaceOfTeam(Team), Team), Team, spawnpointPosition)
	
	if NewPerson then
		if Mission.m_PilotInvunerability > 0 then
			Mission.m_PilotInvTime[Team] = Mission.m_PilotInvunerability
			Mission.m_SavedPilotInvHealth[Team] = GetMaxHealth(NewPerson)
			Mission.m_PilotInvUser[Team] = NewPerson
			SetMaxHealth(NewPerson, 0)
		end
		
		SetAsUser(NewPerson, Team)
		AddPilotByHandle(NewPerson)
		SetRandomHeadingAngle(NewPerson)
		
		if Team == 0 then
			MakeInert(NewPerson)
		end
	end
	
	return EJECTKILLRETCODES_DLLHANDLED
end

local function DeadObject(DeadObjectHandle, KillersHandle, isDeadPerson, isDeadAI)
	local deadObjectTeam = GetTeamNum(DeadObjectHandle)
	local ObjClass = GetClassLabel(DeadObjectHandle)
	local isTorpedo = (string.lower(ObjClass or "") == "class_torpedo")
	
	if (deadObjectTeam ~= 0) and (not IsPowerup(DeadObjectHandle)) and (not isTorpedo) then
		local deadObjectIsPlayer = IsPlayer(DeadObjectHandle)
		local killerObjectIsPlayer = IsPlayer(KillersHandle)
		local relationship = GetTeamRelationship(DeadObjectHandle, KillersHandle)
		local deadObjectScrapCost = GetActualScrapCost(DeadObjectHandle)
		
		if deadObjectIsPlayer then
			if Mission.m_GameType ~= 4 then
				AddScore(DeadObjectHandle, -math.floor(deadObjectScrapCost / 20.0))
			end
			
			if isDeadPerson then
				AddDeaths(DeadObjectHandle, 1)
			end
		else
			if Mission.m_KillForAIKill then
				AddDeaths(DeadObjectHandle, 1)
			end
			if Mission.m_PointsForAIKill and (Mission.m_GameType ~= 4) then
				AddScore(DeadObjectHandle, -math.floor(deadObjectScrapCost / 20.0))
			end
		end
		
		if killerObjectIsPlayer then
			if (relationship == TEAMRELATIONSHIP_SAMETEAM) or (relationship == TEAMRELATIONSHIP_ALLIEDTEAM) then
				if DeadObjectHandle ~= KillersHandle then
					AddKills(KillersHandle, -1)
					if Mission.m_GameType ~= 4 then
						AddScore(KillersHandle, -math.floor(deadObjectScrapCost / 10.0))
					end
				end
			else
				AddKills(KillersHandle, 1)
				if Mission.m_GameType ~= 4 then
					AddScore(KillersHandle, math.floor(deadObjectScrapCost / 10.0))
				end
			end
		else
			if (relationship == TEAMRELATIONSHIP_SAMETEAM) or (relationship == TEAMRELATIONSHIP_ALLIEDTEAM) then
				if Mission.m_KillForAIKill then AddKills(KillersHandle, -1) end
				if Mission.m_PointsForAIKill and (Mission.m_GameType ~= 4) then
					AddScore(KillersHandle, -math.floor(deadObjectScrapCost / 10.0))
				end
			else
				if Mission.m_KillForAIKill then AddKills(KillersHandle, 1) end
				if Mission.m_PointsForAIKill and (Mission.m_GameType ~= 4) then
					AddScore(KillersHandle, math.floor(deadObjectScrapCost / 10.0))
				end
			end
		end
		
		local spawnKillTime = MaxSpawnKillTime * Mission.m_GameTPS
		local isSpawnKill = (DeadObjectHandle ~= KillersHandle) and 
							(not isDeadAI) and
							(deadObjectTeam > 0) and (deadObjectTeam < MAX_TEAMS) and
							(Mission.m_SpawnedAtTime[deadObjectTeam] > 0) and
							((Mission.m_ElapsedGameTime - Mission.m_SpawnedAtTime[deadObjectTeam]) < spawnKillTime)
							
		if isSpawnKill then
			local msg = string.format(TranslateString("mission", "Spawn kill by %s on %s") or "Spawn kill by %s on %s", GetPlayerName(KillersHandle), GetPlayerName(DeadObjectHandle))
			AddToMessagesBox(msg)
			AddScore(KillersHandle, -ScoreDecrementForSpawnKill)
		end
		
		if (Mission.m_KillLimit > 0) and (GetKills(KillersHandle) >= Mission.m_KillLimit) then
			NoteGameoverByKillLimit(KillersHandle)
			DoGameover(endDelta)
		end
	else
		return EJECTKILLRETCODES_DOEJECTPILOT
	end
	
	if isDeadAI then
		if isDeadPerson then
			return EJECTKILLRETCODES_DLLHANDLED
		else
			return EJECTKILLRETCODES_DOEJECTPILOT
		end
	else
		if Mission.m_IsMPI and (deadObjectTeam > 0) and (deadObjectTeam < 11) then
			DoTaunt(TAUNTS_HumanShipDestroyed)
		end
		
		if isDeadPerson then
			return RespawnPilot(DeadObjectHandle, deadObjectTeam)
		else
			return EJECTKILLRETCODES_DOEJECTPILOT
		end
	end
end

function PlayerEjected(DeadObjectHandle)
	local deadObjectTeam = GetTeamNum(DeadObjectHandle)
	if deadObjectTeam == 0 then return EJECTKILLRETCODES_DLLHANDLED end
	
	local isDeadAI = not IsPlayer(DeadObjectHandle)
	return DeadObject(DeadObjectHandle, DeadObjectHandle, false, isDeadAI)
end

function ObjectKilled(DeadObjectHandle, KillersHandle)
	local isDeadAI = not IsPlayer(DeadObjectHandle)
	local isDeadPerson = IsPerson(DeadObjectHandle)
	
	-- Sanity check for multiworld? (Ignoring GetCurWorld check as Lua implies lockstep usually?)
	-- if GetCurWorld() ~= 0 then return EJECTKILLRETCODES_DOEJECTPILOT end
	
	return DeadObject(DeadObjectHandle, KillersHandle, isDeadPerson, isDeadAI)
end

function ObjectSniped(DeadObjectHandle, KillersHandle)
	local isDeadAI = not IsPlayer(DeadObjectHandle)
	-- Dead person means we must always respawn a new person
	return DeadObject(DeadObjectHandle, KillersHandle, true, isDeadAI)
end


-- Moved to BZ1Helper. -GBD
-- Notification to the DLL: a sniper shell has hit a piloted
-- craft. The exe passes the current world, shooters handle, victim
-- handle, and the ODF string of the ordnance involved in the
-- snipe. Returns a code detailing what to do.
--
-- !! Note : If DLLs want to do any actions to the world based on this
-- PreSnipe callback, they should (1) Ensure curWorld == 0 (lockstep)
-- -- do NOTHING if curWorld is != 0, and (2) probably queue up an
-- action to do in the next Execute() call.

--[[
function PreSnipe(curWorld, shooterHandle, victimHandle, ordnanceTeam, pOrdnanceODF)
	-- Default value.
	local returnvalue = PRESNIPE_KILLPILOT

	-- If Friendly Fire is off, then see if we should disallow the snipe
	if not Mission.m_bIsFriendlyFireOn then
		local relationship = GetTeamRelationship(shooterHandle, victimHandle)
		if (relationship == TEAMRELATIONSHIP_ALLIEDTEAM) then
			-- Allow snipes of items on team 0/perceived team 0, as long
			-- as they're not a local/remote player
			if IsPlayer(victimHandle) or (GetTeamNum(victimHandle) ~= 0) then
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
]]

-- Notification to the DLL: called when a pilot tries to enter an
-- empty craft, and all other checks (i.e. craft is empty, masks
-- match, etc) have passed. DLLs can prevent that pilot from entering
-- the craft if desired.
--
-- !! Note : If DLLs want to do any actions to the world based on this
-- PreGetIn callback, they should (1) Ensure curWorld == 0 (lockstep)
-- -- do NOTHING if curWorld is != 0, and (2) probably queue up an
-- action to do in the next Execute() call.

function PreGetIn(curWorld, pilotHandle, emptyCraftHandle)
	if curWorld ~= 0 then
		return PREGETIN_ALLOW
	end
	
	local relationship = GetTeamRelationship(pilotHandle, emptyCraftHandle)
	if (relationship == TEAMRELATIONSHIP_ALLIEDTEAM) and (not IsPlayer(pilotHandle)) and (not Mission.m_SetThugPilotFlag) then
		SetTeamNum(pilotHandle, GetTeamNum(emptyCraftHandle))
	end
	
	local pilotTeam = GetTeamNum(pilotHandle)
	if Mission.m_PilotInvUser[pilotTeam] == pilotHandle then
		SetMaxHealth(pilotHandle, Mission.m_SavedPilotInvHealth[pilotTeam])
		Mission.m_PilotInvTime[pilotTeam] = 0
	end
	
	if Mission.m_IsMPI and (GetTeamNum(emptyCraftHandle) > 10) then
		AddToDispatch(emptyCraftHandle, 15.0, false, 0, false)
	end
	
	return PREGETIN_ALLOW
end

function ScavengerManagementCode()
	-- Clean ThugScavengerList
	local i = 1
	while i <= #Mission.ThugScavengerList do
		local iter = Mission.ThugScavengerList[i]
		-- ShouldRemoveThugScavengerObject logic:
		local ObjClass = GetClassLabel(iter.ThugScavengerObject) or ""
		local lowerClass = string.lower(ObjClass)
		if (not IsAround(iter.ThugScavengerObject)) or (lowerClass == "class_extractor") or (lowerClass == "class_silo") then
			table.remove(Mission.ThugScavengerList, i)
		else
			i = i + 1
		end
	end
	
	for _, iter in ipairs(Mission.ThugScavengerList) do
		local Team = GetTeamNum(iter.ThugScavengerObject)
		
		if (not Mission.m_ThugFlag[Team]) and (iter.ScavengerTeam ~= Team) then
			iter.ScavengerTeam = Team
		elseif (not TeamPlayOn) then -- Thug team, handle scrap swapping
			local ScavScrap = GetScavengerCurScrap(iter.ThugScavengerObject)
			
			if ScavScrap > 0 then
				local CurrScrap = GetScrap(iter.ScavengerTeam)
				local MaxScrap = GetMaxScrap(iter.ScavengerTeam)
				
				if (CurrScrap + ScavScrap) > MaxScrap then
					local TempCurrScrap = MaxScrap - CurrScrap
					local TempScavScrap = ScavScrap - TempCurrScrap
					
					AddScrap(iter.ScavengerTeam, TempCurrScrap)
					SetScavengerCurScrap(iter.ThugScavengerObject, TempScavScrap)
				else
					AddScrap(iter.ScavengerTeam, ScavScrap)
					SetScavengerCurScrap(iter.ThugScavengerObject, 0)
				end
			end
			
			if (Team ~= iter.ScavengerTeam) and IsDeployed(iter.ThugScavengerObject) then
				SetTeamNum(iter.ThugScavengerObject, iter.ScavengerTeam)
			end
		end
	end
	
	-- Clean ThugPilotList
	local i = 1
	while i <= #Mission.ThugPilotList do
		local iter = Mission.ThugPilotList[i]
		-- ShouldRemoveThugPilotObject logic
		if (not IsAround(iter.ThugPilotObject)) or (iter.SwitchTickTimer < 0) or IsPlayer(iter.ThugPilotObject) then
			table.remove(Mission.ThugPilotList, i)
		else
			i = i + 1
		end
	end
	
	for _, iter in ipairs(Mission.ThugPilotList) do
		local Team = GetTeamNum(iter.ThugPilotObject)
		
		if Mission.m_ThugFlag[Team] and (iter.SwitchTickTimer <= 0) then
			local TempCommanderTeam = 1
			for x = 1, MAX_TEAMS - 1 do
				if (Mission.m_AllyTeams[Team] == Mission.m_AllyTeams[x]) and (not Mission.m_ThugFlag[x]) then
					TempCommanderTeam = x
				end
			end
			
			if Team ~= TempCommanderTeam then
				SetTeamNum(iter.ThugPilotObject, TempCommanderTeam)
			end
		end
		iter.SwitchTickTimer = iter.SwitchTickTimer - 1
	end
end

function ExecuteST_Capture()
	local Winner = false
	
	for i = 1, MAX_TEAMS - 1 do
		Mission.UserTarget[i] = GetUserTarget(i)
		
		if Mission.m_NumCaptureGoals > 0 then
			local x = 1
			while x <= Mission.m_NumCaptureGoals do
				local goal = Mission.m_CaptureGoals[x]
				
				if IsAround(goal) then
					SetObjectiveOn(goal)
					
					local TempP = GetPlayerHandle(i)
					local Flagoff = false
					
					for t = 1, MAX_TEAMS - 1 do
						local TempP2 = GetPlayerHandle(t)
						if (t ~= i) and (not IsTeamAllied(i, t)) and (Mission.UserTarget[i] == goal) and (Mission.UserTarget[t] == goal) and TempP and TempP2 and
						   (GetDistance(goal, TempP) < 100) and (GetDistance(goal, TempP2) < 100) then
							-- Restore to previous team
							SetTeamNum(goal, Mission.m_CaptureGoalTeam[x])
							Flagoff = true
							break
						end
					end
					
					if Flagoff and (not Mission.m_DualCapture[x]) then
						Mission.m_DualCapture[x] = true
					end
					if not Flagoff then
						Mission.m_DualCapture[x] = false
					end
					
					-- Capture procedures
					if (Mission.UserTarget[i] == goal) and (Mission.m_CaptureGoalTeam[x] ~= i) and 
					   ((Mission.m_CaptureGoalTeam[x] == 0) or (not IsTeamAllied(Mission.m_CaptureGoalTeam[x], i))) and
					   ((Mission.m_GoalBeingCaptured[x] == 0) or (Mission.m_GoalBeingCaptured[x] == i)) and
					   TempP and (GetDistance(goal, TempP) < 100) then
						
						if Mission.m_GoalBeingCaptured[x] == 0 then
							local msg = string.format(TranslateString("mission", "-- A Goal is being Captured by %s!") or "-- A Goal is being Captured by %s!", GetPlayerName(GetPlayerHandle(i)))
							AddToMessagesBox(msg, Make_RGB(255, 255, 0))
						end
						
						Mission.m_CaptureGoalIsSwitching[i][x] = true
						
						if not Mission.m_DualCapture[x] then
							Mission.m_CaptureGoalTime[x] = Mission.m_CaptureGoalTime[x] + 1
						end
						
						Mission.m_GoalBeingCaptured[x] = i
						Mission.m_TeamIsCapturing[i] = true
						
						local TotalCaptureTime = math.floor((Mission.m_CaptureTime - Mission.m_CaptureGoalTime[x]) / Mission.m_GameTPS)
						
						if GetLocalPlayerTeamNumber() == i then
							StartCockpitTimer(TotalCaptureTime, math.floor(TotalCaptureTime / 2), math.floor(TotalCaptureTime / 4))
						end
						
						if (Mission.m_CaptureGoalTime[x] % (1 * Mission.m_GameTPS)) == 0 then
							if not Mission.m_CaptureGoalObjectify[x] then
								SetTeamNum(goal, i)
								SetObjectiveOn(goal)
								Mission.m_CaptureGoalObjectify[x] = true
							else
								SetTeamNum(goal, Mission.m_CaptureGoalTeam[x])
								SetObjectiveOff(goal)
								Mission.m_CaptureGoalObjectify[x] = false
							end
						end
						
						if Mission.m_CaptureGoalTime[x] == Mission.m_CaptureTime then
							if Mission.m_CaptureGoalTeam[x] ~= 0 then
								local h = GetPlayerHandle(Mission.m_CaptureGoalTeam[x])
								if h then AddScore(h, -1) end
							end
							
							local OldPlayer = GetPlayerHandle(Mission.m_CaptureGoalTeam[x])
							
							Mission.m_CaptureGoalTeam[x] = i
							SetTeamNum(goal, i)
							for v = 0, 7 do
								local TempTap = GetTap(goal, v)
								if TempTap then SetTeamNum(TempTap, i) end
							end
							
							local pH = GetPlayerHandle(i)
							if pH then AddScore(pH, 1) end
							Mission.m_GoalBeingCaptured[x] = 0
							
							if GetLocalPlayerTeamNumber() == i then
								StopCockpitTimer()
								HideCockpitTimer()
							end
							
							SetObjectiveOff(goal)
							Mission.m_CaptureGoalTime[x] = 0
							Mission.m_CaptureGoalIsSwitching[i][x] = false
							Mission.m_TeamIsCapturing[i] = false
							
							local msg
							local winnerName = (pH and GetPlayerName(pH)) or "Unknown"
							if IsAround(OldPlayer) then
								msg = string.format(TranslateString("mission", "-- %s Captured a Goal from %s!") or "-- %s Captured a Goal from %s!", winnerName, GetPlayerName(OldPlayer))
							else
								msg = string.format(TranslateString("mission", "-- %s Captured a Goal!") or "-- %s Captured a Goal!", winnerName)
							end
							AddToMessagesBox(msg, Make_RGB(255, 255, 0))
						end
						
					elseif Mission.m_CaptureGoalIsSwitching[i][x] then
						Mission.m_CaptureGoalTime[x] = 0
						Mission.m_GoalBeingCaptured[x] = 0
						SetTeamNum(goal, Mission.m_CaptureGoalTeam[x])
						
						if GetLocalPlayerTeamNumber() == i then
							StopCockpitTimer()
							HideCockpitTimer()
						end
						
						if Mission.UserTarget[i] == goal then
							local h = GetPlayerHandle(i)
							if h then SetTarget(h, 0) end
						end
						
						Mission.m_CaptureGoalIsSwitching[i][x] = false
						Mission.m_TeamIsCapturing[i] = false
					end
					
					x = x + 1
				else
					-- CaptureGoal is not around, remove it
					table.remove(Mission.m_CaptureGoals, x)
					table.remove(Mission.m_CaptureGoalTime, x)
					table.remove(Mission.m_CaptureGoalTeam, x)
					table.remove(Mission.m_GoalBeingCaptured, x)
					table.remove(Mission.m_CaptureGoalObjectify, x)
					-- m_CaptureGoalIsSwitching is 2D, tricky to remove column. 
					-- Lua tables don't shift columns automatically. We might leave it dirty or rebuild.
					-- For safety/simplicity in this port, we'll just ignore the column drift for now or just decrement count.
					-- Correct logic would be to iterate all teams and remove index x.
					for t = 1, MAX_TEAMS - 1 do
						table.remove(Mission.m_CaptureGoalIsSwitching[t], x)
					end
					table.remove(Mission.m_DualCapture, x)
					
					Mission.m_NumCaptureGoals = Mission.m_NumCaptureGoals - 1
					-- Don't increment x, so we check the new element at this index next
				end
			end
			
			-- Look for a winner
			if Mission.m_KillLimit > 0 then
				local h = GetPlayerHandle(i)
				if h and (GetScore(h) >= Mission.m_KillLimit) then
					Winner = true
				end
			else
				Winner = true
				for t = 1, Mission.m_NumCaptureGoals do
					if (Mission.m_GoalBeingCaptured[t] ~= 0) or 
					   (Mission.m_CaptureGoalTeam[t] == 0) or 
					   (Mission.m_CaptureGoalTeam[t] ~= i and (not IsTeamAllied(i, Mission.m_CaptureGoalTeam[t]))) then
						Winner = false
						break
					end
				end
			end
			
			if Winner and (not Mission.m_GameOver) then
				local TempMsgString = ""
				if TeamPlayOn then
					local WinningTeamgroup = WhichTeamGroup(i)
					if Mission.m_KillLimit > 0 then
						TempMsgString = string.format(TranslateString("mission", "-- Team %d has won! Captured %d Goals!") or "-- Team %d has won! Captured %d Goals!", WinningTeamgroup + 1, Mission.m_KillLimit)
					else
						TempMsgString = string.format(TranslateString("mission", "-- Team %d has won! Captured all Goals!") or "-- Team %d has won! Captured all Goals!", WinningTeamgroup + 1)
					end
					local h = GetPlayerHandle(i)
					if h then AddScore(h, ScoreForWinning) end
					NoteGameoverWithCustomMessage(TempMsgString)
					
					for k = 1, MAX_TEAMS - 1 do
						if WhichTeamGroup(k) == WinningTeamgroup then
							local kH = GetPlayerHandle(k)
							if kH then AddScore(kH, ScoreForWinning) end
						end
					end
					
					AddToMessagesBox(TempMsgString, Make_RGB(255, 255, 0))
					DoGameover(endDelta)
					Mission.m_GameOver = true
				else
					if Mission.m_HasAllies[i] then
						if Mission.m_KillLimit > 0 then
							TempMsgString = string.format(TranslateString("mission", "-- Team %d has won! Captured %d Goals!") or "-- Team %d has won! Captured %d Goals!", Mission.m_AllyTeams[i], Mission.m_KillLimit)
						else
							TempMsgString = string.format(TranslateString("mission", "-- Team %d has won! Captured All Goals!") or "-- Team %d has won! Captured All Goals!", Mission.m_AllyTeams[i])
						end
						local h = GetPlayerHandle(i)
						if h then AddScore(h, ScoreForWinning) end
						NoteGameoverWithCustomMessage(TempMsgString)
					else
						local recyH = Mission.m_RecyclerHandles[i]
						local recyName = (recyH and GetPlayerName(recyH)) or "Unknown"

						if Mission.m_KillLimit > 0 then
							TempMsgString = string.format(TranslateString("mission", "-- %s has won! Captured %d Goals!") or "-- %s has won! Captured %d Goals!", recyName, Mission.m_KillLimit)
						else
							TempMsgString = string.format(TranslateString("mission", "-- %s has won! Captured All Goals!") or "-- %s has won! Captured All Goals!", recyName)
						end
						
						local h = GetPlayerHandle(i)
						if h then 
							AddScore(h, ScoreForWinning)
							NoteGameoverByScore(h)
						end
					end
					AddToMessagesBox(TempMsgString, Make_RGB(255, 255, 0))
					DoGameover(endDelta)
					Mission.m_GameOver = true
				end
			end
		else
			if not Mission.m_GameOver then
				AddToMessagesBox(TranslateString("mission", "-- No Capture Goals! Game will be over very soon!") or "-- No Capture Goals! Game will be over very soon!", Make_RGB(255, 255, 0))
				DoGameover(endDelta)
				Mission.m_GameOver = true
			end
		end
	end
end
