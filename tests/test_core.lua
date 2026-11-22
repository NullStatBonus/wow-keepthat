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
eq(table.concat(created.mixins, ","), "AceEvent-3.0,AceConsole-3.0", "the Ace mixins")

stubs.restore()

-- OnInitialize restores the profile choice before the presentation upgrade (SetProfile replaces db.profile).
do
    local order, fakeDb = {}, { profile = {}, keys = { char = "Me Smith" } }
    stubs.install({ LibStub = function(lib)
        if lib == "AceAddon-3.0" then return { NewAddon = function() return {} end } end
        return { New = function() return fakeDb end }
    end })
    local n2 = {}
    H.locale(n2)
    H.load("Core/Init.lua", n2)
    H.load("Core/Addon.lua", n2)
    n2.defaults = { profile = {} }
    n2.Adapter = { LegacyCharacterKey = function() return "Me - Realm" end, ProfessionDisplayNames = function() return {} end }
    n2.ProfileKey = { Migrate = function(db, key) order[#order + 1] = "profile:" .. key; eq(db, fakeDb, "migration gets the db") end,
        Rename = function(db, key) order[#order + 1] = "rename:" .. key; eq(db, fakeDb, "rename gets the db") end }
    n2.Presentation = { Migrate = function() order[#order + 1] = "presentation" end }
    n2.Wording = { UseClientNames = function() end }
    n2.Slash = { Register = function() end }
    n2.addon:OnInitialize()
    eq(table.concat(order, ","), "profile:Me - Realm,rename:Me - Realm,presentation", "migrate, then rename, then the presentation upgrade")
    stubs.restore()
end

-- Saved data through the real AceDB-3.0 and the real defaults.
local function loadAceDB(saved)
    local dbns = {}
    H.load("Core/Defaults.lua", dbns)
    return stubs.loadAceDB(saved, dbns.defaults)
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
eq(db.profile.recipeOrder, "learned", "new install: Recipe order is Learned first")
eq(db.global.recipes, nil, "new install: no recipe records from defaults (Core/Recipes.lua creates them)")

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
