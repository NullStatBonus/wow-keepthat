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

-- Cost estimate (specs auctionator-export, material-tooltip): prices come from Auctionator's last scan.
do
    local prices, ages = {}, {}
    local v1 = ns.Adapter.env.Auctionator.API.v1
    v1.GetAuctionPriceByItemID = function(caller, id) calls[#calls + 1] = caller; return prices[id] end
    v1.GetAuctionAgeByItemID = function(caller, id) calls[#calls + 1] = caller; return ages[id] end
    local realMaterials = ns.Auctionator.Materials
    local rows
    ns.Auctionator.Materials = function() return rows end
    local function lines() return ns.AuctionatorExport.EstimateLines("tailoring") end

    -- The setting is off by default: nothing is estimated and no price is read.
    rows = { { itemID = 1, quantity = 20 } }
    prices[1], ages[1] = 5000, 1
    local before = #calls
    eq(ns.defaults.profile.estimateLevelingCost, false, "the estimate setting is off by default")
    eq(ns.AuctionatorExport.EstimateAvailable(), false, "setting off: the estimate is unavailable")
    eq(lines(), nil, "setting off: no estimate lines")
    eq(ns.Auctionator.ItemCost(1, "tailoring"), nil, "setting off: no item cost")
    eq(#calls, before, "setting off: no price is read")

    eq(ns.AuctionatorExport.EstimateReason(), nil, "setting off: nothing else is against the estimate")
    ns.defaults.profile.estimateLevelingCost = true
    eq(ns.AuctionatorExport.EstimateAvailable(), true, "setting on: the estimate is available")

    -- All prices known: 20 x 50s + 10 x 1g = 20g.
    rows = { { itemID = 1, quantity = 20 }, { itemID = 2, quantity = 10 } }
    prices[2], ages[2] = 10000, 3
    local l = lines()
    eq(#l, 1, "all known: one sentence")
    eq(l[1], "Estimated cost: 20g, from Auctionator's last scan.", "all known: the total")
    for _, c in ipairs(calls) do eq(c, "KeepThat", "price calls use the KeepThat callerID") end

    -- One price unknown: the rest is "at least", never counted as 0.
    prices[2] = nil
    l = lines()
    eq(l[1], "At least 10g from Auctionator's last scan.", "one unknown: at least the known part")
    eq(l[2], "One material could not be priced.", "one unknown: says so")
    -- A stale price (no age) is unknown even with a price.
    prices[2], ages[2], ages[1] = 10000, 3, nil
    l = lines()
    eq(l[1], "At least 10g from Auctionator's last scan.", "stale price left out (item 1 is unknown, item 2 is 10 x 1g)")
    ages[1] = 1
    -- A material with no quantity is unknown; two unknown use the plural.
    rows = { { itemID = 1, quantity = 20 }, { itemID = 2 }, { itemID = 3, quantity = 5 } }
    l = lines()
    eq(l[2], "2 materials could not be priced.", "two unknown: plural")
    -- Nothing priced: no amount at all.
    prices[1], prices[2] = nil, nil
    l = lines()
    eq(#l, 1, "none known: one sentence")
    eq(l[1], "No cost estimate is available for these materials.", "none known: no amount")
    -- The result is recorded once in the debug log, again only when it changes.
    ns.addon = { db = { profile = ns.defaults.profile, global = { log = {} } } }
    ns.defaults.profile.debug = true
    prices[1], prices[2], rows = 5000, 10000, { { itemID = 1, quantity = 20 }, { itemID = 2, quantity = 10 } }
    lines(); lines()
    local logged = ns.addon.db.global.log
    eq(#logged, 1, "the estimate is logged once for an unchanged result")
    eq(logged[1], "[auctionator] estimate tailoring: 200000 copper, 2 priced, 0 unknown", "the log line gives the total and the counts")
    prices[2] = nil
    lines()
    eq(#logged, 2, "a changed result is logged again")
    ns.defaults.profile.debug = false
    ns.addon = nil
    prices[1], prices[2] = nil, nil
    -- Empty list: nothing to show.
    rows = {}
    eq(lines(), nil, "empty list: no lines")
    -- Rounded up to the next silver.
    prices[1], rows = 150, { { itemID = 1, quantity = 1 } }
    eq(lines()[1], "Estimated cost: 2s, from Auctionator's last scan.", "150 copper shows 2s")
    prices[1] = 10150
    eq(lines()[1], "Estimated cost: 1g 2s, from Auctionator's last scan.", "10150 copper shows 1g 2s")
    -- A lower bound rounds down: 1s 1c known plus an unknown is "at least 1s", never 2s.
    prices[1], rows = 101, { { itemID = 1, quantity = 1 }, { itemID = 2, quantity = 1 } }
    prices[2] = nil
    eq(lines()[1], "At least 1s from Auctionator's last scan.", "a partial total rounds down")
    prices[2] = nil
    ns.Auctionator.Materials = realMaterials

    -- The item cost on the Shift tooltip: the quantity is the export quantity.
    ns.StockRecorder = nil
    carry = need.high - 28
    prices[BOLT], ages[BOLT] = 5000, 2
    local c = ns.Auctionator.ItemCost(BOLT, "tailoring")
    eq(c and c.quantity, 28, "item cost: the export quantity")
    eq(c and c.cost, "14g", "item cost: 28 x 50s")
    -- Stock in the bank, the mail and on other characters lowers the quantity, and so the cost, like the export.
    carry = 0
    ns.StockRecorder = { Total = function(id) if id == BOLT then return need.high - 10, true, {} end end }
    c = ns.Auctionator.ItemCost(BOLT, "tailoring")
    eq(c and c.quantity, 10, "item cost: the realm-and-faction total is subtracted, not only the bags")
    eq(c and c.cost, "5g", "item cost: 10 x 50s")
    local e = ns.Auctionator.Estimate("tailoring")
    eq(e and e.copper, 50000, "page estimate: only the 10 still needed are priced")
    ns.StockRecorder.Total = function(id) if id == BOLT then return need.high, true, {} end end
    eq(ns.Auctionator.ItemCost(BOLT, "tailoring"), nil, "item cost: nothing when other characters hold enough")
    e = ns.Auctionator.Estimate("tailoring")
    eq(e and e.copper, 0, "page estimate: nothing to price when other characters hold enough")
    ns.StockRecorder = nil
    carry = need.high - 28
    ages[BOLT] = nil
    c = ns.Auctionator.ItemCost(BOLT, "tailoring")
    eq(c and c.quantity, 28, "item cost, stale price: the quantity")
    eq(c and c.cost, nil, "item cost, stale price: no amount")
    ages[BOLT] = 2
    carry = need.high
    eq(ns.Auctionator.ItemCost(BOLT, "tailoring"), nil, "item cost: nothing when the need is covered")
    carry = 0
    ns.defaults.profile.disabled.leveling[BOLT] = true
    eq(ns.Auctionator.ItemCost(BOLT, "tailoring"), nil, "item cost: nothing for a disabled material")
    ns.defaults.profile.disabled.leveling[BOLT] = nil
    do
        local saved = ns.Data.Routes.materials.tailoring[BOLT]
        ns.Data.Routes.materials.tailoring[BOLT] = { 1, 1, 50, 40, 40, 0, 1, SKILL, 300, 0, 0, 0 }
        ns.Context.Invalidate()
        eq(ns.Auctionator.ItemCost(BOLT, "tailoring"), nil, "item cost: nothing when the count is unknown")
        ns.Data.Routes.materials.tailoring[BOLT] = saved
        ns.Context.Invalidate()
    end
    ns.defaults.profile.estimateLevelingCost = false
    eq(ns.Auctionator.ItemCost(BOLT, "tailoring"), nil, "item cost: nothing with the setting off")
    ns.defaults.profile.estimateLevelingCost = true

    -- Unavailable on Classic Era and with the integration off.
    ns.client = "era"
    eq(ns.AuctionatorExport.EstimateAvailable(), false, "Classic Era: no estimate")
    eq(ns.AuctionatorExport.EstimateReason(), "Integrations are not yet available on Classic Era.", "Classic Era: the reason names the client")
    ns.client = "forever"
    ns.defaults.profile.integrations.auctionator = false
    eq(ns.AuctionatorExport.EstimateAvailable(), false, "integration off: no estimate")
    eq(ns.AuctionatorExport.EstimateReason(), "The Auctionator integration is turned off.", "integration off: the reason")
    ns.defaults.profile.integrations.auctionator = true

    -- A price function missing: no estimate, and the export still works.
    local savedAge = v1.GetAuctionAgeByItemID
    v1.GetAuctionAgeByItemID = nil
    eq(ns.AuctionatorExport.EstimateAvailable(), false, "no age function: no estimate")
    eq(ns.AuctionatorExport.EstimateReason(), "This version of Auctionator gives no prices.", "no age function: the reason")
    eq((AH.Export("tailoring", "leveling")), true, "no age function: the export still works")
    v1.GetAuctionAgeByItemID = savedAge

    -- A price call that raises stops only the estimate: logged, export unaffected.
    v1.GetAuctionPriceByItemID = function() error("changed API") end
    eq(ns.Auctionator.ItemCost(BOLT, "tailoring"), nil, "price error: no item cost")
    eq(ns.Auctionator.estimateFailed, true, "price error: the estimate stops for the session")
    eq(ns.Log.failures[#ns.Log.failures].area, "auctionator-estimate", "price error: logged")
    eq(ns.AuctionatorExport.EstimateAvailable(), false, "price error: estimate unavailable")
    eq(ns.AuctionatorExport.EstimateReason(), "The cost estimate stopped after an error. See /kt log.", "price error: the reason")
    eq((AH.Available()), true, "price error: the export stays available")
    eq((AH.Export("tailoring", "leveling")), true, "price error: the export still works")
    ns.Auctionator.estimateFailed = nil
    ns.defaults.profile.estimateLevelingCost = false
    carry = need.high
end

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
