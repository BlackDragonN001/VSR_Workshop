function InitAIPLua(team)
    AIPUtil.print(team, "Starting Lua Conditions for Cerberi AIP VSR_c6_0");
end

-- BUILD PLAN CONDITIONS.

function BuildServicePodCondition(team, time)
    if (DoesRecyclerExist(team, time) == false) then
        return false, "I don't have a Recycler yet.";
    end

    -- Check we have at least 2 Scavengers in the field before doing this.
    if (ScavengerCount(team, time) < 2) then
        return false, "I need to prioritise Scavengers over Service Pods first.";
    end

    if (AIPUtil.GetScrap(team, false) < 2) then
        return false, "I don't have enough scrap for a Service Pod.";
    end

    -- Check to see if Service Pods exist.
    if (AIPUtil.CountUnits(team, "apserv", "sameteam", false) >= 2) then
        return false, "I already have enough Service Pods.";
    end

    if (DoesServiceBayExist(team, time)) then
        return false, "I have a Service Bay now, no more pods are needed.";
    end

    return true, "Building Service Pods for Recovery...";
end

function BuildScavengerCondition(team, time)
    if (DoesRecyclerExist(team, time) == false) then
        return false, "I don't have a Recycler yet.";
    end

    if (ScavengerCount(team, time) >= 4) then
        return false, "I already have enough Scavengers.";
    end

    if (AIPUtil.GetScrap(team, false) < 20) then
        return false, "I don't have enough scrap for a Scavenger.";
    end

    return true, "My Recycler is healthy, and I need more Scavengers. Tasking Recycler to build a Scavenger.";
end

function BuildConstructorCondition(team, time)
    if (DoesRecyclerExist(team, time) == false) then
        return false, "I don't have a Recycler yet.";
    end

    if (ExtractorCount(team, time) <= 0) then
        return false, "I don't have any deployed Scavengers yet.";
    end

    if (ConstructorCount(team, time) >= 3) then
        return false, "I already have enough Constructors.";
    end

    if (AIPUtil.GetScrap(team, false) < 40) then
        return false, "I don't have enough scrap for a Constructor.";
    end

    return true,
        "My Recycler is healthy, I have an Extractor, and I need more Constructors. Tasking Recycler to build a Constructor.";
end

function BuildPowerLoopCondition(team, time)
    if (DoesConstructorExist(team, time) == false) then
        return false, "I don't have a Constructor yet.";
    end

    if (AIPUtil.GetPower(team, false) > 0) then
        return false, "I already have enough Power.";
    end

    if (AIPUtil.GetScrap(team, false) < 30) then
        return false, "I don't have enough scrap for a Power Plant.";
    end

    return true, "I need some power. Attempting to task a Constructor to build...";
end

function BuildFactoryCondition(team, time)
    if (DoesConstructorExist(team, time) == false) then
        return false, "I don't have a Constructor yet.";
    end

    if (AIPUtil.GetPower(team, false) <= 0) then
        return false, "I don't have enough Power for a Factory.";
    end

    if (AIPUtil.GetScrap(team, false) < 55) then
        return false, "I don't have enough scrap for a Factory.";
    end

    return true, "I can build a Factory. Attempting to task a Constructor to build...";
end

function BuildRelayCondition(team, time)
    if (DoesConstructorExist(team, time) == false) then
        return false, "I don't have a Constructor yet.";
    end

    if (AIPUtil.GetPower(team, false) <= 0) then
        return false, "I don't have enough Power for a Relay Bunker.";
    end

    if (DoesFactoryExist(team, time) == false) then
        return false, "I don't have a Factory yet. Build a Factory first.";
    end

    if (AIPUtil.GetScrap(team, false) < 50) then
        return false, "I don't have enough scrap for a Relay Bunker.";
    end

    return true, "I can build a Relay Bunker. Attempting to task a Constructor to build...";
end

function BuildArmoryCondition(team, time)
    if (DoesConstructorExist(team, time) == false) then
        return false, "I don't have a Constructor yet.";
    end

    if (AIPUtil.GetPower(team, false) <= 0) then
        return false, "I don't have enough Power for an Armory.";
    end

    if (DoesFactoryExist(team, time) == false) then
        return false, "I don't have a Factory yet. Build a Factory first.";
    end

    if (AIPUtil.GetScrap(team, false) < 60) then
        return false, "I don't have enough scrap for an Armory.";
    end

    return true, "I can build an Armory. Attempting to task a Constructor to build...";
