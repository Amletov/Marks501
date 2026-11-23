local _, addon = ...

local function PrintInventorySummary()
    local summary = addon.ScanInventory()
    local incomplete = summary.unknownPriceItemCount > 0 or summary.unknownQualitySlots > 0
    local valueLabel = incomplete and "известная стоимость" or "стоимость"
    local message = ("Marks501: серых предметов: %d; %s: %d мед."):format(
        summary.grayItemCount, valueLabel, summary.knownValueCopper
    )

    if summary.unknownPriceItemCount > 0 then
        message = message .. (" Без цены: %d шт."):format(summary.unknownPriceItemCount)
    end
    if summary.unknownQualitySlots > 0 then
        message = message .. (" Слотов с неизвестным качеством: %d."):format(summary.unknownQualitySlots)
    end

    print(message)
end

SLASH_MARKS5011 = "/bm"
SlashCmdList.MARKS501 = function(message)
    if message:match("^%s*scan%s*$") then
        PrintInventorySummary()
    else
        print("Marks501: /bm scan")
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        PrintInventorySummary()
    end
end)
eventFrame:RegisterEvent("MERCHANT_SHOW")
