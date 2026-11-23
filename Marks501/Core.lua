local _, addon = ...
local L = addon.L

local function PrintInventorySummary()
    local summary = addon.ScanInventory()
    local incomplete = summary.unknownPriceItemCount > 0 or summary.unknownQualitySlots > 0
    local template = incomplete and L.partialSummary or L.summary
    local message = template:format(summary.grayItemCount, summary.knownValueCopper)

    if summary.unknownPriceItemCount > 0 then
        message = message .. " " .. L.unknownPrice:format(summary.unknownPriceItemCount)
    end
    if summary.unknownQualitySlots > 0 then
        message = message .. " " .. L.unknownQuality:format(summary.unknownQualitySlots)
    end

    print("Marks501: " .. message)
end

SLASH_MARKS5011 = "/bm"
SlashCmdList.MARKS501 = function(message)
    if message:match("^%s*clear%s*$") then
        addon.ClearSaleMarks()
        addon.ClearPendingMarkedSale()
        addon.RefreshSaleMarkUI()
        print("Marks501: " .. L.marksCleared)
    else
        print("Marks501: /bm clear")
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        PrintInventorySummary()
    end
end)
eventFrame:RegisterEvent("MERCHANT_SHOW")