end

function BuildGunTowersCondition(team, time)
    if (DoesConstructorExist(team, time) == false) then
        return false, "I don't have a Constructor yet.";
    end

    if (AIPUtil.GetPower(team, false) <= 0) then
        return false, "I don't have enough Power for a Gun Tower.";
    end

    if (DoesArmoryExist(team, time) == false) then
        return false, "I don't have an Armory so I can't build a Gun Tower.";
    end

    if (AIPUtil.GetScrap(team, false) < 50) then
        return false, "I don't have enough scrap for a Gun Tower.";
    end

    return true, "I can build a Gun Tower. Attempting to task a Constructor to build...";
end

function BuildGunTowersAtGtow1Condition(team, time)
    if (AIPUtil.PathExists("gtow1") == false) then
        return false, "Path: gtow1 doesn't exist, so I can't build any Gun Towers there.";
    end

    if (DoesConstructorExist(team, time) == false) then
        return false, "I don't have a Constructor yet.";
    end

    if (AIPUtil.GetPower(team, false) <= 0) then
        return false, "I don't have enough Power for a Gun Tower.";
    end

    if (DoesArmoryExist(team, time) == false) then
        return false, "I don't have an Armory so I can't build a Gun Tower.";
    end

    if (AIPUtil.GetScrap(team, false) < 50) then
        return false, "I don't have enough scrap for a Gun Tower.";
    end

    return true, "I can build a Gun Tower at path: gtow1. Attempting to task a Constructor to build...";
end

function BuildGunTowersAtGtow2Condition(team, time)
    if (AIPUtil.PathExists("gtow2") == false) then
        return false, "Path: gtow2 doesn't exist, so I can't build any Gun Towers there.";
    end

    if (DoesConstructorExist(team, time) == false) then
        return false, "I don't have a Constructor yet.";
    end

    if (AIPUtil.GetPower(team, false) <= 0) then
        return false, "I don't have enough Power for a Gun Tower.";
    end

    if (DoesArmoryExist(team, time) == false) then
        return false, "I don't have an Armory so I can't build a Gun Tower.";
    end

    if (AIPUtil.GetScrap(team, false) < 50) then
        return false, "I don't have enough scrap for a Gun Tower.";
    end

    return true, "I can build a Gun Tower at path: gtow2. Attempting to task a Constructor to build...";
end

function BuildServiceBayCondition(team, time)
    if (DoesConstructorExist(team, time) == false) then
        return false, "I don't have a Constructor yet.";
    end

    if (AIPUtil.GetPower(team, false) <= 0) then
        return false, "I don't have enough Power for a Service Bay.";
    end

    if (DoesFactoryExist(team, time) == false) then
        return false, "I don't have a Factory yet. Build a Factory first.";
    end

    if (DoesArmoryExist(team, time) == false) then
        return false, "I don't have an Armory yet. Build an Armory first.";
    end

    if (AIPUtil.GetScrap(team, false) < 50) then
        return false, "I don't have enough scrap for a Service Bay.";
    end

    return true, "I can build a Service Bay. Attempting to task a Constructor to build...";
end

function BuildJammerCondition(team, time)
    if (DoesConstructorExist(team, time) == false) then
        return false, "I don't have a Constructor yet.";
    end

    if (DoesServiceBayExist(team, time) == false) then
        return false, "I don't have a Service Bay yet. Build a Service Bay first.";
    end

    if (DoesRelayBunkerExist(team, time) == false) then
        return false, "I don't have a Relay Bunker yet. Build a Relay Bunker first.";
    end

    if (AIPUtil.GetScrap(team, false) < 50) then
        return false, "I don't have enough scrap for a Jammer.";
    end

    return true, "I can build a Jammer. Attempting to task a Constructor to build...";
end

function BuildTechCenterCondition(team, time)
    if (DoesConstructorExist(team, time) == false) then
        return false, "I don't have a Constructor yet.";
    end

    if (DoesServiceBayExist(team, time) == false) then
        return false, "I don't have a Service Bay yet. Build a Service Bay first.";
    end

    if (DoesArmoryExist(team, time) == false) then
        return false, "I don't have an Armory so I can't build a Tech Center.";
    end

    if (AIPUtil.GetScrap(team, false) < 80) then
        return false, "I don't have enough scrap for a Tech Center.";
    end

    return true, "I can build a Tech Center. Attempting to task a Constructor to build...";
