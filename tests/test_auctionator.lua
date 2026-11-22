-- Integrations/Auctionator.lua against the auctionator-export scenarios, with the real Forever data and
-- a fake Auctionator.API.v1 that keeps its shopping lists by name (CreateShoppingList replaces one).
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
H.load("Model/RecipeKnowledge.lua", ns)
H.load("Model/Wording.lua", ns)
H.load("Core/Context.lua", ns)
H.load("Debug/Log.lua", ns)
H.load("Integrations/Auctionator.lua", ns)
local AH = ns.AuctionatorExport
local names = ns.Data.Catalog.itemNames
eq(ns.client, "forever", "Forever data loaded")

-- Fake Auctionator: lists by name; each search is "name|exact|quantity".
local lists, calls = {}, {}
local function install()
    ns.Adapter.env = { Auctionator = { API = { v1 = {
        ConvertToSearchString = function(caller, term)
            calls[#calls + 1] = caller
            return ("%s|%s|%s"):format(term.searchString, tostring(term.isExact), tostring(term.quantity))
        end,
        CreateShoppingList = function(caller, name, searches)
            calls[#calls + 1] = caller
            lists[name] = searches
        end,
    } } } }
end
local function find(list, name)
    for _, s in ipairs(list or {}) do
        local n, exact, q = s:match("^(.-)|(.-)|(.-)$")
        if n == name then return { exact = exact, quantity = tonumber(q) } end
    end
end

-- Auctionator missing: unavailable with a reason, Export does nothing and does not error.
ns.Adapter.env = {}
local ok, reason = AH.Available()
eq(ok, false, "missing: unavailable")
eq(reason, "Auctionator is needed.", "missing: the reason says Auctionator is needed")
ok, reason = AH.Export("tailoring", "leveling")
eq(ok, false, "missing: export refused")
eq(reason, "Auctionator is needed.", "missing: same reason")
ns.Adapter.env = { Auctionator = { API = { v1 = { CreateShoppingList = function() end } } } }
eq((AH.Available()), false, "an incomplete API is unavailable")

install()
eq((AH.Available()), true, "installed: available")

-- Endgame: one exact search per enabled Blacksmithing endgame material, under the KeepThat name.
local expected = {}
for itemID, entry in pairs(ns.Data.Catalog.endgame) do
    if entry.blacksmithing then expected[#expected + 1] = itemID end
end
eq(#expected > 1, true, "Blacksmithing has endgame materials")
ok = AH.Export("blacksmithing", "endgame")
eq(ok, true, "endgame export works")
local bs = lists["KeepThat: Blacksmithing Endgame"]
eq(bs ~= nil, true, "list named KeepThat: Blacksmithing Endgame")
eq(#bs, #expected, "one search per Blacksmithing endgame material")
local first = find(bs, names[expected[1]])
eq(first and first.exact, "true", "searches are exact")
eq(first and first.quantity, nil, "endgame searches have no quantity")
for _, c in ipairs(calls) do eq(c, "KeepThat", "callerID is KeepThat") end

-- A material turned off is left out.
ns.defaults.profile.disabled.endgame[expected[1]] = true
AH.Export("blacksmithing", "endgame")
eq(#lists["KeepThat: Blacksmithing Endgame"], #expected - 1, "disabled endgame material left out")
eq(find(lists["KeepThat: Blacksmithing Endgame"], names[expected[1]]), nil, "the disabled one is gone")
ns.defaults.profile.disabled.endgame[expected[1]] = nil

-- Leveling: the quantity still needed from the player's skill, minus what they carry.
local BOLT = 14048
local SKILL = 260
ns.Adapter.ProfessionSkills = function() return { tailoring = SKILL } end
ns.Context.Invalidate()
local need = ns.Leveling.Need(ns.Data.Routes, "tailoring", BOLT, SKILL)
eq(need ~= nil and need.high > 0, true, "the route needs Bolt of Runecloth from 260")
local carry = 0
ns.Adapter.ItemCount = function(id) return id == BOLT and carry or 0 end

ok = AH.Export("tailoring", "leveling")
eq(ok, true, "leveling export works")
local tl = lists["KeepThat: Tailoring Leveling"]
eq(find(tl, names[BOLT]).quantity, need.high, "carrying none: the whole count")
local count = 0
for itemID in pairs(ns.Data.Routes.materials.tailoring) do
    local n = ns.Leveling.Need(ns.Data.Routes, "tailoring", itemID, SKILL)
    if n and (not n.high or n.high > 0) and names[itemID] then count = count + 1 end
end
eq(#tl, count, "one search per Tailoring leveling material still needed from the skill")

carry = need.high - 1
AH.Export("tailoring", "leveling")
eq(find(lists["KeepThat: Tailoring Leveling"], names[BOLT]).quantity, 1, "carrying one short: quantity 1")

-- Already carrying enough: not in the list. Exporting twice keeps one list, reflecting the second export.
carry = need.high
lists["My own list"] = { "Peacebloom" }
AH.Export("tailoring", "leveling")
eq(find(lists["KeepThat: Tailoring Leveling"], names[BOLT]), nil, "carrying enough: Bolt of Runecloth not exported")
eq(#lists["KeepThat: Tailoring Leveling"], count - 1, "the rest are still there")
local n = 0
for name in pairs(lists) do if name:find("^KeepThat: Tailoring") then n = n + 1 end end
eq(n, 1, "re-export: one KeepThat: Tailoring Leveling list")
eq(lists["My own list"][1], "Peacebloom", "the player's own list is untouched")
eq(#lists["My own list"], 1, "the player's own list is unchanged")

-- Cross-character stock: the realm-and-faction total replaces the bags count when the recorder knows it.
carry = 0
local total, rtotal = 0, nil
ns.StockRecorder = { Total = function(id) if id == BOLT then return rtotal end end }
rtotal = need.high
AH.Export("tailoring", "leveling")
eq(find(lists["KeepThat: Tailoring Leveling"], names[BOLT]), nil, "enough on another character: no entry")
rtotal = need.high - 3
AH.Export("tailoring", "leveling")
eq(find(lists["KeepThat: Tailoring Leveling"], names[BOLT]).quantity, 3, "part held elsewhere: the difference")
carry = need.high -- bags alone would say enough; the (incomplete) counted total wins
ns.StockRecorder.Total = function(id) if id == BOLT then return need.high - 2, false, {} end end
AH.Export("tailoring", "leveling")
eq(find(lists["KeepThat: Tailoring Leveling"], names[BOLT]).quantity, 2, "an incomplete total still uses the counted amount")
ns.StockRecorder.Total = function() return nil end
AH.Export("tailoring", "leveling")
eq(find(lists["KeepThat: Tailoring Leveling"], names[BOLT]), nil, "recorder total unknown: bags behaviour")
ns.StockRecorder = nil
carry = need.high - 1
AH.Export("tailoring", "leveling")
eq(find(lists["KeepThat: Tailoring Leveling"], names[BOLT]).quantity, 1, "no recorder: bags behaviour")
ns.StockRecorder = { Total = function() error("boom") end }
AH.Export("tailoring", "leveling")
eq(find(lists["KeepThat: Tailoring Leveling"], names[BOLT]).quantity, 1, "a failing recorder falls back to bags")
ns.StockRecorder = nil

-- Review #4: a material whose only steps left have no count is exported without a quantity.
do
    local saved = ns.Data.Routes.materials.tailoring[BOLT]
    ns.Data.Routes.materials.tailoring[BOLT] = { 1, 1, 50, 40, 40, 0, 1, SKILL, 300, 0, 0, 0 }
    ns.Context.Invalidate()
    carry = 0
    AH.Export("tailoring", "leveling")
    local row = find(lists["KeepThat: Tailoring Leveling"], names[BOLT])
    eq(row ~= nil, true, "uncounted steps ahead: still exported")
    eq(row and row.quantity, nil, "without a quantity")
    ns.Data.Routes.materials.tailoring[BOLT] = saved
    ns.Context.Invalidate()
end
-- A disabled leveling material is left out.
carry = 0
ns.defaults.profile.disabled.leveling[BOLT] = true
AH.Export("tailoring", "leveling")
eq(find(lists["KeepThat: Tailoring Leveling"], names[BOLT]), nil, "disabled leveling material left out")
ns.defaults.profile.disabled.leveling[BOLT] = nil

-- With Profession Journal running: its counts and its own materials are in the leveling list.
H.load("Integrations/ProfessionJournal.lua", ns)
local SILK = 14227 -- Ironweb Spider Silk: named in the catalog, not in the built-in Tailoring routes
eq(ns.Data.Routes.materials.tailoring[SILK], nil, "Ironweb Spider Silk is not a built-in Tailoring material")
ns.Adapter.env.DFLProfessionJournalNS = { GuideData = { tailoring = { steps = {
    { kind = "skill", from = 250, to = 270, materials = { { itemID = BOLT, total = 4000 }, { itemID = SILK, total = 10 } } },
} } } }
ns.ProfessionJournal.Start()
carry = 100
AH.Export("tailoring", "leveling")
tl = lists["KeepThat: Tailoring Leveling"]
eq(find(tl, names[BOLT]).quantity, 2000 - 100, "Profession Journal's larger count, less what is carried")
eq(find(tl, names[SILK]) and find(tl, names[SILK]).quantity, 5, "a material only Profession Journal uses is exported")
ns.Adapter.env.DFLProfessionJournalNS = nil
ns.Context.Invalidate()

-- Turned off in the Integrations settings, or not on Forever: unavailable.
ns.defaults.profile.integrations.auctionator = false
eq((AH.Available()), false, "integration off: unavailable")
ns.defaults.profile.integrations.auctionator = true
ns.client = "era"
eq((AH.Available()), false, "Classic Era: unavailable")
ns.client = "forever"

-- An Auctionator error: false with a reason, logged, and the export stops for the session.
ns.Adapter.env.Auctionator.API.v1.CreateShoppingList = function() error("changed API") end
ok, reason = AH.Export("tailoring", "leveling")
eq(ok, false, "an Auctionator error is caught")
eq(type(reason), "string", "with a reason")
eq(ns.Log.failures[#ns.Log.failures].area, "auctionator", "and logged")
eq((AH.Available()), false, "the export is off for the session")

H.done()
