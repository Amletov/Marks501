local function Load(locale)
    local addon = {}
    local env = setmetatable({ GetLocale = function() return locale end }, { __index = _G })
    setfenv(assert(loadfile("Marks501/Locale.lua")), env)("Marks501", addon)
    return addon.L
end

local english = Load("enUS")
assert(Load("enGB").toggleSaleMark == english.toggleSaleMark)
assert(Load("xxXX").sellMarked == english.sellMarked)
assert(Load("esMX").sellMarked == Load("esES").sellMarked)
for _, locale in ipairs({ "ruRU", "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }) do
    local L = Load(locale)
    assert(L.toggleSaleMark ~= english.toggleSaleMark)
    for key in pairs(english) do
        assert(type(L[key]) == "string" and L[key] ~= "", locale .. ": " .. key)
    end
    assert(L.summary:format(123, 456):find("123") and L.partialSummary:format(123, 456):find("456"))
    assert(L.sellMarked:format(123):find("123"))
end
print("ok - client locale selects complete translations with English fallback")
