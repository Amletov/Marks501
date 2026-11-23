local function Item(guid, quality, marked)
    return { guid = guid, quality = quality, marked = marked, hasNoValue = false, isLocked = false, stackCount = 1 }
end

local function Launch(lateMerchantUI, useUnitCombatFallback)
    local events, callbacks, registrations, requests = {}, {}, {}, {}
    local merchant = { open = true, selectedTab = 1 }
    function merchant:IsVisible() return self.open end
    local button = { visible = true, Icon = {} }
    function button:IsVisible() return self.visible end
    function button:SetEnabled(enabled) self.enabled = enabled end
    function button.Icon:SetDesaturated(value) self.desaturated = value end

    local items = { [0] = {}, [4] = {} }
    local state = { junk = 0 }
    local env = setmetatable({
        GetLocale = function() return "ruRU" end,
        GetCursorInfo = function() return state.cursor end,
        SpellIsTargeting = function() return state.targeting end,
        InRepairMode = function() return state.repair end,
        issecretvalue = function() return false end,
        Enum = {
            BagIndex = { Backpack = 0, Bag_4 = 4 },
            BagSlotFlags = { ExcludeJunkSell = 64 },
            ItemQuality = { Poor = 0 },
        },
        C_RestrictedActions = {},
        InCombatLockdown = not useUnitCombatFallback and function() return state.combat end or nil,
        UnitAffectingCombat = function(unit)
            assert(unit == "player")
            return state.combat
        end,
        C_MerchantFrame = {
            IsSellAllJunkEnabled = function() return not state.disabled end,
            GetNumJunkItems = function() return state.junk end,
        },
        C_Container = {
            GetBackpackSellJunkDisabled = function() return state.excludeBackpack end,
            GetBagSlotFlag = function(bag, flag) return bag == 4 and flag == 64 and state.excludeBag end,
            GetContainerNumSlots = function(bag) return bag == 0 and 10 or (bag == 4 and 2 or 0) end,
            GetContainerItemInfo = function(bag, slot) return items[bag][slot] end,
            GetContainerItemPurchaseInfo = function(bag, slot) return items[bag][slot].refund end,
            UseContainerItem = function(bag, slot)
                requests[#requests + 1] = items[bag][slot].guid
                assert(requests[1] == "native", "the vanilla handler should have run")
                if state.closeAfterFirst then
                    events.handle(nil, "MERCHANT_CLOSED")
                end
                if state.blockAfterFirst then
                    events.handle(nil, "ADDON_ACTION_BLOCKED", "Marks501", "C_Container.UseContainerItem()")
                end
            end,
        },
        MerchantFrame = merchant,
        MerchantSellAllJunkButton = button,
        MerchantFrame_Update = function()
            button:SetEnabled(state.junk > 0)
            button.Icon:SetDesaturated(state.junk == 0)
        end,
        MerchantFrame_OnSellAllJunkButtonConfirmed = function()
            requests[#requests + 1] = "native"
            local callback = assert(callbacks["MerchantFrame.SellAllJunkButtonConfirmed"])
            callback()
        end,
        StaticPopup_ShowCustomGenericConfirmation = function(data)
            if not state.noPopup then
                local text = { value = data.text, SetText = function(self, value) self.value = value end }
                state.dialog = { data = data, text = text, GetTextFontString = function() return text end }
            end
        end,
        StaticPopup_FindVisible = function(kind, data)
            assert(kind == "GENERIC_CONFIRMATION")
            if state.dialog and state.dialog.data == data then
                return state.dialog
            end
        end,
        StaticPopup_ResizeShownDialogs = function() state.resized = true end,
        CreateFrame = function()
            return {
                RegisterEvent = function(_, name) registrations[name] = true end,
                SetScript = function(_, _, callback) events.handle = callback end,
            }
        end,
        EventRegistry = { RegisterCallback = function(_, name, callback) callbacks[name] = callback end },
    }, { __index = _G })
    env.hooksecurefunc = function(name, callback)
        local original = assert(env[name])
        env[name] = function(...)
            original(...)
            callback(...)
        end
    end
    local addon = {
        HasSaleMarks = function() return not state.noMarks end,
        GetMarkedBagItemGUID = function(bag, slot)
            local item = items[bag][slot]
            return item and item.marked and item.guid or nil
        end,
    }
    setfenv(assert(loadfile("Marks501/Locale.lua")), env)("Marks501", addon)
    setfenv(assert(loadfile("Marks501/MerchantSales.lua")), env)("Marks501", addon)
    local function Fire(event)
        assert(registrations[event])
        events.handle(nil, event)
    end
    local update = env.MerchantFrame_Update
    if lateMerchantUI then
        env.MerchantFrame_Update = nil
    end
    Fire("PLAYER_LOGIN")
    env.MerchantFrame_Update = env.MerchantFrame_Update or update
    if not lateMerchantUI then
        Fire("MERCHANT_SHOW")
    end

    local data = { text = "Vanilla prompt", callback = env.MerchantFrame_OnSellAllJunkButtonConfirmed }
    function state.Click()
        env.StaticPopup_ShowCustomGenericConfirmation(data)
    end
    function state.Confirm()
        data.callback()
        state.dialog = nil
    end
    function state.Cancel() state.dialog = nil end
    function state.Refresh() env.MerchantFrame_Update() end
    return state, items, requests, merchant, button, Fire, addon
end

local state, items, requests, _, button, _, addon = Launch()
items[0][1] = Item("common", 1, true)
items[0][2] = Item("gray", 0, true)
items[0][3] = Item("unmarked", 2, false)
items[0][4] = Item("no-price", 2, true)
items[0][4].hasNoValue = true
items[0][5] = Item("locked", 2, true)
items[0][5].isLocked = true
items[0][6] = Item("refundable", 2, true)
items[0][6].refund = { refundSeconds = 123, currencyCount = 1 }
items[4][1] = Item("excluded", 2, true)
state.excludeBag = true
addon.RefreshMerchantSaleButton()
assert(button.enabled and not button.Icon.desaturated)
state.Click()
assert(#requests == 0 and state.resized)
assert(state.dialog.text.value:find("помеченные стопки: 1", 1, true))
state.Confirm()
assert(table.concat(requests, ",") == "native,common")
items[0][1].marked = false
addon.RefreshMerchantSaleButton()
assert(not button.enabled and button.Icon.desaturated)
state.junk = 1
state.Refresh()
assert(button.enabled and not button.Icon.desaturated)
print("ok - marked-only button state, localized warning and native-confirmed sales")

local opened, markedItems, openedRequests, frame, sell, Fire = Launch(true)
markedItems[0][1] = Item("no-native-junk", 1, true)
opened.disabled = true -- The native feature query must not gate a button already shown by Blizzard.
Fire("MERCHANT_SHOW")
assert(sell.enabled and not sell.Icon.desaturated)
opened.Refresh() -- Blizzard disables its button again when counting zero greys.
assert(sell.enabled and not sell.Icon.desaturated)
sell:SetEnabled(false)
Fire("BAG_UPDATE_DELAYED")
assert(sell.enabled and #openedRequests == 0)
opened.Click()
opened.Confirm()
assert(table.concat(openedRequests, ",") == "native,no-native-junk")
frame.selectedTab = 2
sell:SetEnabled(false)
Fire("BAG_UPDATE_DELAYED")
assert(not sell.enabled)
frame.selectedTab, sell.visible = 1, false
Fire("BAG_UPDATE_DELAYED")
assert(not sell.enabled)
print("ok - marked-only button recovers on merchant open and refresh without overriding native visibility")

local inCombat, combatItems, combatRequests, _, combatButton, FireCombat = Launch(false, true)
combatItems[0][1] = Item("marked-without-lockdown-api", 1, true)
inCombat.combat = true
inCombat.Refresh()
assert(not combatButton.enabled)
inCombat.Click()
inCombat.Confirm()
assert(table.concat(combatRequests, ",") == "native")
inCombat.combat = false
FireCombat("PLAYER_REGEN_ENABLED")
assert(combatButton.enabled and not combatButton.Icon.desaturated)
print("ok - merchant works when the optional combat-lockdown and secret-value helpers are absent")

state, items, requests = Launch()
items[0][1] = Item("changed-guid", 1, true)
items[0][2] = Item("changed-count", 1, true)
items[0][3] = Item("unmarked-before-confirm", 1, true)
items[0][4] = Item("stays", 1, true)
state.Click()
items[0][1] = Item("another-marked-item", 1, true)
items[0][2].stackCount = 2
items[0][3].marked = false
items[0][5] = Item("newly-marked", 1, true)
state.Confirm()
assert(table.concat(requests, ",") == "native,stays")
print("ok - no sales outside the confirmed GUID/slot/count snapshot")

for _, interruption in ipairs({ "cancelled", "closed", "buyback", "bag-excluded", "cursor", "combat", "targeting", "repair" }) do
    local state, items, requests, merchant, _, Fire = Launch()
    items[0][1] = Item("marked", 1, true)
    state.Click()
    if interruption == "cancelled" then
        state.Cancel()
        assert(#requests == 0)
    elseif interruption == "closed" then
        Fire("MERCHANT_CLOSED")
    elseif interruption == "buyback" then
        merchant.selectedTab = 2
    elseif interruption == "bag-excluded" then
        state.excludeBackpack = true
    else
        state[interruption] = true
    end
    -- Even an unrelated confirmed event must not sell marks from a stale popup.
    state.Confirm()
    assert(table.concat(requests, ",") == "native", interruption)
end
print("ok - cancelled, closed and unsuitable merchant contexts do not sell marks")

state, items, requests = Launch()
items[0][1] = Item("first", 1, true)
items[0][2] = Item("second", 1, true)
state.noPopup = true
state.Click()
state.Confirm()
assert(table.concat(requests, ",") == "native")
state.noPopup = false
state.closeAfterFirst = true
state.Click()
state.Confirm()
assert(table.concat(requests, ",") == "native,native,first")
print("ok - a missing popup or lost merchant interaction stops add-on sales")

state, items, requests = Launch()
items[0][1] = Item("first", 1, true)
items[0][2] = Item("second", 1, true)
state.blockAfterFirst = true
state.Click()
state.Confirm()
assert(table.concat(requests, ",") == "native,first")
print("ok - a client protection error stops the batch without retrying")

local cleared, clearItems, clearRequests, _, _, _, clearAddon = Launch()
clearItems[0][1] = Item("marked-again", 1, true)
cleared.Click()
assert(cleared.dialog.text.value ~= "Vanilla prompt")
clearItems[0][1].marked = false
clearAddon.ClearPendingMarkedSale()
assert(cleared.dialog.text.value == "Vanilla prompt")
clearItems[0][1].marked = true
cleared.Confirm()
assert(table.concat(clearRequests, ",") == "native")
print("ok - clearing marks cancels the existing marked-sale snapshot without changing native junk sales")
