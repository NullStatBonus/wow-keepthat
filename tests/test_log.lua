-- Debug/Log.lua: recording and Log.Report (spec settings, "Debug report").
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ns = H.locale({})
H.load("Core/Defaults.lua", ns)
H.load("Debug/Log.lua", ns)
local Log = ns.Log

local function copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = copy(v) end
    return c
end
local function has(s, needle, msg) eq(s:find(needle, 1, true) ~= nil, true, msg .. " (" .. needle .. ")") end

ns.version, ns.client = "1.2.3", "forever"
ns.addon = { db = { profile = copy(ns.defaults.profile), global = { log = {} } } }

-- Recording only while debug is on.
Log.Record("tip", "ignored")
eq(#ns.addon.db.global.log, 0, "nothing recorded while debug is off")
ns.addon.db.profile.debug = true
Log.Record("tip", "kept")
eq(ns.addon.db.global.log[1], "[tip] kept", "recorded while debug is on")

-- Report without an integrations module and without failures.
local r = Log.Report()
has(r, "KeepThat 1.2.3, client forever", "header")
has(r, "endgame = true", "a top-level setting")
has(r, "leveling = false", "another setting")
has(r, "estimateLevelingCost = false", "the estimate setting is listed")
has(r, "colors.endgame.r = 0.64", "nested setting is flattened")
has(r, "locations.bags = true", "locations are listed")
has(r, "integrations.bagnon = true", "integration toggles are listed")
has(r, "(state not available)", "integrations state missing is said")
has(r, "(none)", "no failures")
has(r, "[tip] kept", "recorded lines")

-- Scenario: an integration was disabled after a failure.
ns.Integrations = { Status = function(key)
    if key == "baganator" then return { detected = true, working = false, reason = "overlay hook failed" } end
    return { detected = false, working = false }
end }
Log.Failure("baganator", "overlay hook failed")
r = Log.Report()
has(r, "baganator: detected=true, working=false, reason=overlay hook failed", "integration state names the reason")
has(r, "bagnon: detected=false, working=false", "undetected integration")
has(r, "[baganator] overlay hook failed", "failure is listed")
has(r, "[baganator] FAILED: overlay hook failed", "failure is also a recorded line")

-- Stock state.
has(r, "stock: unknown", "no recorder: stock unknown")
ns.StockRecorder = { State = function() return { version = 1, characters = 3,
    missing = { { name = "Alt", bank = true, mail = true }, { name = "Bob", bank = false, mail = true } },
    unavailable = { bank = true, mail = false }, reminder = false } end }
r = Log.Report()
has(r, "version = 1", "stock version")
has(r, "characters = 3", "stock characters")
has(r, "missing = Alt (bank and mailbox), Bob (mailbox)", "missing sources by name")
has(r, "unavailable = bank\n", "unavailable sources")
has(r, "reminder = off", "reminder setting")
ns.StockRecorder = { State = function() error("boom") end }
has(Log.Report(), "stock: unknown", "a failing State is reported as unknown")
ns.StockRecorder = nil

-- Recipe knowledge per profession, and the Recipe order setting.
has(r, "recipeOrder = learned", "recipe order setting listed")
has(r, "Recipes:\n  recipes: unknown", "no recipe recorder: unknown")
ns.Context = { Get = function() return { skills = { tailoring = 280 } } end }
ns.Recipes = { ReportLines = function(skills)
    eq(skills.tailoring, 280, "report lines get the live skills")
    return { "  tailoring: source=window complete=true known=12 recordable=true" }
end }
has(Log.Report(), "Recipes:\n  tailoring: source=window complete=true known=12 recordable=true", "a recorded profession")
ns.Recipes = { ReportLines = function() error("boom") end }
has(Log.Report(), "  recipes: unknown", "a failing recorder is reported as unknown")
ns.Recipes, ns.Context = nil, nil

-- A Status that errors does not break the report.
ns.Integrations = { Status = function() error("boom") end }
has(Log.Report(), "error:", "a failing Status is reported, not raised")

-- Toast sound: both settings listed; sound packs counted, or none without the library.
r = Log.Report()
has(r, "toastSound = auction", "toast sound setting listed")
has(r, "toastSoundChannel = Master", "toast channel setting listed")
ns.Adapter = { SoundPacks = function() return nil end }
has(Log.Report(), "sound packs = none", "no library")
ns.Adapter = { SoundPacks = function() return { a = "x", b = "y" } end }
has(Log.Report(), "sound packs = 2", "packs counted")
ns.Adapter = { SoundPacks = function() error("boom") end }
has(Log.Report(), "sound packs = none", "an error is contained")

H.done()
