-- Model/RecipeKnowledge.lua, Core/Adapter_Recipes.lua and Core/Recipes.lua against the recipe-knowledge spec
-- and the difficulty rules (design D1-D5, D8).
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ns = H.locale({})
H.load("Model/RecipeKnowledge.lua", ns)
local K = ns.RecipeKnowledge

-- Difficulty at rank (D1, D2): Transmute: Arcanite turns yellow at 275, green at 282, gray at 290.
local ARC = { y = 275, gy = 290 }
eq(K.Difficulty(ARC, 274, true), "orange", "learned below yellow: orange")
eq(K.Difficulty(ARC, 274, false), nil, "not learned below yellow: unknown (orange or too low to learn)")
eq(K.Difficulty(ARC, 274, nil), nil, "unknown knowledge below yellow: no word")
eq(K.Difficulty(ARC, 275, nil), "yellow", "yellow from the yellow rank")
eq(K.Difficulty(ARC, 281, true), "yellow", "yellow below the midpoint")
eq(K.Difficulty(ARC, 282, true), "green", "green from floor((275 + 290) / 2)")
eq(K.Difficulty(ARC, 289, false), "green", "green below gray")
eq(K.Difficulty(ARC, 290, true), "gray", "gray from the gray rank")
eq(K.Difficulty({ y = 30, gy = 60 }, 45, true), "green", "Linen Bandage turns green at 45")
eq(K.Difficulty({}, 100, true), nil, "no thresholds: unknown")
eq(K.Difficulty(nil, 100, true), nil, "no recipe: unknown")
eq(K.Difficulty(ARC, nil, true), nil, "no rank: unknown")

-- Three states (spec "Three states per recipe").
eq(K.State(nil, 1), nil, "no record: unknown, never not learned")
eq(K.State({ complete = false, known = { [1] = true } }, 1), true, "seen: learned")
eq(K.State({ complete = false, known = {} }, 2), nil, "incomplete record: unknown")
eq(K.State({ complete = true, known = {} }, 2), false, "complete record without it: not learned")

-- Window reads (spec "Knowledge is recorded when the profession window opens").
local records = {}
K.Apply(records, { profession = "tailoring", complete = false, known = { [10] = true } }, 1)
eq(K.State(records.tailoring, 10), true, "a filtered read adds what it saw")
eq(K.State(records.tailoring, 11), nil, "a filtered read marks nothing not learned")
K.Apply(records, { profession = "tailoring", complete = true, known = { [11] = true } }, 2)
eq(K.State(records.tailoring, 11), true, "a complete read records the learned recipe")
eq(K.State(records.tailoring, 10), false, "a complete read replaces the record")
eq(records.tailoring.at, 2, "the read time is kept")
K.Apply(records, { profession = "tailoring", complete = false, known = { [12] = true } }, 3)
eq(records.tailoring.complete, true, "a later filtered read keeps a complete record complete")
eq(K.State(records.tailoring, 12), true, "and adds what it saw")
eq(K.Count(records.tailoring), 2, "known count")
eq(K.Apply(records, { complete = true }), nil, "a read without a profession is ignored")

-- Learn events (spec "A newly learned recipe is never shown as not learned", D5).
local catalog = { recipes = { [20] = { p = "tailoring" }, [30] = { p = "enchanting" } } }
eq(K.Learned(records, catalog, 20), "tailoring", "a catalog recipe is learned in its profession")
eq(K.State(records.tailoring, 20), true, "learned at once, though the complete record lacked it")
eq(K.Learned(records, catalog, 30), "enchanting", "a profession without a record gets one")
eq(K.State(records.enchanting, 30), true, "the new recipe is learned")
eq(records.enchanting.complete, false, "and the rest of that profession stays unknown")
eq(K.Learned(records, catalog, 999), nil, "a class spell changes nothing")
eq(K.Learned(records, catalog, nil), nil, "an event without an ID changes nothing")
local unsure = { tailoring = { complete = true, known = { [1] = true } } }
K.Unsure(unsure)
eq(K.State(unsure.tailoring, 2), nil, "unsure: not learned becomes unknown")
eq(K.State(unsure.tailoring, 1), true, "unsure: learned stays learned")

