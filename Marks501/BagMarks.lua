local _, addon = ...
local bagFrames = {}
local badges = {}
local saleBadgeTexture = "Interface\\AddOns\\Marks501\\Art\\SalePouch.tga"

BINDING_HEADER_MARKS501 = "Marks501"
BINDING_NAME_MARKS501_TOGGLE_SALE_MARK = addon.L.toggleSaleMark

local function RefreshButtonMark(button)
    local slotID, bagID = button:GetSlotAndBagID()
    local marked = addon.IsBagSlotMarked(bagID, slotID)
    local badge = badges[button]
    if marked and not badge then
        badge = button:CreateTexture(nil, "OVERLAY", nil, 6)
        badge:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        badge:SetSize(24, 24)
        badge:SetTexture(saleBadgeTexture)
        badges[button] = badge
    end
    if badge then
        badge:SetShown(marked)
    end
end

local function RefreshBagMarks(container)
    if container:IsVisible() then
        for _, button in container:EnumerateValidItems() do
            if button then
                RefreshButtonMark(button)
            end
        end
    end
end

function addon.RefreshSaleMarkUI()
    for _, container in ipairs(bagFrames) do
        RefreshBagMarks(container)
    end
    addon.RefreshMerchantSaleButton()
end

local function GetHoveredBagButton()
    -- Do not reach through another window to a bag button underneath it.
    local region = GetMouseFoci()[1]
    if not region then
        return
    end
    local hovered = {}
    while region do
        hovered[region] = true
        region = region.GetParent and region:GetParent()
    end

    for _, container in ipairs(bagFrames) do
        if container:IsVisible() then
            for _, button in container:EnumerateValidItems() do
                if button and hovered[button] and button:IsVisible() then
                    return button
                end
            end
        end
    end
end

function Marks501_ToggleHoveredSaleMark()
    if GetCurrentKeyBoardFocus() or CursorHasItem() then
        return
    end
    local button = GetHoveredBagButton()
    if not button then
        return
    end

    local slotID, bagID = button:GetSlotAndBagID()
    if addon.ToggleBagSlotMark(bagID, slotID) ~= nil then
        addon.RefreshSaleMarkUI()
    end
end

local function WatchBagFrame(container)
    bagFrames[#bagFrames + 1] = container
    container:HookScript("OnShow", RefreshBagMarks)
    -- Bag buttons are pooled. Refresh both when their slot changes and when
    -- Blizzard updates the item shown in an existing slot.
    hooksecurefunc(container, "UpdateItemSlots", RefreshBagMarks)
    hooksecurefunc(container, "UpdateItems", RefreshBagMarks)
    RefreshBagMarks(container)
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function()
    addon.InitializeSaleMarks()
    if ContainerFrameContainer and ContainerFrameContainer.ContainerFrames then
        for _, container in pairs(ContainerFrameContainer.ContainerFrames) do
            WatchBagFrame(container)
        end
    end
    if ContainerFrameCombinedBags then
        WatchBagFrame(ContainerFrameCombinedBags)
    end
end)
eventFrame:RegisterEvent("PLAYER_LOGIN")
