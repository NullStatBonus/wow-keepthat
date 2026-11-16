-- Core loads the way the game loads it: the locale table, the version from the TOC, and an Ace addon.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq
local stubs = require("stubs")

local created
stubs.install({
    C_AddOns = { GetAddOnMetadata = function(name, field) return name == "KeepThat" and field == "Version" and "9.9.9" or nil end },
    LibStub = function(lib)
        eq(lib, "AceAddon-3.0", "Core asks for AceAddon")
        return { NewAddon = function(_, name, ...) created = { name = name, mixins = { ... } }; return created end }
    end,
})

local ns = {}
H.locale(ns)
H.load("Core/Init.lua", ns)
H.load("Core/Addon.lua", ns)

eq(ns.L["Any sentence"], "Any sentence", "an untranslated sentence comes back as written")
eq(ns.name, "KeepThat", "the addon name comes from the game")
eq(ns.version, "9.9.9", "the version comes from the TOC")
eq(ns.addon, created, "the Ace addon is stored in ns")
eq(created.name, "KeepThat", "the Ace addon is named after the addon")
eq(table.concat(created.mixins, ","), "AceEvent-3.0,AceConsole-3.0,AceHook-3.0", "the Ace mixins")

stubs.restore()

-- Saved data through the real AceDB-3.0 and the real defaults.
local function loadAceDB(saved)
    stubs.install({
        UnitName = function() return "Me" end,
        GetRealmName = function() return "Realm" end,
        UnitClass = function() return "Mage", "MAGE" end,
        UnitRace = function() return "Human", "Human" end,
        UnitFactionGroup = function() return "Alliance" end,
        GetLocale = function() return "enUS" end,
        GetCurrentRegion = function() return 1 end,
        GetCurrentRegionName = function() return "US" end,
        CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end,
    })
    _G.KeepThatDB = saved
    local old = { LibStub = _G.LibStub }
    _G.LibStub = nil
    for _, f in ipairs({ "LibStub/LibStub.lua", "CallbackHandler-1.0/CallbackHandler-1.0.lua", "AceDB-3.0/AceDB-3.0.lua" }) do
        assert(loadfile("KeepThat/Libs/" .. f))("x", {})
    end
    local dbns = {}
    H.load("Core/Defaults.lua", dbns)
    local db = _G.LibStub("AceDB-3.0"):New("KeepThatDB", dbns.defaults, true)
    local lib = _G.LibStub
    _G.LibStub = old.LibStub
    return db, lib
end

-- An existing save keeps its log and its stock; the reminder default fills in.
local char = { seen = 5, bags = { unavailable = true } }
local saved = { global = { log = { "one", "two" }, stock = { version = 1, realms = { R = { Alliance = { Bob = char } } } } } }
local db = loadAceDB(saved)
eq(#db.global.log, 2, "saved log survives")
eq(db.global.log[2], "two", "saved log lines are intact")
eq(db.global.stock.realms.R.Alliance.Bob, char, "saved stock keeps its character")
eq(db.global.stock.version, 1, "saved stock keeps its version")
eq(db.profile.stockReminder, true, "reminder defaults on for an existing save")

-- A new install: AceDB adds no stock (Core/Stock.lua creates it at login), and the reminder is on.
db = loadAceDB(nil)
eq(db.global.stock, nil, "new install: no stock from defaults")
eq(db.profile.stockReminder, true, "new install reminder on")

-- A version written by a newer KeepThat is not touched.
local future = { version = 2, payload = { R = { Bob = { seen = 1 } } }, extra = "kept" }
db = loadAceDB({ global = { stock = future } })
eq(db.global.stock.version, 2, "future stock version left alone")
eq(db.global.stock.extra, "kept", "future stock fields left alone")
eq(db.global.stock.payload.R.Bob.seen, 1, "future stock data left alone")
eq(db.global.stock.realms, nil, "no defaults merged into future stock (no realms added)")

_G.KeepThatDB = nil
stubs.restore()
H.done()
