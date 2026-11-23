local messages, events, scripts = {}, {}, {}
local scanCount = 0
local refreshCount, pendingClearCount = 0, 0
local summary = { grayItemCount = 5, knownValueCopper = 35, unknownPriceItemCount = 0, unknownQualitySlots = 0 }
local addon = {
    ScanInventory = function()
        scanCount = scanCount + 1
        return summary
    end,
    ClearPendingMarkedSale = function() pendingClearCount = pendingClearCount + 1 end,
    RefreshSaleMarkUI = function() refreshCount = refreshCount + 1 end,
}
local env = setmetatable({
    SlashCmdList = {},
    Marks501DB = { saleMarks = { visible = true, absent = true }, otherSetting = "keep" },
    GetLocale = function() return "ruRU" end,
    CreateFrame = function(kind)
        assert(kind == "Frame")
        return {
            RegisterEvent = function(_, event)
                events[#events + 1] = event
            end,
            SetScript = function(_, script, handler)
                scripts[script] = handler
            end,
        }
    end,
    print = function(message)
        messages[#messages + 1] = message
    end,
}, { __index = _G })

setfenv(assert(loadfile("Marks501/Locale.lua")), env)("Marks501", addon)
setfenv(assert(loadfile("Marks501/SaleMarks.lua")), env)("Marks501", addon)
setfenv(assert(loadfile("Marks501/Core.lua")), env)("Marks501", addon)
addon.InitializeSaleMarks()

assert(env.SLASH_MARKS5011 == "/bm")
env.SlashCmdList.MARKS501(" scan ")
assert(scanCount == 0 and messages[1] == "Marks501: /bm clear")
assert(addon.HasSaleMarks() and refreshCount == 0 and pendingClearCount == 0)
env.SlashCmdList.MARKS501(" clear ")
assert(scanCount == 0 and messages[2] == "Marks501: Все метки «на продажу» сняты.")
assert(not addon.HasSaleMarks() and next(env.Marks501DB.saleMarks) == nil)
assert(env.Marks501DB.otherSetting == "keep" and refreshCount == 1 and pendingClearCount == 1)
env.SlashCmdList.MARKS501("clear")
assert(not addon.HasSaleMarks() and messages[3] == messages[2])
print("ok - slash command clears all marks without a scan or changes to other settings")

assert(#events == 1 and events[1] == "MERCHANT_SHOW")
scripts.OnEvent(nil, "MERCHANT_UPDATE")
assert(scanCount == 0 and #messages == 3)
scripts.OnEvent(nil, "MERCHANT_SHOW")
scripts.OnEvent(nil, "MERCHANT_SHOW")
assert(scanCount == 2 and #messages == 5)
assert(messages[4] == "Marks501: серых предметов: 5; стоимость: 35 мед." and messages[5] == messages[4])
print("ok - each merchant opening prints one summary")

summary = { grayItemCount = 5, knownValueCopper = 35, unknownPriceItemCount = 2, unknownQualitySlots = 1 }
scripts.OnEvent(nil, "MERCHANT_SHOW")
assert(scanCount == 3 and #messages == 6)
assert(messages[6] == "Marks501: серых предметов: 5; известная стоимость: 35 мед. Без цены: 2 шт. Слотов с неизвестным качеством: 1.")
print("ok - incomplete summary shows both reasons")
print("3 core tests passed")
