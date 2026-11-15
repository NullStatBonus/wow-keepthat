-- Integrations/ProfessionJournal.lua against the leveling-guidance "Profession Journal adds to the
-- sources" scenarios. Profession Journal is faked with a hand-made route in its documented shape
-- (docs/contracts.md); none of its data is used here.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ns = {}
H.locale(ns)
H.load("Data/Catalog_Forever.lua", ns)
H.load("Data/Routes_Forever.lua", ns)
H.load("Core/Client.lua", ns)
H.load("Core/Adapter.lua", ns)
H.load("Core/Defaults.lua", ns)
H.load("Model/Leveling.lua", ns)
H.load("Model/Classify.lua", ns)
H.load("Model/Wording.lua", ns)
H.load("Core/Context.lua", ns)
H.load("Debug/Log.lua", ns)
H.load("Integrations/ProfessionJournal.lua", ns)
local PJ = ns.ProfessionJournal

local BOLT, BELT, MADE_UP, RUNE = 14048, 14143, 999001, 14047
local SKILL = 260

-- Missing: nothing to read, nothing logged, no error.
ns.Adapter.env = {}
eq(PJ.Detect(), false, "missing: not detected")
eq(PJ.Read("tailoring"), nil, "missing: Read gives nil")
eq(#ns.Log.failures, 0, "missing: nothing logged")
eq((PJ.Available()), false, "missing: unavailable")

-- A fake Profession Journal. The training row has only `from` until OrderedSteps sets `to`.
local orderedWith
local function fakePJ(boltTotal)
    return { DFLProfessionJournalNS = {
        API = { Faction = function() return "Horde" end },
        Leveling = { OrderedSteps = function(steps, faction)
            orderedWith = faction
            local out = {}
            for i, s in ipairs(steps) do
                local c = {}
                for k, v in pairs(s) do c[k] = v end
                if c.kind == "training" then c.to = c.from end
                out[i] = c
            end
            return out
        end },
        GuideData = { tailoring = { steps = {
            { kind = "training", from = 125, materials = {}, number = 1 },
            { kind = "preparation", forStep = 3, number = 2, make = { itemID = BOLT },
              materials = { { itemID = RUNE, name = "Runecloth", total = 30 } } },
            { kind = "skill", from = 250, to = 270, number = 3, make = { itemID = BELT },
              materials = { { itemID = BOLT, name = "Bolt of Runecloth", total = boltTotal },
                            { itemID = MADE_UP, name = "Only in Profession Journal", total = 5 } } },
            { kind = "gap", from = 270, to = 275, number = 4 },
        } } },
        UI = { OpenRecipeInJournal = function(self, key, spellID, name)
            self.opened = { key, spellID, name }
            return true
        end },
    } }
end

-- Installed: its route is read into segments, in its own faction order.
ns.Adapter.env = fakePJ(40)
eq(PJ.Detect(), true, "installed: detected")
local segs = PJ.Read("tailoring")
eq(orderedWith, "Horde", "OrderedSteps gets API.Faction()")
eq(table.concat(segs[BOLT], ","), "250,270,40,40," .. BELT, "one segment: from, to, total, total, via")
eq(table.concat(segs[RUNE], ","), "250,270,30,30," .. BOLT, "a preparation step counts over the range of the step it is for")
eq(PJ.Read("alchemy"), nil, "no guide for a profession: nil")

-- Started: it joins the built-in sources in the range, through ns.Context and ns.Leveling.Need.
ns.defaults.profile.leveling = true
ns.Adapter.ProfessionSkills = function() return { tailoring = SKILL } end
PJ.Start()
local builtIn = ns.Leveling.Need(ns.Data.Routes, "tailoring", BOLT, SKILL)
local function levelingNeed(itemID)
    local r = ns.Context.Classify(itemID)
    for _, e in ipairs(r and r.leveling or {}) do
        if e.profession == "tailoring" then return e.need end
    end
end
local need = levelingNeed(BOLT)
local named = false
for _, s in ipairs(need.sources) do if s == "DFL Profession Journal" then named = true end end
eq(named, true, "the details name DFL Profession Journal")
eq(need.high, builtIn.high, "a smaller count does not raise the top")
eq(need.low, math.min(builtIn.low, 20), "half its 250-270 step is still ahead of 260")
eq(levelingNeed(MADE_UP) ~= nil, true, "a material only Profession Journal uses becomes a leveling material")
eq(levelingNeed(MADE_UP).high, 3, "with its count (5 over 250-270, half ahead, rounded up)")

-- Profession Journal needs more: the top of the range is its count.
ns.Adapter.env = fakePJ(4000)
ns.Context.Invalidate()
need = levelingNeed(BOLT)
eq(need.high, 2000, "the top of the range is Profession Journal's count")
eq(need.high > builtIn.high, true, "above every built-in guide")

-- Unreadable shape: nil, only the built-in sources, logged once, no error.
local function unreadable(env, label)
    ns.Adapter.env = env
    PJ.ClearFailures()
    ns.Context.Invalidate()
    local before = #ns.Log.failures
    eq(PJ.Read("tailoring"), nil, label .. ": Read gives nil")
    local n = levelingNeed(BOLT)
    eq(n.high, builtIn.high, label .. ": the built-in count")
    for _, s in ipairs(n.sources) do eq(s ~= "DFL Profession Journal", true, label .. ": not named") end
    levelingNeed(BOLT)
    PJ.Read("tailoring")
    eq(#ns.Log.failures, before + 1, label .. ": logged once")
    eq(ns.Log.failures[#ns.Log.failures].area, "professionjournal", label .. ": under professionjournal")
end
local env = fakePJ(40)
env.DFLProfessionJournalNS.GuideData.tailoring.steps = "not a list"
unreadable(env, "steps not a list")
env = fakePJ(40)
env.DFLProfessionJournalNS.GuideData.tailoring.steps[3].to = "270"
unreadable(env, "a string skill range")
env = fakePJ(40)
env.DFLProfessionJournalNS.GuideData.tailoring.steps[3].materials = { [BOLT] = 40 }
unreadable(env, "materials keyed by item")
env = fakePJ(40)
env.DFLProfessionJournalNS.Leveling.OrderedSteps = function() error("changed") end
unreadable(env, "OrderedSteps errors")
env = fakePJ(40)
env.DFLProfessionJournalNS.GuideData = "renamed"
eq(PJ.Detect(), true, "loaded with a changed GuideData: still detected, so the reason is logged")
unreadable(env, "GuideData not a table")

-- Without OrderedSteps, the steps are read as they are.
env = fakePJ(40)
env.DFLProfessionJournalNS.Leveling = nil
env.DFLProfessionJournalNS.GuideData.tailoring.steps[1].to = 125
ns.Adapter.env = env
PJ.ClearFailures()
eq(PJ.Read("tailoring")[BOLT][3], 40, "no OrderedSteps: raw steps")

-- Nothing is stored: no saved variables are touched (there is no ns.addon.db here to write to), and
-- the segments are a session cache dropped on invalidation.
ns.Adapter.env = fakePJ(40)
ns.Context.Invalidate()
eq(levelingNeed(BOLT).high, builtIn.high, "after invalidation the new data is read")

-- Missing after start: only the built-in sources.
ns.Adapter.env = {}
ns.Context.Invalidate()
eq(levelingNeed(BOLT).high, builtIn.high, "missing after start: built-in count")
eq(levelingNeed(MADE_UP), nil, "missing after start: its own material is gone")

-- Link to a recipe in its window.
env = fakePJ(40)
ns.Adapter.env = env
eq(PJ.Open("tailoring", 18560, "Mooncloth"), true, "Open opens the recipe")
eq(env.DFLProfessionJournalNS.UI.opened[1], "tailoring", "with its profession key")
env.DFLProfessionJournalNS.UI.OpenRecipeInJournal = function() error("broken") end
eq(PJ.Open("tailoring", 18560, "Mooncloth"), false, "an error opening is caught")
ns.Adapter.env = {}
eq(PJ.Open("tailoring", 18560, "Mooncloth"), false, "missing: Open gives false")

H.done()
