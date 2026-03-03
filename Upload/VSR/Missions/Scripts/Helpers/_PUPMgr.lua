--[[
    _PUPMgr.lua
    Converted from PUPMgr.cpp via Antigravity
    
    Utility functions for DLLs-- 'PowerUP ManaGeR'-- handles the list
    of powerups given in the mission, respawns them as appropriate.
]]

local _PUPMgr = {}

-- Internal State
local MAX_POWERUPS = 100
local pup = {} -- Array of tables: { time=0, dt=0, str="", odf="", waiting=false }
local pupHandle = {} -- Array of handles
local PUPCount = 0

function _PUPMgr.Init()
    -- Reset state
    pup = {}
    pupHandle = {}
    PUPCount = 0
    
    local pathNames = GetAiPaths()
    if not pathNames then return end
    
    local pathCount = #pathNames
    
    for i = 1, pathCount do
        if PUPCount < MAX_POWERUPS then
            local label = pathNames[i]
            local skip = false
            
            -- Filtering logic from C++
            if string.sub(label, 1, 4) == "king" then skip = true end
            if string.sub(label, 1, 9) == "edge_path" then skip = true end
            if string.sub(label, 1, 10) == "spawntank8" then skip = true end
            if string.sub(label, 1, 12) == "spawnrocket8" then skip = true end
            if string.sub(label, 1, 5) == "base1" then skip = true end
            if string.sub(label, 1, 5) == "base2" then skip = true end
            if string.sub(label, 1, 4) == "path" then skip = true end
            
            if not skip then
                PUPCount = PUPCount + 1
                pup[PUPCount] = {
                    time = 0,
                    dt = 10.0,
                    str = label,
                    odf = label, -- In C++, odf is copied from label initially
                    waiting = false
                }
                
                -- Parse Delay from Name
                -- Logic: "name_10" -> dt = 10
                -- C++ strchr logic implementation in Lua
                local ptr = string.find(label, "_")
                if ptr then
                    -- Get substring after first underscore
                    local suffix = string.sub(label, ptr + 1)
                    -- Check for second underscore as per C++ logic: 
                    -- C++: ptr = strchr(tmp, '_'); if (ptr) *ptr = 0;
                    -- It essentially looks for the number between underscores or at end?
                    -- "powerup_10" -> suffix "10". "powerup_10_something" -> "10".
                    local ptr2 = string.find(suffix, "_")
                    if ptr2 then
                        suffix = string.sub(suffix, 1, ptr2 - 1)
                    end
                    
                    local v = tonumber(suffix)
                    if v and v > 0 then
                        pup[PUPCount].dt = v
                    else
                        pup[PUPCount].dt = 10.0
                    end
                    
                    -- Update ODF name to truncate at first underscore?
                    -- C++: char *ptr = strchr(pup[PUPCount].odf, '_'); if (ptr) *ptr = 0;
                    -- So "ammo_10" becomes odf "ammo".
                    pup[PUPCount].odf = string.sub(label, 1, ptr - 1)
                else
                     -- C++: if!ptr continue. Bad format. 
                     -- If no underscore, it skips adding? 
                     -- "if(!ptr) continue;"
                     -- So we should revert the increment.
                     pup[PUPCount] = nil
                     PUPCount = PUPCount - 1
                end
            end
        end
    end
    
    -- Build initial objects
    for i = 1, PUPCount do
        if pup[i] then
            pupHandle[i] = BuildObject(pup[i].odf, 0, pup[i].str)
            pup[i].waiting = false
        end
    end
end

function _PUPMgr.Execute()
    local CurTime = GetTime()
    
    for i = 1, PUPCount do
        if pup[i] then
            -- Note: In Lua we need to handle handle validation carefully.
            -- C++: IsAlive(pupHandle[i])
            local isAlive = IsAround(pupHandle[i]) -- IsAlive check? usually IsAround/IsAlive
            
            if (not isAlive) and (not pup[i].waiting) then
                pup[i].waiting = true
                pup[i].time = CurTime + pup[i].dt
            end
            
            if pup[i].waiting and (CurTime > pup[i].time) then
                pupHandle[i] = BuildObject(pup[i].odf, 0, pup[i].str)
                pup[i].waiting = false
            end
        end
    end
end

function _PUPMgr.Save()
    return {
        PUPCount = PUPCount,
        pup = pup,
        pupHandle = pupHandle
    }
end

function _PUPMgr.Load(data)
    if data then
        PUPCount = data.PUPCount or 0
        pup = data.pup or {}
        pupHandle = data.pupHandle or {}
    end
end

-- PostLoad usually handles handle conversion from IDs, but Lua engine might handle simple tables automatically?
-- If not, we might need a manual fixup if handles change ID on load (which they do).
-- C++: ConvertHandles(pupHandle, PUPCount);
-- Lua: If handles are saved as integers, they might need re-lookup or engine magic.
-- Standard BZCC Lua Mission saving usually handles global Mission table. 
-- Since we return a separate table from Save(), ensuring it's merged into the main save might be needed if not using Mission table.
-- However, standard practice: Modules often just have their state managed by the main script calling Load/Save.

return _PUPMgr
