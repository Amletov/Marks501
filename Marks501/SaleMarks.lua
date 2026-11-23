local _, addon = ...
local saleMarks

function addon.InitializeSaleMarks()
    if type(Marks501DB) ~= "table" then
        Marks501DB = {}
    end
    if type(Marks501DB.saleMarks) ~= "table" then
        Marks501DB.saleMarks = {}
    end
    saleMarks = Marks501DB.saleMarks
end

local function GetBagItemGUID(bagID, slotID)
    if type(bagID) ~= "number" or bagID < Enum.BagIndex.Backpack or bagID > Enum.BagIndex.Bag_4
        or type(slotID) ~= "number" or slotID < 1 then
        return
    end

    local location = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    local exists = C_Item.DoesItemExist(location)
    if issecretvalue(exists) or not exists then
        return
    end

    local guid = C_Item.GetItemGUID(location)
    if not issecretvalue(guid) and type(guid) == "string" and guid ~= "" then
        return guid
    end
end

function addon.HasSaleMarks()
    return saleMarks ~= nil and next(saleMarks) ~= nil
end

function addon.ClearSaleMarks()
    if saleMarks then
        for guid in pairs(saleMarks) do
            saleMarks[guid] = nil
        end
    end
end

function addon.GetMarkedBagItemGUID(bagID, slotID)
    if not addon.HasSaleMarks() then
        return
    end
    local guid = GetBagItemGUID(bagID, slotID)
    if guid and saleMarks[guid] == true then
        return guid
    end
end

function addon.IsBagSlotMarked(bagID, slotID)
    return addon.GetMarkedBagItemGUID(bagID, slotID) ~= nil
end

function addon.ToggleBagSlotMark(bagID, slotID)
    if not saleMarks then
        return
    end
    local guid = GetBagItemGUID(bagID, slotID)
    if not guid then
        return
    end

    if saleMarks[guid] == true then
        saleMarks[guid] = nil
        return false
    end
    saleMarks[guid] = true
    return true
end
