local SECRET = {}

local function NewButton(bag, slot)
    return {
        bag = bag,
        slot = slot,
        visible = true,
        GetSlotAndBagID = function(self) return self.slot, self.bag end,
        IsVisible = function(self) return self.visible end,
        CreateTexture = function(self, _, layer)
            assert(not self.badge, "a pooled button should reuse its badge")
            assert(layer == "OVERLAY")
            self.badge = {
                SetPoint = function(_, point, relativeTo, relativePoint, x, y)
                    assert(point == "BOTTOMLEFT" and relativeTo == self and relativePoint == point)
                    assert(x == 0 and y == 0)
                end,
                SetSize = function(_, width, height) assert(width == 24 and height == 24) end,
                SetTexture = function(badge, path) badge.texture = path end,
                SetShown = function(badge, shown) badge.shown = shown end,
            }
            return self.badge
        end,
    }
end

local function NewContainer(visible, ...)
    return {
        visible = visible,
        buttons = { ... },
        IsVisible = function(self) return self.visible end,
        EnumerateValidItems = function(self) return ipairs(self.buttons) end,
        HookScript = function(self, name, callback)
            assert(name == "OnShow")
            self.OnShow = callback
        end,
        UpdateItems = function() end,
        UpdateItemSlots = function() end,
    }
end

local function Launch(savedDB)
    local first, second = NewButton(0, 1), NewButton(0, 2)
    local combined, otherBag, bank = NewButton(0, 1), NewButton(4, 1), NewButton(6, 1)
    local separateFrame = NewContainer(true, first, second)
    local combinedFrame = NewContainer(false, combined, otherBag, bank)
    local bagItems = {
        [0] = { { guid = "a", itemID = 123, stackCount = 5 }, { guid = "b", itemID = 123, stackCount = 5 } },
        [4] = {},
        [6] = { { guid = "bank" } },
    }
    local controls = {}
    local function GetItem(location)
        local bag = bagItems[location.bag]
        return bag and bag[location.slot]
    end
    local env = setmetatable({
        Marks501DB = savedDB,
        ContainerFrameContainer = { ContainerFrames = { separateFrame } },
        ContainerFrameCombinedBags = combinedFrame,
        Enum = { BagIndex = { Backpack = 0, Bag_4 = 4 } },
        ItemLocation = {
            CreateFromBagAndSlot = function(_, bag, slot)
                assert(bag >= 0 and bag <= 4, "must not inspect out-of-scope bags")
                return { bag = bag, slot = slot }
            end,
        },
        C_Item = {
            DoesItemExist = function(location) return GetItem(location) ~= nil end,
            GetItemGUID = function(location) return assert(GetItem(location)).guid end,
        },
        issecretvalue = function(value) return value == SECRET end,
        GetMouseFoci = function() return controls.mouse or {} end,
        GetLocale = function() return "enUS" end,
        GetCurrentKeyBoardFocus = function() return controls.keyboard end,
        CursorHasItem = function() return controls.dragging end,
        CreateFrame = function(kind)
            assert(kind == "Frame")
            return {
                RegisterEvent = function(_, name) assert(name == "PLAYER_LOGIN") end,
                SetScript = function(_, script, handler)
                    assert(script == "OnEvent")
                    controls.login = handler
                end,
            }
        end,
        hooksecurefunc = function(object, key, callback)
            local original = assert(object[key])
            object[key] = function(...)
                original(...)
                callback(...)
            end
        end,
    }, { __index = _G })
    local addon = { RefreshMerchantSaleButton = function()
        controls.saleButtonRefreshes = (controls.saleButtonRefreshes or 0) + 1
    end }
    setfenv(assert(loadfile("Marks501/Locale.lua")), env)("Marks501", addon)
    setfenv(assert(loadfile("Marks501/SaleMarks.lua")), env)("Marks501", addon)
    setfenv(assert(loadfile("Marks501/BagMarks.lua")), env)("Marks501", addon)
    controls.login()
    return env, controls, bagItems, separateFrame, combinedFrame, addon
end

local function HasBadge(button)
    return button.badge and button.badge.shown
end

local function Press(env, controls, ...)
    controls.mouse = { ... }
    env.Marks501_ToggleHoveredSaleMark()
end

