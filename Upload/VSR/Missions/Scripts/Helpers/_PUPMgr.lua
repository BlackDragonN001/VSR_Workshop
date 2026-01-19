local MAX_POWERUPS = 100

local PUPMgr = {
    PUPCount = 0
}

function PUPMgr:Start()
    local pathNames = GetAiPaths()
    local pathCount = #pathNames
    local length

    for i = 1, pathCount do
        if (self.PUPCount < MAX_POWERUPS) then
            local Label = pathNames[i]

            if (string.sub(Label, 1, 4) == "king") then
                break -- king of the hill not implemented yet
            end

            if (string.sub(Label, 1, 9) == "edge_path") then
                break -- this is not a powerup
            end

            if (string.sub(Label, 1, 9) == "spawntank8") then
                break
            end

            if (string.sub(Label, 1, 11) == "spawnrocket8") then
                break
            end

            if (string.sub(Label, 1, 5) == "base1") then
                break -- Inserted for CTF
            end

            if (string.sub(Label, 1, 5) == "base2") then
                break -- Inserted for CTF
            end

            if (string.sub(Label, 1, 4) == "path") then
                break -- Inserted to debug
            end

            if (self.PUPCount < MAX_POWERUPS) then

            end
        end
    end
end

function PUPMgr:Update()

end

function PUPMgr:Load()

end

function PUPMgr:Save()

end

return PUPMgr