end

function BuildAntiMatterCondition(team, time)
    if (DoesConstructorExist(team, time) == false) then
        return false, "I don't have a Constructor yet.";
    end

    if (DoesServiceBayExist(team, time) == false) then
        return false, "I don't have a Service Bay yet. Build a Service Bay first.";
    end

    if (DoesArmoryExist(team, time) == false) then
        return false, "I don't have an Armory so I can't build an Anti-Matter Generator.";
    end

    if (AIPUtil.GetScrap(team, false) < 120) then
        return false, "I don't have enough scrap for an Anti-Matter Generator.";
    end

    return true, "I can build an Anti-Matter Generator. Attempting to task a Constructor to build...";
end

function BuildTurretsCondition(team, time)
    -- Make sure we have a pool first.
    if (ExtractorCount(team, time) <= 0) then
        return false, "I don't have any deployed Scavengers yet.";
    end

    -- Make sure we also have a Constructor as that's our priority.
    if (DoesConstructorExist(team, time) == false) then
        return false, "I don't have a Constructor yet.";
    end

    if (AIPUtil.GetScrap(team, false) < 40) then
        return false, "I don't have enough scrap for a turret.";
    end

    -- Do this until we build an armory.
    if (DoesArmoryExist(team, time)) then
        return false, "I have an armory, so I'm not going to waste scrap on turrets.";
    end

    return true, "Building turrets for early map control.";
end

function BuildMineLayersCondition(team, time)
    -- Make sure we have a pool first.
    if (ExtractorCount(team, time) <= 0) then
        return false, "I don't have any deployed Scavengers yet.";
    end

    if (DoesFactoryExist(team, time) == false) then
        return false, "I don't have a Factory yet. Build a Factory first.";
    end

    if (AIPUtil.GetScrap(team, false) < 55) then
        return false, "I don't have enough scrap for a Minelayer.";
    end

    return true, "I can build a Minelayer. Attempting to task the Factory to build...";
end

function BuildServiceTrucksCondition(team, time)
    if (DoesRecyclerExist(team, time) == false) then
        return false, "I don't have a Recycler yet.";
    end

    if (DoesServiceBayExist(team, time) == false) then
        return false, "I don't have a Service Bay yet.";
    end

    if (ServiceTruckCount(team, time) >= 5) then
        return false, "I already have enough Service Trucks.";
    end

    if (AIPUtil.GetScrap(team, false) < 50) then
        return false, "I don't have enough scrap for a Service Truck.";
    end

    return true, "I can build a Service Truck. Attempting to task the Recycler to build...";
end

function BuildGorgonsCondition(team, time)
    if (ExtractorCount(team, time) <= 0) then
        return false, "I don't have any deployed Scavengers yet.";
    end

    if (DoesFactoryExist(team, time) == false) then
        return false, "I don't have a Factory yet. Build a Factory first.";
    end

    if (AIPUtil.CountUnits(team, "cbagen_vsr", "sameteam", false) <= 0) then
        return false, "I don't have an Anti-Matter Generator so I can't build a Gorgon.";
    end

    if (AIPUtil.GetScrap(team, false) < 110) then
        return false, "I don't have enough scrap for a Gorgon.";
    end

    return true, "I can build a Gorgon. Attempting to task the Factory to build...";
end

function UpgradePoolCondition(team, time)
    if (DoesConstructorExist(team, time) == false) then
        return false, "I don't have a Constructor yet.";
    end

    if (ExtractorCount(team, time) <= 0) then
        return false, "I don't have any deployed Scavengers yet.";
    end

    if (AIPUtil.GetScrap(team, false) < 60) then
        return false, "I don't have enough scrap to upgrade an Extractor.";
    end

    return true, "I have an Extractor that can be upgraded. Tasking Constructor to upgrade an Extractor.";
end

