local _, addon = ...

local function AddSlotToSummary(info, summary)
    local quality = info.quality
    local poorQuality = Enum.ItemQuality.Poor
    if quality ~= nil and quality ~= poorQuality then
        return
    end

    local unitPrice
    local item = info.hyperlink
    if not item or item == "" then
        item = info.itemID
    end
    if item then
        local _, _, itemQuality, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(item)
        quality = quality or itemQuality
        unitPrice = sellPrice
    end

    if quality == nil then
        summary.unknownQualitySlots = summary.unknownQualitySlots + 1
    elseif quality == poorQuality then
        summary.grayItemCount = summary.grayItemCount + info.stackCount
        if unitPrice == nil then
            summary.unknownPriceItemCount = summary.unknownPriceItemCount + info.stackCount
        else
            summary.knownValueCopper = summary.knownValueCopper + unitPrice * info.stackCount
        end
    end
end

function addon.ScanInventory()
    local summary = {
        grayItemCount = 0,
        knownValueCopper = 0,
        unknownPriceItemCount = 0,
        unknownQualitySlots = 0,
    }

    for bagIndex = Enum.BagIndex.Backpack, Enum.BagIndex.Bag_4 do
        for slotIndex = 1, C_Container.GetContainerNumSlots(bagIndex) do
            local info = C_Container.GetContainerItemInfo(bagIndex, slotIndex)
            if info then
                AddSlotToSummary(info, summary)
            end
        end
    end

    return summary
end