-- A dropped profession forgets its recipes.
local dropping = { alchemy = { complete = true, known = {} }, tailoring = { complete = true, known = {} } }
local dropped = K.Drop(dropping, { tailoring = 300 })
eq(dropped[1], "alchemy", "the dropped profession is reported")
eq(dropping.alchemy, nil, "its record is gone")
eq(dropping.tailoring ~= nil, true, "a profession still known keeps its record")
K.Drop(dropping, {}, { tailoring = true })
eq(dropping.tailoring ~= nil, true, "a profession out of view is kept")

-- Recipe order (D8).
local function order(o, list)
    local out = {}
    for _, r in ipairs(K.Sort(list, o)) do out[#out + 1] = r.spell end
    return table.concat(out, ",")
end
local function list()
    return { { spell = 1, y = 300, state = false }, { spell = 2, y = 200, state = true }, { spell = 3, y = 250, state = nil },
        { spell = 4, state = true }, { spell = 5, y = 300, state = true } }
end
eq(order("learned", list()), "5,2,4,3,1", "learned first, yellow rank highest first, no rank last")
eq(order(nil, list()), "5,2,4,3,1", "learned first is the default")
eq(order("unlearned", list()), "1,3,5,2,4", "not learned first")
eq(order("skill", list()), "1,5,3,2,4", "highest skill first ignores learned status, ties by spell ID")

-- Adapter (D3, D4b): Era trade skill window, Era craft window, Forever recipe info.
local function adapter(env)
    local a = { L = ns.L }
    H.load("Core/Adapter.lua", a)
    H.load("Core/Adapter_Recipes.lua", a)
    a.Adapter.env = env
    return a.Adapter
end
local function rows(t)
    return function(i) local r = t[i]; if r then return r[1], r[2], r[3], r[4] end end
end
local tradeRows = {
    { "Cloth", "header", 0, true },
    { "Mooncloth", "optimal", 0, nil },
    { "Bolt of Runecloth", "trivial", 0, nil },
}
local links = { [2] = "|cffffffff|Henchant:18560|h[Mooncloth]|h|r", [3] = "|Henchant:18401|h[Bolt of Runecloth]|h" }
local era = {
    GetTradeSkillLine = function() return "Tailoring", 280, 300 end,
    GetNumTradeSkills = function() return #tradeRows end,
    GetTradeSkillInfo = rows(tradeRows),
    GetTradeSkillRecipeLink = function(i) return links[i] end,
    GetTradeSkillSubClassFilter = function() return 1 end,
    GetTradeSkillInvSlotFilter = function() return 1 end,
}
local A = adapter(era)
-- Off in this version: Classic Era's window reads are unverified in game (Forever only).
eq(A.RecipeWindow("trade", {}), nil, "Era window reads are off until verified")
eq(A.RecipeRecordable("tailoring"), false, "and no profession is recordable, so no hint shows")
A.WINDOW_ROWS_VERIFIED = true
local read = A.RecipeWindow("trade", {})
eq(read.profession, "tailoring", "Era: the profession from the window title")
eq(read.complete, true, "Era: no filter and every header open is complete")
eq(read.known[18560], true, "Era: spell ID from the recipe link")
eq(read.known[18401], true, "Era: every listed recipe is learned")
eq(read.rows[1].client, "orange", "Era: the client's own difficulty, for the probe")
tradeRows[1][4] = false
eq(A.RecipeWindow("trade", {}).complete, false, "Era: a collapsed header makes the read incomplete")
tradeRows[1][4] = true
era.GetTradeSkillSubClassFilter = function() return nil end
eq(A.RecipeWindow("trade", {}).complete, false, "Era: a subclass filter makes the read incomplete")
era.GetTradeSkillSubClassFilter = nil
eq(A.RecipeWindow("trade", {}).complete, false, "Era: a missing filter getter counts as filtered")
era.GetTradeSkillSubClassFilter = function() return 1 end
era.TradeSkillFrameAvailableFilterCheckButton = { GetChecked = function() return true end }
eq(A.RecipeWindow("trade", {}).complete, false, "Era: 'Have materials' makes the read incomplete")
era.TradeSkillFrameAvailableFilterCheckButton = nil
links[3] = "|Hitem:14048|h[Bolt of Runecloth]|h"
read = A.RecipeWindow("trade", {})
eq(read.complete, false, "Era: a row without a spell ID makes the read incomplete")
eq(read.known[18560], true, "Era: the keyed rows still count")
era.GetTradeSkillLine = function() return "Unknown", 1, 1 end
eq(A.RecipeWindow("trade", {}), nil, "Era: an unknown profession gives nothing")
era.GetTradeSkillInfo = function() error("boom") end
era.GetTradeSkillLine = function() return "Tailoring", 1, 1 end
eq(A.RecipeWindow("trade", {}).complete, false, "Era: a failing row read is incomplete, never an error")
eq(A.RecipeRecordable("tailoring"), true, "Era: trade skills are recordable")
eq(A.RecipeRecordable("enchanting"), true, "Era: Enchanting is recordable through the trade skill path when there is no craft API")

local craftRows = { { "Bracer", "", "header", 0, true }, { "Enchant Bracer - Minor Health", "", "medium", 0, nil } }
local craft = adapter({
    GetCraftDisplaySkillLine = function() return "Enchanting", 100, 300 end,
    GetNumCrafts = function() return #craftRows end,
    GetCraftInfo = function(i) local r = craftRows[i]; return r[1], r[2], r[3], r[4], r[5] end,
    GetCraftItemLink = function() return "|Henchant:7418|h[Enchant Bracer - Minor Health]|h" end,
})
craft.WINDOW_ROWS_VERIFIED = true
read = craft.RecipeWindow("craft", {})
eq(read.profession, "enchanting", "Era craft: Enchanting")
eq(read.known[7418], true, "Era craft: spell ID from the craft link")
eq(read.rows[1].client, "yellow", "Era craft: the craft type is the difficulty")
eq(read.complete, true, "Era craft: every header open is complete")
craftRows[1][5] = false
eq(craft.RecipeWindow("craft", {}).complete, false, "Era craft: a collapsed header (0 available) makes the read incomplete")
craftRows[1][5] = true
eq(craft.RecipeRecordable("enchanting"), true, "Era craft: Enchanting is recordable")
local noIDs = adapter({
    GetCraftDisplaySkillLine = function() return "Enchanting", 100, 300 end,
    GetNumCrafts = function() return 1 end,
    GetCraftInfo = function() return "Enchant", "", "medium", 0, nil end,
    GetCraftItemLink = function() return "|Hitem:1|h[x]|h" end,
})
noIDs.WINDOW_ROWS_VERIFIED = true
eq(noIDs.RecipeRecordable("enchanting"), true, "Era craft: recordable until a read shows otherwise")
eq(noIDs.RecipeWindow("craft", {}), nil, "Era craft: links without spell IDs record nothing")
eq(noIDs.RecipeRecordable("enchanting"), false, "Era craft: then Enchanting is not recordable, so its hint goes away")
local linked = adapter({ IsTradeSkillLinked = function() return true end, GetTradeSkillLine = function() return "Tailoring", 1, 1 end,
    GetNumTradeSkills = function() return 0 end, GetTradeSkillInfo = function() end })
linked.WINDOW_ROWS_VERIFIED = true
eq(linked.RecipeWindow("trade", {}), nil, "a linked profession is never recorded as this character's")
local npc = adapter({ C_TradeSkillUI = { IsNPCCrafting = function() return true end,
    GetBaseProfessionInfo = function() return { professionID = 197 } end, GetRecipeInfo = function() return { learned = true } end } })
eq(npc.RecipeWindow("trade", { recipes = { [1] = { p = "tailoring" } } }), nil, "an NPC crafter's window is not recorded")

local info = { [18560] = { learned = true, relativeDifficulty = 1 }, [18401] = { learned = false, relativeDifficulty = 3 } }
local forever = adapter({ C_TradeSkillUI = {
    GetBaseProfessionInfo = function() return { professionID = 197, professionName = "Tailoring" } end,
    GetRecipeInfo = function(spell) return info[spell] end,
} })
read = forever.RecipeWindow("trade", { recipes = { [18560] = { p = "tailoring" }, [18401] = { p = "tailoring" },
    [99] = { p = "tailoring" }, [7418] = { p = "enchanting" } } })
eq(read.profession, "tailoring", "Forever: the profession from the skill line ID")
eq(read.complete, true, "Forever: asking each recipe ignores window filters")
eq(read.known[18560], true, "Forever: learned from recipe info")
eq(read.known[18401], nil, "Forever: unlearned is not known")
eq(#read.rows, 2, "Forever: only the open profession's recipes the client lists")
eq(forever.RecipeRecordable("enchanting"), true, "Forever: every profession is recordable")
eq(adapter({}).RecipeWindow("trade", {}), nil, "no window API: nothing")
eq(adapter({}).RecipeRecordable("tailoring"), false, "no window API: not recordable")
eq(adapter({ IsPlayerSpell = function(s) return s == 1 end }).IsPlayerSpell(1), true, "IsPlayerSpell true")
eq(adapter({ IsPlayerSpell = function(s) return s == 1 end }).IsPlayerSpell(2), false, "IsPlayerSpell false")
eq(adapter({}).IsPlayerSpell(1), nil, "IsPlayerSpell missing: unknown")

-- Recorder (Core/Recipes.lua): per character in db.global.recipes[realm][name], events, status and the hint.
local rns = H.locale({})
H.load("Model/RecipeKnowledge.lua", rns)
local logged = {}
rns.Log = { Enabled = function() return true end, Record = function(_, m) logged[#logged + 1] = m end }
local invalidated = 0
local skills = { tailoring = 280 }
rns.Context = { Invalidate = function() invalidated = invalidated + 1 end, Get = function() return { skills = skills } end }
rns.Data = { Catalog = { recipes = { [18560] = { p = "tailoring", y = 290, gy = 320 }, [18401] = { p = "tailoring", y = 250, gy = 270 },
    [12092] = { p = "tailoring", y = 275, gy = 290 } } } }
local identity = { "Me", "Realm" }
rns.addon = { db = { global = {} } }
local windowRead
local recordable = true
rns.Adapter = {
    RecipeWindow = function() return windowRead end,
    RecipeRecordable = function() return recordable end,
    IsPlayerSpell = function() return nil end,
    Clock = function() return 100 end,
    PlayerIdentity = function() return identity[1], identity[2], "Alliance" end,
}
local started
rns.Start = function(fn) started = fn end
H.load("Core/Recipes.lua", rns)
local Rc = rns.Recipes

eq(Rc.Status("tailoring", 18560, skills).learned, nil, "never opened: unknown")
eq(Rc.Status("tailoring", 12092, skills).difficulty, "yellow", "never opened: the difficulty alone at or above yellow")
eq(Rc.Status("tailoring", 18560, skills).difficulty, nil, "never opened, below yellow: no difficulty")
eq(Rc.Status("alchemy", 1, skills), nil, "a profession the character does not have: no status")
eq(Rc.NeedsHint("tailoring", skills), true, "never opened: the hint shows")
eq(Rc.NeedsHint("alchemy", skills), false, "no hint for a profession the character does not have")
recordable = false
eq(Rc.NeedsHint("tailoring", skills), false, "no hint when this client cannot record the profession")
recordable = true

windowRead = { profession = "tailoring", complete = true, known = { [18560] = true }, rows = {} }
Rc.OnWindow("trade")
local saved = rns.addon.db.global.recipes.Realm.Me
eq(saved.tailoring.complete, true, "stored per character under realm and name")
eq(saved.tailoring.at, 100, "with the read time")
eq(invalidated, 1, "a changed record refreshes the tooltip")
eq(logged[#logged], "tailoring complete=true known=1", "one log line per record change")
local logs = #logged
Rc.OnWindow("trade")
eq(invalidated, 1, "the same read again changes nothing")
eq(#logged, logs, "and is not logged again this session")
H.load("Core/Recipes.lua", rns)   -- a /reload: the saved record stays, the session starts over
Rc = rns.Recipes
Rc.OnWindow("trade")
eq(logged[#logged], "tailoring complete=true known=1", "the first read after a reload is logged, though nothing changed")
eq(invalidated, 1, "and refreshes nothing")
local st = Rc.Status("tailoring", 18560, skills)
eq(st.learned, true, "learned after opening the window")
eq(st.difficulty, "orange", "learned below yellow: orange")
eq(Rc.Status("tailoring", 18401, skills).learned, false, "not in the complete record: not learned")
eq(Rc.Status("tailoring", 18401, skills).difficulty, "gray", "not learned above gray: gray")
eq(Rc.NeedsHint("tailoring", skills), false, "the hint goes away once the knowledge is recorded")

Rc.OnLearned("NEW_RECIPE_LEARNED", 18401)
eq(Rc.Status("tailoring", 18401, skills).learned, true, "learned from a trainer with the window closed")
eq(invalidated, 2, "learning refreshes the tooltip")
Rc.OnLearned("LEARNED_SPELL_IN_TAB", 133)
eq(invalidated, 2, "a class spell refreshes nothing here")
eq(saved.tailoring.complete, true, "and keeps the record complete")

identity = { "Alt", "Realm" }
eq(Rc.Status("tailoring", 18560, skills).learned, nil, "another character: unknown")
identity = { "Me", "Realm" }

Rc.Drop({ alchemy = 10 }, { ["Secondary Skills"] = true })
eq(saved.tailoring ~= nil, true, "a collapsed Skills header drops nothing")
Rc.Drop({}, {})
eq(saved.tailoring ~= nil, true, "an empty skills read drops nothing")
Rc.Drop({ alchemy = 10 }, {})
eq(saved.tailoring, nil, "a dropped profession forgets its recipes")

identity = { nil, nil }
Rc.OnWindow("trade")
eq(Rc.Status("tailoring", 18560, skills).learned, nil, "no identity: nothing recorded, unknown")
identity = { "Me", "Realm" }

-- Report lines (spec "Knowledge sources in the debug report").
Rc.OnWindow("trade")
local lines = Rc.ReportLines({ tailoring = 280, alchemy = 10 })
eq(lines[1], "  alchemy: source=none complete=false known=0 recordable=true", "a profession never opened")
eq(lines[2], "  tailoring: source=window complete=true known=1 recordable=true", "a recorded profession")
eq(Rc.ReportLines({})[1], "  (no professions)", "no professions")

-- The probe logs one summary per profession and the rows whose computed difficulty differs.
logged = {}
rns.Log.Record = function(_, m) logged[#logged + 1] = m end
Rc.Probe({ profession = "tailoring", complete = true, known = { [18560] = true }, source = "trade skill window",
    rows = { { spell = 18560, client = "orange", learned = true }, { spell = 12092, client = "green", learned = true } } })
eq(logged[1]:find("recipe probe: tailoring source=trade skill window rows=2 complete=true", 1, true) ~= nil, true, "probe summary")
eq(logged[1]:find("mismatches=1", 1, true) ~= nil, true, "one mismatch counted")
eq(logged[1]:find("unlisted=2", 1, true) ~= nil, true, "unlisted catalog recipes counted")
eq(logged[2], "recipe probe: tailoring 12092 client=green computed=yellow y=275 gy=290 rank=280", "the mismatch row")
local n = #logged
Rc.Probe({ profession = "tailoring", complete = true, known = { [18560] = true }, source = "trade skill window",
    rows = { { spell = 18560, client = "orange", learned = true }, { spell = 12092, client = "green", learned = true } } })
eq(#logged, n, "the same probe result is not logged twice")

-- Events go to a module of its own; a failing handler is recorded, never raised.
local registered = {}
local module = { RegisterEvent = function(_, e, fn) registered[e] = fn end }
rns.Listen = function(target, e, fn) target:RegisterEvent(e, fn); return true end
rns.Log.Failure = function(area, err) logged[#logged + 1] = area .. ": " .. tostring(err) end
started({ NewModule = function() return module end })
eq(type(registered.TRADE_SKILL_SHOW), "function", "trade skill window listened for")
eq(type(registered.CRAFT_UPDATE), "function", "craft window listened for")
eq(type(registered.NEW_RECIPE_LEARNED), "function", "learn event listened for")
rns.Adapter.RecipeWindow = function() error("broken") end
registered.TRADE_SKILL_SHOW("TRADE_SKILL_SHOW")
eq(logged[#logged]:find("recipes: ", 1, true) == 1, true, "a failure is recorded")

H.done()
