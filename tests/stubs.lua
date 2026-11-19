-- Fake WoW API for tests. install() sets globals, restore() puts them back.
local M = {}
local saved = {}

function M.install(globals)
    for k, v in pairs(globals) do
        if saved[k] == nil then saved[k] = { old = _G[k] } end
        _G[k] = v
    end
end

function M.restore()
    for k, s in pairs(saved) do _G[k] = s.old end
    saved = {}
end

-- The real shipped AceDB-3.0 (with LibStub and CallbackHandler) on a fake client, as a fresh copy each
-- call. opts.forever: WoW Forever (regional unique names: the character key is "Name Surname").
-- Returns the db and the LibStub it was loaded into; _G.LibStub and the globals are put back.
function M.loadAceDB(saved, defaults, opts)
    opts = opts or {}
    local forever = opts.forever
    local rule = { RPRuleset = 1, PvPRuleset = 2, HardcoreRuleset = 3 }
    M.install({
        UnitName = function() return opts.name or "Me" end,
        UnitNameUnmodified = function()
            if forever then return opts.name or "Me", opts.surname or "Smith" end
            return opts.name or "Me"
        end,
        GetRealmName = function() return opts.realm or "Realm" end,
        UnitClass = function() return "Mage", "MAGE" end,
        UnitRace = function() return "Human", "Human" end,
        UnitFactionGroup = function() return "Alliance" end,
        GetLocale = function() return "enUS" end,
        GetCurrentRegion = function() return 1 end,
        GetCurrentRegionName = function() return "US" end,
        strlenutf8 = function(s) return #s end,
        RegionalUniqueNamesEnabled = function() return forever and true or false end,
        C_GameRules = { IsGameRuleActive = function() return false end },
        Enum = { GameRule = rule },
        CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end,
    })
    _G.KeepThatDB = saved
    local old = _G.LibStub
    _G.LibStub = nil
    for _, f in ipairs({ "LibStub/LibStub.lua", "CallbackHandler-1.0/CallbackHandler-1.0.lua", "AceDB-3.0/AceDB-3.0.lua" }) do
        assert(loadfile("KeepThat/Libs/" .. f))("x", {})
    end
    local db = _G.LibStub("AceDB-3.0"):New("KeepThatDB", defaults, true)
    local lib = _G.LibStub
    _G.LibStub = old
    return db, lib
end

return M
