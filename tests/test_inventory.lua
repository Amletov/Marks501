local POOR, COMMON = 0, 1

local function newScanner(bags, itemData)
    local lookups = {}
    local env = setmetatable({
        Enum = {
            BagIndex = { Backpack = 0, Bag_4 = 4 },
            ItemQuality = { Poor = POOR, Common = COMMON },
        },
        C_Container = {
            GetContainerNumSlots = function(bag)
                assert(bag >= 0 and bag <= 4, "unexpected bag: " .. bag)
                return bags[bag] and bags[bag].size or 0
            end,
            GetContainerItemInfo = function(bag, slot)
                assert(bags[bag] and slot >= 1 and slot <= bags[bag].size, "unexpected slot")
                return bags[bag][slot]
            end,
        },
        C_Item = {
            GetItemInfo = function(item)
                lookups[#lookups + 1] = item
                local data = itemData[item]
                if data then
                    return "name", "link", data.quality, 1, 1, "type", "subtype", 20, "", 1, data.price
                end
            end,
        },
    }, { __index = _G })

    local addon = {}
    setfenv(assert(loadfile("Marks501/Inventory.lua")), env)("Marks501", addon)
    return addon.ScanInventory, lookups
end

local function assertSummary(summary, grayCount, copper, missingPriceCount, unknownSlots)
    local expected = {
        grayItemCount = grayCount,
        knownValueCopper = copper,
        unknownPriceItemCount = missingPriceCount,
        unknownQualitySlots = unknownSlots,
    }
    for field, value in pairs(expected) do
        assert(summary[field] == value, ("%s: expected %s, got %s"):format(field, value, tostring(summary[field])))
    end
end

local cases = {
    { "empty and unequipped bags", function()
        local scan, lookups = newScanner({ [0] = { size = 4 } }, {})
        assertSummary(scan(), 0, 0, 0, 0)
        assert(#lookups == 0)
    end },
    { "same item ID in separate stacks, backpack and last equipped bag", function()
        local scan = newScanner({
            [0] = { size = 2, [2] = { itemID = 10, hyperlink = "item:10", stackCount = 2, quality = POOR } },
            [4] = { size = 1, { itemID = 10, hyperlink = "item:10", stackCount = 3, quality = POOR } },
            [5] = { size = 1, { itemID = 10, hyperlink = "item:10", stackCount = 8, quality = POOR } },
        }, { ["item:10"] = { quality = POOR, price = 7 } })
        assertSummary(scan(), 5, 35, 0, 0)
    end },
    { "known non-gray items do not request item data", function()
        local scan, lookups = newScanner({
            [1] = { size = 1, { itemID = 11, stackCount = 10, quality = COMMON } },
        }, {})
        assertSummary(scan(), 0, 0, 0, 0)
        assert(#lookups == 0)
    end },
    { "zero price is known; missing price counts units", function()
        local scan = newScanner({
            [2] = { size = 2,
                { itemID = 12, stackCount = 2, quality = POOR },
                { itemID = 13, stackCount = 3, quality = POOR },
            },
        }, { [12] = { quality = POOR, price = 0 } })
        assertSummary(scan(), 5, 0, 3, 0)
    end },
    { "cached quality fallback and unresolved quality count slots", function()
        local scan = newScanner({
            [3] = { size = 3,
                { itemID = 14, stackCount = 2 },
                { itemID = 15, stackCount = 6 },
                { itemID = 16, stackCount = 9 },
            },
        }, {
            [14] = { quality = POOR, price = 5 },
            [15] = { quality = COMMON, price = 8 },
        })
        assertSummary(scan(), 2, 10, 0, 1)
    end },
    { "prefers link and falls back to item ID for empty link", function()
        local scan, lookups = newScanner({
            [4] = { size = 2,
                { hyperlink = "item:17:variant", itemID = 17, stackCount = 1, quality = POOR },
                { hyperlink = "", itemID = 17, stackCount = 1, quality = POOR },
            },
        }, {
            ["item:17:variant"] = { quality = POOR, price = 7 },
            [17] = { quality = POOR, price = 5 },
        })
        assertSummary(scan(), 2, 12, 0, 0)
        assert(lookups[1] == "item:17:variant" and lookups[2] == 17 and #lookups == 2)
    end },
    { "each scan is fresh after data arrives or a slot is emptied", function()
        local bags = { [0] = { size = 1, { itemID = 18, stackCount = 4, quality = POOR } } }
        local itemData = {}
        local scan = newScanner(bags, itemData)
        local first = scan()
        assertSummary(first, 4, 0, 4, 0)
        itemData[18] = { quality = POOR, price = 3 }
        assertSummary(scan(), 4, 12, 0, 0)
        bags[0][1] = nil
        assertSummary(scan(), 0, 0, 0, 0)
        assertSummary(first, 4, 0, 4, 0)
    end },
}

for _, case in ipairs(cases) do
    case[2]()
    print("ok - " .. case[1])
end
print(("%d inventory tests passed"):format(#cases))
