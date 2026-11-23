local messages, events, scripts = {}, {}, {}
local scanCount = 0
local summary = { grayItemCount = 5, knownValueCopper = 35, unknownPriceItemCount = 0, unknownQualitySlots = 0 }
local addon = {
    ScanInventory = function()
        scanCount = scanCount + 1
        return summary
    end,
}
local env = setmetatable({
    SlashCmdList = {},
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

setfenv(assert(loadfile("Marks501/Core.lua")), env)("Marks501", addon)

assert(env.SLASH_MARKS5011 == "/bm")
env.SlashCmdList.MARKS501(" scan ")
assert(scanCount == 1 and #messages == 1)
assert(messages[1] == "Marks501: серых предметов: 5; стоимость: 35 мед.")
env.SlashCmdList.MARKS501("unknown")
assert(scanCount == 1 and messages[2] == "Marks501: /bm scan")
print("ok - slash command scans or prints usage")

assert(#events == 1 and events[1] == "MERCHANT_SHOW")
scripts.OnEvent(nil, "MERCHANT_UPDATE")
assert(scanCount == 1 and #messages == 2)
scripts.OnEvent(nil, "MERCHANT_SHOW")
scripts.OnEvent(nil, "MERCHANT_SHOW")
assert(scanCount == 3 and #messages == 4)
assert(messages[3] == messages[1] and messages[4] == messages[1])
print("ok - each merchant opening prints one summary")

summary = { grayItemCount = 5, knownValueCopper = 35, unknownPriceItemCount = 2, unknownQualitySlots = 1 }
env.SlashCmdList.MARKS501("scan")
assert(scanCount == 4 and #messages == 5)
assert(messages[5] == "Marks501: серых предметов: 5; известная стоимость: 35 мед. Без цены: 2 шт. Слотов с неизвестным качеством: 1.")
print("ok - incomplete summary shows both reasons")
print("3 core tests passed")