function CollectPoolCondition(team, time)
    if (ScavengerCount(team, time) <= 0) then
        return false, "I don't have any Scavengers.";
    end

    if (DoesScrapPoolExist(team, time) == false) then
        return false, "I cannot find any available scrap pools.";
    end

    return true, "Tasking a Scavenger to collect a pool.";
end

function CollectFieldCondition(team, time)
    if (ScavengerCount(team, time) > 0 and DoesLooseScrapExist(team, time)) then
        return true, "Tasking a Scavenger to collect loose.";
    else
        return false, "No loose or Scavenger is available. Cannot collect loose yet.";
    end
end

-- ATTACKER PLAN CONDITIONS.

function EarlyScavengerAttackCondition(team, time)
    -- Check to see if the Human team has any Scavengers first.
    if (AIPUtil.CountUnits(team, "VIRTUAL_CLASS_SCAVENGER", 'enemy', true) <= 0) then
        return false, "The enemy doesn't have any Scavengers for me to attack.";
    end

    -- Make sure we have a pool first.
    if (ExtractorCount(team, time) <= 0) then
        return false, "I don't have any deployed Scavengers yet.";
    end

    return true, "I am going to send early Scouts to attack.";
end

function EarlyScoutAttackCondition(team, time)
    -- Make sure we have a pool first.
    if (ExtractorCount(team, time) <= 0) then
        return false, "I don't have any deployed Scavengers yet.";
    end

    if (DoesFactoryExist(team, time)) then
        return false, "I have a Factory already, I don't want to send Scouts to attack now.";
    end

    return true, "I am going to send early Scouts to attack.";
end

function EarlyTankAttackCondition(team, time)
    -- Make sure we have a pool first.
    if (ExtractorCount(team, time) <= 0) then
        return false, "I don't have any deployed Scavengers yet.";
    end

    if (DoesFactoryExist(team, time) == false) then
        return false, "I don't have a Factory so I can't attack.";
    end

    -- If the enemy has too many Gun Towers, let's stop this and send something heavier.
    if (AIPUtil.CountUnits(team, "defender", 'enemy', true) >= 2) then
        return false, "The enemy has too many Gun Towers. This would be a waste of scrap to attack now.";
    end

    return true, "I am going to send Tanks to attack.";
end

function FirstRocketBomberAttackCondition(team, time)
    -- Make sure we have a pool first.
    if (ExtractorCount(team, time) <= 0) then
        return false, "I don't have any deployed Scavengers yet.";
    end

    if (DoesFactoryExist(team, time) == false) then
        return false, "I don't have a Factory so I can't attack.";
    end

    if (DoesArmoryExist(team, time) == false) then
        return false, "I don't have an Armory so I can't attack.";
    end

    return true, "I am going to send Rocket Bombers to attack.";
end

function SecondRocketBomberAttackCondition(team, time)
    -- Make sure we have a pool first.
    if (ExtractorCount(team, time) <= 0) then
        return false, "I don't have any deployed Scavengers yet.";
    end

    if (DoesFactoryExist(team, time) == false) then
        return false, "I don't have a Factory so I can't attack.";
    end

    if (DoesArmoryExist(team, time) == false) then
        return false, "I don't have an Armory so I can't attack.";
    end

    if (DoesServiceBayExist(team, time) == false) then
        return false, "I don't have a Service Bay so I can't attack.";
    end

    if (DoesRelayBunkerExist(team, time) == false) then
        return false, "I don't have a Relay Bunker so I can't attack.";
    end

    if (AIPUtil.CountUnits(team, "defender", 'enemy', true) < 2) then
        return false, "Enemy defenses are too weak. Let's stick to something lighter for now.";
    end

    return true, "Enemy defenses are mounting. I will send more Rocket Bombers to attack.";
end

function DroneCarrierAttackCondition(team, time)
    -- I think it's safe to limit this to 10 minutes. When 10 minutes, passes this should be allowed to be built.
    if (time < 600) then
        return false, "We haven't been playing for 10 minutes. I can't build a Drone Carrier yet.";
    end

    if (DoesFactoryExist(team, time) == false) then
        return false, "I don't have a Factory so I can't attack.";
    end

    return true, "10 minutes has passed. Tasking Factory to build a Drone Carrier...";
end