local env, controls, items, separate, combined = Launch()
local first, second = unpack(separate.buttons)
local combinedFirst, otherBag, bank = unpack(combined.buttons)
local child = { GetParent = function() return first end }
Press(env, controls, child)
assert(env.Marks501DB.saleMarks.a and not env.Marks501DB.saleMarks.b)
assert(HasBadge(first) and first.badge.texture == "Interface\\AddOns\\Marks501\\Art\\SalePouch.tga")
assert(not HasBadge(second))
Press(env, controls, child)
assert(next(env.Marks501DB.saleMarks) == nil and not HasBadge(first))
Press(env, controls, first)
assert(HasBadge(first))
print("ok - native action toggles a single GUID and reuses a passive badge")

local a = items[0][1]
items[0][1], items[0][2] = items[0][2], a
separate:UpdateItems()
assert(not HasBadge(first) and HasBadge(second))

a.stackCount = 2
items[4][1] = { guid = "split", itemID = 123, stackCount = 3 }
separate:UpdateItems()
assert(HasBadge(second))
separate.visible, combined.visible = false, true
combined:OnShow()
assert(not HasBadge(combinedFirst) and not HasBadge(otherBag))

a.stackCount = 5
items[0][2], items[4][1] = nil, a
combined:UpdateItems()
assert(HasBadge(otherBag) and not HasBadge(combinedFirst))
otherBag.slot = 2
combined:UpdateItemSlots()
assert(not HasBadge(otherBag))
otherBag.slot = 1
combined:UpdateItemSlots()
assert(HasBadge(otherBag))
print("ok - badges follow the surviving GUID through moves, stack changes and button reuse")

Press(env, controls)
Press(env, controls, {}, otherBag)
Press(env, controls, bank)
Press(env, controls, second)
controls.keyboard = {}
Press(env, controls, otherBag)
controls.keyboard, controls.dragging = nil, true
Press(env, controls, otherBag)
controls.dragging = nil
otherBag.visible = false
Press(env, controls, otherBag)
otherBag.visible = true
assert(HasBadge(otherBag) and env.Marks501DB.saleMarks.a and not env.Marks501DB.saleMarks.bank)

-- An empty slot and a new item with a missing or secret GUID must not get a mark.
items[4][1] = nil
combined:UpdateItems()
Press(env, controls, otherBag)
assert(not HasBadge(otherBag))
items[4][1] = { itemID = 123 }
Press(env, controls, otherBag)
items[4][1].guid = SECRET
Press(env, controls, otherBag)
assert(not HasBadge(otherBag) and next(env.Marks501DB.saleMarks) == "a")
assert(next(env.Marks501DB.saleMarks, "a") == nil)
print("ok - unrelated, hidden, unavailable and out-of-scope targets are ignored")

local savedDB = { saleMarks = { a = true }, otherSetting = "keep" }
local reloaded, newControls, _, reloadedFrame = Launch(savedDB)
assert(HasBadge(reloadedFrame.buttons[1]) and not HasBadge(reloadedFrame.buttons[2]))
assert(reloaded.Marks501DB.otherSetting == "keep")
Press(reloaded, newControls, reloadedFrame.buttons[1])
assert(not HasBadge(reloadedFrame.buttons[1]) and savedDB.saleMarks.a == nil)
local _, _, _, otherCharacter = Launch()
assert(not HasBadge(otherCharacter.buttons[1]))
print("ok - saved marks are restored without modifying unrelated settings")

local merged, mergeControls, mergeItems, mergeFrame = Launch()
Press(merged, mergeControls, mergeFrame.buttons[1])
mergeItems[0][1] = nil
mergeItems[0][2].stackCount = 10
mergeFrame:UpdateItems()
assert(not HasBadge(mergeFrame.buttons[1]) and not HasBadge(mergeFrame.buttons[2]))
assert(not merged.Marks501DB.saleMarks.b)
print("ok - merging into an unmarked GUID does not inherit a mark")

local saved = { saleMarks = { a = true, b = true, absent = true } }
local _, clearControls, _, clearFrame, clearCombined, clearAddon = Launch(saved)
assert(HasBadge(clearFrame.buttons[1]) and HasBadge(clearFrame.buttons[2]))
clearAddon.ClearSaleMarks()
clearAddon.RefreshSaleMarkUI()
assert(next(saved.saleMarks) == nil and clearControls.saleButtonRefreshes == 1)
assert(not HasBadge(clearFrame.buttons[1]) and not HasBadge(clearFrame.buttons[2]))
clearCombined.visible = true
clearCombined:OnShow()
assert(not HasBadge(clearCombined.buttons[1]))
print("ok - clearing all marks immediately removes badges and refreshes the vendor button")
print("6 bag mark tests passed")
