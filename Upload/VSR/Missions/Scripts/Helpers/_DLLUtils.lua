local DLLUtils = {}

-- Returns true if h is a recycler or recycler vehicle, false
-- if h is invalid, or not a recycler
function DLLUtils:IsRecycler(h)
    local ObjClass = GetClassLabel(h)
    if (ObjClass == nil) then
        return false
    end

    return (ObjClass == "CLASS_RECYCLERVEHICLE") or (ObjClass == "CLASS_RECYCLER") or
        (ObjClass == "CLASS_RECYCLERVEHICLEH")
end

-- Sanity wrapper for GetVarItemStr. Reads the specified svar, and
-- verifies it's present in the specified list. If not found in
-- there, returns NULL.
function DLLUtils:GetCheckedNetworkSvar(svar, listType)
    local svarStr = "network.session.svar" .. svar
    local pContents = GetVarItemStr(svarStr)

    -- Error finding? Bail, asap
    if (pContents == nil or pContents == "") then
        return nil
    end

    local count = GetNetworkListCount(listType)

    for i = 0, count do
        local pItem = GetNetworkListItem(listType, i)
        if (pItem ~= nil) then
            if (pContents == pItem) then
                -- Got a good match. Return it
                return pContents
            end
        end
    end

    -- No match found. Report error
    return nil
end

return DLLUtils