function LateDroneCarrierAttackCondition(team, time)
    -- I think it's safe to limit this to 10 minutes. When 15 minutes, passes this should be allowed to be built.
    if (time < 900) then
        return false, "We haven't been playing for 15 minutes. I can't build a Drone Carrier yet.";
    end

    if (DoesFactoryExist(team, time) == false) then
        return false, "I don't have a Factory so I can't attack.";
    end

    return true, "15 minutes has passed. Tasking Factory to build a Drone Carrier...";
end

function FinalAttacksCondition(team, time)
    -- Make sure we have a pool first.
    if (ExtractorCount(team, time) <= 0) then
        return false, "I don't have any deployed Scavengers yet.";
    end

    if (DoesFactoryExist(team, time) == false) then
        return false, "I don't have a Factory so I can't attack.";
    end

    if (DoesTechCenterExist(team, time) == false) then
        return false, "I don't have a Tech Center yet so I can't attack.";
    end

    return true, "I have finished building my base, time for late attacks.";
end

-- RECOVER / SERVICE PLAN CONDITIONS.
function EarlyRecoverCondition(team, time)
    -- Check to see if Service Pods exist.
    if (AIPUtil.CountUnits(team, "apserv", "sameteam", false) <= 0) then
        return false, "I don't have enough Service Pods for unit recovery.";
    end

    if (DoesServiceBayExist(team, time)) then
        return false, "I have a Service Bay now, no more pods are needed.";
    end

    return true, "I have pods, I can recover a unit to full health/ammo";
end

function ServiceBayRecoveryCondition(team, time)
    if (DoesServiceBayExist(team, time) == false) then
        return false, "I don't have a Service Bay yet.";
    end

    return true, "I have a Service Bay and I can send units to repair there.";
end

function ServiceTruckServiceCondition(team, time)
    if (ServiceTruckCount(team, time) < 1) then
        return false, "I don't have any Service Trucks to repair with.";
    end

    return true, "Tasking Service Truck to heal units...";
end

-- COUNT FUNCTIONS TO CHECK IF A NUMBER OF GAME OBJECT EXISTS.

function ScavengerCount(team, time)
    return AIPUtil.CountUnits(team, "VIRTUAL_CLASS_SCAVENGER", "sameteam", true);
end

function ExtractorCount(team, time)
    return AIPUtil.CountUnits(team, "VIRTUAL_CLASS_EXTRACTOR", "sameteam", true);
end

function ConstructorCount(team, time)
    return AIPUtil.CountUnits(team, "VIRTUAL_CLASS_CONSTRUCTIONRIG", "sameteam", true);
end

function ServiceTruckCount(team, time)
    return AIPUtil.CountUnits(team, "VIRTUAL_CLASS_SERVICETRUCK", "sameteam", true);
end

-- BOOLEAN FUNCTIONS TO CHECK IF A SINGULAR GAME OBJECT EXISTS.

function DoesLooseScrapExist(team, time)
    return AIPUtil.CountUnits(team, "resource", "friendly", true) > 0;
end

function DoesScrapPoolExist(team, time)
    return AIPUtil.CountUnits(team, "biometal", "friendly", true) > 0;
end

function DoesRecyclerExist(team, time)
    return AIPUtil.CountUnits(team, "VIRTUAL_CLASS_RECYCLERBUILDING", "sameteam", true) > 0;
end

function DoesRelayBunkerExist(team, time)
    return AIPUtil.CountUnits(team, "VIRTUAL_CLASS_COMMBUNKER", "sameteam", true) > 0;
end

function DoesFactoryExist(team, time)
    return AIPUtil.CountUnits(team, "VIRTUAL_CLASS_FACTORY", "sameteam", true) > 0;
end

function DoesArmoryExist(team, time)
    return AIPUtil.CountUnits(team, "VIRTUAL_CLASS_ARMORY", "sameteam", true) > 0;
end

function DoesTechCenterExist(team, time)
    return AIPUtil.CountUnits(team, "VIRTUAL_CLASS_TECHCENTER", "sameteam", true) > 0;
end

function DoesServiceBayExist(team, time)
    return AIPUtil.CountUnits(team, "VIRTUAL_CLASS_SUPPLYDEPOT", "sameteam", true) > 0;
end

function DoesConstructorExist(team, time)
    return AIPUtil.CountUnits(team, "VIRTUAL_CLASS_CONSTRUCTIONRIG", "sameteam", true) > 0;
end
