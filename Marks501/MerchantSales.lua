local addonName, addon = ...
local pendingSale
local saleBlocked
local merchantOpen = false

-- Forever may expose the global even when the namespaced API is absent.
local combatLockdown = InCombatLockdown or (C_RestrictedActions and C_RestrictedActions.InCombatLockdown)

local function IsCombatLocked()
    if combatLockdown then
        return combatLockdown()
    end
    if UnitAffectingCombat then
        return UnitAffectingCombat("player")
    end
    return true
end

local hasSecretValues = hasanysecretvalues or function(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if issecretvalue(value) then
            return true
        end
    end
    return false
end

local function IsMerchantSellTabVisible()
    return MerchantFrame:IsVisible() and MerchantFrame.selectedTab == 1
        and MerchantSellAllJunkButton:IsVisible()
end

local function CanSellNow()
    return merchantOpen and IsMerchantSellTabVisible() and not IsCombatLocked()
        and not GetCursorInfo() and not SpellIsTargeting() and not InRepairMode()
end

local function IsBagExcluded(bagID)
    if bagID == Enum.BagIndex.Backpack then
        return C_Container.GetBackpackSellJunkDisabled()
    end
    return C_Container.GetBagSlotFlag(bagID, Enum.BagSlotFlags.ExcludeJunkSell)
end

local function GetSaleCandidate(bagID, slotID)
    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    -- The native action handles grays; never send a second sale for one.
    if issecretvalue(info) or not info then
        return
    end
    local quality, noValue, locked, count = info.quality, info.hasNoValue, info.isLocked, info.stackCount
    if hasSecretValues(quality, noValue, locked, count) or type(quality) ~= "number" or quality == Enum.ItemQuality.Poor
        or noValue ~= false or locked ~= false or type(count) ~= "number" or count < 1 then
        return
    end
    local guid = addon.GetMarkedBagItemGUID(bagID, slotID)
    if not guid then
        return
    end
    local refund = C_Container.GetContainerItemPurchaseInfo(bagID, slotID, false)
    if issecretvalue(refund) then
        return
    end
    if refund and hasSecretValues(refund.refundSeconds, refund.money, refund.itemCount, refund.currencyCount) then
        return
    end
    if refund and refund.refundSeconds and
        ((refund.money or 0) > 0 or (refund.itemCount or 0) > 0 or (refund.currencyCount or 0) > 0) then
        return
    end
    return guid, count
end

local function FindMarkedSales(firstOnly)
    if not addon.HasSaleMarks() then
        return
    end
    local items = {}
    for bagID = Enum.BagIndex.Backpack, Enum.BagIndex.Bag_4 do
        if not IsBagExcluded(bagID) then
            for slotID = 1, C_Container.GetContainerNumSlots(bagID) do
                local guid, count = GetSaleCandidate(bagID, slotID)
                if guid then
                    if firstOnly then
                        return true
                    end
                    items[#items + 1] = { bag = bagID, slot = slotID, guid = guid, count = count }
                end
            end
        end
    end
    if #items > 0 then
        return items
    end
end

local function RefreshSaleButton()
    -- Blizzard controls whether this button is shown. The enabled state also
    -- needs to account for our marked stacks, even if there is no native junk.
    if not IsMerchantSellTabVisible() or IsCombatLocked() then
        return
    end
    local enabled = C_MerchantFrame.GetNumJunkItems() > 0 or FindMarkedSales(true) == true
    MerchantSellAllJunkButton.Icon:SetDesaturated(not enabled)
    MerchantSellAllJunkButton:SetEnabled(enabled)
end

-- Keep Blizzard's popup and callback. Arm only the exact popup whose text we
-- updated, and capture the GUIDs and counts the user is about to confirm.
local function PrepareMarkedSale(data)
    if type(data) ~= "table" or data.callback ~= MerchantFrame_OnSellAllJunkButtonConfirmed then
        return
    end
    pendingSale = nil
    if type(data.text) ~= "string" or not CanSellNow() then
        return
    end
    local dialog = StaticPopup_FindVisible("GENERIC_CONFIRMATION", data)
    if not dialog then
        return
    end
    local items = FindMarkedSales(false)
    if items then
        dialog:GetTextFontString():SetText(data.text .. "\n\n" .. addon.L.sellMarked:format(#items))
        StaticPopup_ResizeShownDialogs()
        pendingSale = { dialog = dialog, data = data, items = items }
    end
end

local function SellConfirmedMarks()
    local sale = pendingSale
    pendingSale = nil
    if not sale or StaticPopup_FindVisible("GENERIC_CONFIRMATION", sale.data) ~= sale.dialog then
        return
    end
    saleBlocked = false
    for _, entry in ipairs(sale.items) do
        if not CanSellNow() then
            break
        end
        if not IsBagExcluded(entry.bag) and entry.slot <= C_Container.GetContainerNumSlots(entry.bag) then
            local guid, count = GetSaleCandidate(entry.bag, entry.slot)
            if guid == entry.guid and count == entry.count then
                -- Item use is protected in some contexts. Only try the normal
                -- vendor action here; stop if the client refuses it.
                local ok = pcall(C_Container.UseContainerItem, entry.bag, entry.slot)
                if not ok or saleBlocked then
                    break
                end
            end
        end
    end
end

function addon.ClearPendingMarkedSale()
    local sale = pendingSale
    pendingSale = nil
    if sale and StaticPopup_FindVisible("GENERIC_CONFIRMATION", sale.data) == sale.dialog then
        sale.dialog:GetTextFontString():SetText(sale.data.text)
        StaticPopup_ResizeShownDialogs()
    end
end

addon.RefreshMerchantSaleButton = function() end

local function InstallMerchantHooks()
    if addon.RefreshMerchantSaleButton == RefreshSaleButton then
        return
    end
    if MerchantFrame and MerchantSellAllJunkButton and MerchantFrame_Update
        and MerchantFrame_OnSellAllJunkButtonConfirmed and EventRegistry
        and StaticPopup_ShowCustomGenericConfirmation and StaticPopup_FindVisible and StaticPopup_ResizeShownDialogs then
        hooksecurefunc("MerchantFrame_Update", RefreshSaleButton)
        hooksecurefunc("StaticPopup_ShowCustomGenericConfirmation", PrepareMarkedSale)
        EventRegistry:RegisterCallback("MerchantFrame.SellAllJunkButtonConfirmed", SellConfirmedMarks, addon)
        addon.RefreshMerchantSaleButton = RefreshSaleButton
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, source, action)
    if event == "PLAYER_LOGIN" then
        InstallMerchantHooks()
    elseif event == "MERCHANT_SHOW" then
        merchantOpen = true
        InstallMerchantHooks()
        addon.RefreshMerchantSaleButton()
    elseif event == "MERCHANT_CLOSED" then
        merchantOpen = false
        pendingSale = nil
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if source == addonName and type(action) == "string" and action:find("UseContainerItem", 1, true) then
            saleBlocked = true
        end
    else
        addon.RefreshMerchantSaleButton()
    end
end)
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_CLOSED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("BAG_SLOT_FLAGS_UPDATED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
eventFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
