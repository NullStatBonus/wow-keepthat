-- Options/Options.lua: defaults, setters, the Materials tree, the Integrations page, profiles.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ARC, THORIUM, LINEN = 12360, 12359, 2589

local function copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = copy(v) end
    return c
end

local function fresh(opts)
    opts = opts or {}
    local ns = H.locale({})
    ns.client = opts.client or "forever"
    ns.version = "9.9.9"
    local started = {}
    ns.Start = function(fn) started[#started + 1] = fn end
    ns.started = started
    ns.Adapter = { ProfessionSkills = function() return opts.skills or { tailoring = 1 } end }
    H.load("Core/Defaults.lua", ns)
    H.load("Core/Presentation.lua", ns)
    H.load("Model/Leveling.lua", ns)
    H.load("Model/Classify.lua", ns)
    H.load("Model/RecipeKnowledge.lua", ns)
    H.load("Model/Wording.lua", ns)
    H.load("Model/Stock.lua", ns)
    H.load("Model/Sounds.lua", ns)
    H.load("Core/Context.lua", ns)
    ns.Data = { Catalog = {
        client = ns.client,
        itemNames = { [ARC] = "Arcanite Bar", [THORIUM] = "Thorium Bar", [LINEN] = "Linen Cloth" },
        spellNames = { [1] = "Arcanite Reaper" },
        recipes = { [1] = { p = "blacksmithing", learn = 300, make = 0, n = 1, r = { ARC, 12 } } },
        endgame = {
            [ARC] = { blacksmithing = { "Essential endgame crafting material", "Vendor and drops", 0 } },
            [THORIUM] = { blacksmithing = { "Used to make Arcanite Bar", "Mining", ARC } },
        },
    }, Routes = { guides = { { name = "Guide A" } }, materials = {
        tailoring = { [LINEN] = { 1, 1, 50, 40, 40, 0 } },
    } } }
    ns.addon = { db = { profile = copy(ns.defaults.profile) } }
    ns.invalidated = 0
    local realInvalidate = ns.Context.Invalidate
    ns.Context.Invalidate = function() ns.invalidated = ns.invalidated + 1; realInvalidate() end
    H.load("Options/Options.lua", ns)
    ns.realNotify = ns.Options.NotifyChange
    ns.Options.NotifyChange = function() end
    return ns
end

local function name(w) return type(w.name) == "function" and w.name() or w.name end
-- Text without its color codes (the pages color every line).
local function plain(t) return (tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function plainName(w) return plain(name(w)) end

-- Defaults match the spec.
local ns = fresh()
local d = ns.defaults.profile
eq(d.endgame, true, "endgame on by default")
eq(d.leveling, false, "leveling off by default")
eq(d.tooltip, true, "tooltip on by default")
eq(d.toast, false, "toast off by default")
eq(d.mask, false, "mask off by default")
eq(d.toastSound, "auction", "toast sound Auction open by default")
eq(d.toastSoundChannel, "Master", "toast sound on Master by default")
eq(d.colors.endgame.b > d.colors.endgame.g and d.colors.endgame.r > d.colors.endgame.g, true, "endgame color is purple")
eq(d.colors.leveling.g > d.colors.leveling.r and d.colors.leveling.g > d.colors.leveling.b, true, "leveling color is green")
eq(d.locations.bags and d.locations.bank and d.locations.merchant, true, "bags, bank and merchant checked")
local n = 0
for _ in pairs(d.locations) do n = n + 1 end
eq(n, 3, "only the three v1 locations (auction house, mail, loot and trade are deferred)")

-- Home: Login reminder sits after Loot toast and before Icon tint, and routes through Presentation.Set.
do
    local ns = fresh()
    local h = ns.Options.Home(1)
    eq(h.args.stockReminder.name, "Login reminder", "login reminder toggle")
    eq(h.args.stockReminder.desc, "Remind you at login when a character's bank or mailbox is not counted.", "hover text")
    eq(h.args.toast.order < h.args.stockReminder.order and h.args.stockReminder.order < h.args.mask.order, true, "after Loot toast, before Icon tint")
    local setKey, setVal
    ns.Presentation.keys["stock.reminder"] = ns.Presentation.keys["stock.reminder"] or { storage = "stockReminder" }
    local realSet = ns.Presentation.Set
    ns.Presentation.Set = function(k, v) setKey, setVal = k, v end
    h.args.stockReminder.set(nil, false)
    eq(setKey, "stock.reminder", "routes through Presentation.Set with the public key")
    eq(setVal, "off", "off")
    h.args.stockReminder.set(nil, true)
    eq(setVal, "on", "on")
    ns.Presentation.Set = realSet
    ns.Presentation.keys["stock.reminder"] = nil
    setKey = nil
    h.args.stockReminder.set(nil, false)
    eq(ns.addon.db.profile.stockReminder, false, "falls back to the profile when the key is missing")
    eq(h.args.stockReminder.get(), false, "get reads the profile")
    ns.addon.db.profile.stockReminder = true
    -- "All displays are off" ignores the reminder
    for _, k in ipairs({ "tooltip", "toast", "mask" }) do ns.addon.db.profile[k] = false end
    eq(h.args.noSurfaces.hidden(), false, "displays-off note shown with only the reminder on")
end

-- Home: Recipe order sits under Tooltip line, is disabled with it, and applies without a reload.
do
    local ns = fresh()
    local h = ns.Options.Home(1)
    local w = h.args.recipeOrder
    eq(w.type, "select", "recipe order is a dropdown")
    eq(w.name, "Recipe order", "recipe order label")
    eq(h.args.tooltip.order < w.order and w.order < h.args.toast.order, true, "right under Tooltip line")
    eq(table.concat(w.sorting, ","), "learned,unlearned,skill", "the three orders, Learned first on top")
    eq(w.values.learned, "Learned first", "Learned first label")
    eq(w.values.unlearned, "Not learned first", "Not learned first label")
    eq(w.values.skill, "Highest skill first", "Highest skill first label")
    eq(ns.defaults.profile.recipeOrder, "learned", "defaults to Learned first")
    eq(w.get(), "learned", "shows the default")
    local before = ns.invalidated
    w.set(nil, "unlearned")
    eq(ns.addon.db.profile.recipeOrder, "unlearned", "saved in the profile")
    eq(ns.invalidated > before, true, "a change applies without a reload")
    eq(w.get(), "unlearned", "shows the saved value")
    ns.addon.db.profile.recipeOrder = "bogus"
    eq(w.get(), "learned", "an unknown saved value shows Learned first")
    ns.addon.db.profile.tooltip = false
    eq(w.disabled(), true, "disabled while the tooltip line is off")
    eq(ns.addon.db.profile.recipeOrder, "bogus", "and the saved value stays the same")
    ns.addon.db.profile.tooltip = true
    eq(w.disabled(), false, "enabled with the tooltip line")
end

-- Home: every setter invalidates the context; the pages read the profile.
local home = ns.Options.Home(1)
local before = ns.invalidated
for _, key in ipairs({ "endgame", "leveling", "tooltip", "toast", "mask" }) do
    local w = home.args[key]
    eq(w.get(), d[key], key .. " toggle shows the default")
    w.set(nil, not d[key])
    eq(ns.addon.db.profile[key], not d[key], key .. " toggle writes the profile")
end
eq(ns.invalidated, before + 5, "each Home toggle invalidates the context")
eq(ns.Context.Get().settings.leveling, true, "the context sees the new setting without a reload")
local c = ns.Options.Appearance(4).args.color_endgame
c.set(nil, 0.1, 0.2, 0.3)
local r, g, b = c.get()
eq(r + g + b, 0.1 + 0.2 + 0.3, "color picker round trip")
eq(ns.invalidated, before + 6, "color setter invalidates")
home.args.locations.set(nil, "mail", true)
eq(home.args.locations.get(nil, "mail"), true, "Show marks in writes the location")
eq(ns.invalidated, before + 7, "location setter invalidates")
eq(home.args.locations.values.bags, "Bags", "locations have names")
for key in pairs(d.locations) do eq(home.args.locations.values[key] ~= nil, true, "location " .. key .. " is offered") end

-- Materials: one list (profession > material), following the Home checkboxes.
local P = ns.addon.db.profile
P.leveling = true
local mats = ns.Options.Materials(2)
eq(mats.args.title.name, "Materials", "one Materials page")
local bs = mats.args.blacksmithing
eq(bs.name, "Blacksmithing", "profession node")
local arc = bs.args["i" .. ARC]
eq(plain(name(arc)):find("Arcanite Bar", 1, true) ~= nil, true, "tree name: the item")
eq(name(arc):find("WHITE8X8", 1, true) ~= nil, true, "tree name: a swatch in the category color")
eq(arc.args.keep_endgame.get(), true, "Keep for endgame on by default")
eq(arc.args.keep_leveling, nil, "no leveling toggle for an endgame-only material")
eq(plainName(arc.args.usedEndgame), "Endgame: Blacksmithing — Essential endgame crafting material", "Used for: endgame line")
eq(name(arc.args.usedEndgame):find("|cff" .. ns.Wording.Hex(P.colors.endgame) .. "Endgame|r", 1, true) ~= nil, true, "only the category word in its color")
eq(arc.args.h_recipes.name, "Recipes that use it", "a Recipes that use it heading")
eq(plainName(arc.args.recipes):find("Arcanite Reaper — 12 per craft, skill 300", 1, true) ~= nil, true, "each recipe with quantity and skill")
eq(arc.args.recipes.name:find("|cffddddddArcanite Reaper|r", 1, true) ~= nil, true, "recipe names neutral, details grey")
eq(arc.args.h_links.name, "Wowhead link", "one Wowhead link heading")
local buttons = 0
for _, w in pairs(arc.args) do if w.type == "execute" then buttons = buttons + 1 end end
eq(buttons, 1, "one button: the item's link")
eq(arc.args.link.name, "Copy Wowhead link", "the button wording")
for _, w in pairs(arc.args) do
    local n = type(w.name) == "function" and w.name() or w.name
    eq(tostring(n):find("Vendor and drops", 1, true), nil, "no source line anywhere")
end
local copied
ns.Adapter.ShowCopyBox = function(_, url) copied = url end
arc.args.link.func()
eq(copied, "https://www.wowhead.com/classic/item=" .. ARC, "the button opens the copy box with the link")
-- Title in the item's quality color, neutral while unknown.
eq(arc.args.title.name():find("^|cffdddddd") ~= nil, true, "title neutral while the quality is unknown")
ns.Adapter.ItemQualityHex = function() return "ffa335ee" end
eq(arc.args.title.name():find("^|cffa335ee") ~= nil, true, "title in the quality color")
ns.Adapter.ItemQualityHex = nil

local linen = mats.args.tailoring.args["i" .. LINEN]
eq(plain(name(linen)):find("Linen Cloth", 1, true) ~= nil, true, "leveling material in the same list")
eq(linen.args.keep_leveling.get(), true, "Keep for leveling")
eq(plainName(linen.args.usedLeveling), "Leveling: Tailoring, skill 1-50", "Used for: leveling line")
eq(plainName(linen.args.many), "Needed for remaining Tailoring steps: 40", "How many names the profession")
eq(linen.args.h_stock.name, "Your stock", "a Your stock section")
-- Stock comes from the recorder: summary, one line per holder, ages, to-get.
local DAY = 86400
local rec = { total = 20, complete = true, rows = { { name = "Me", self = true, bags = 10, bank = 15, count = 25 } } }
ns.StockRecorder = { Total = function() if rec.unknown then return nil end return rec.total, rec.complete, rec.rows end }
rec.total = 25
eq(plainName(linen.args.stock), "25 owned, all on this character", "all on this character")
eq(plainName(linen.args.stockRows), "  This character: 10 in bags, 15 in the bank", "this character line, no age")
eq(plainName(linen.args.toGet), "Still to get: 15", "still to get: needed minus total")
eq(linen.args.toGet.hidden(), false, "shown when complete")
rec.complete = false
eq(linen.args.toGet.hidden(), true, "hidden while incomplete")
rec.complete = true
rec.total = 60; rec.rows[1].count = 25
eq(plainName(linen.args.toGet), "You have enough.", "enough: range clamps")
-- three characters, ages, singular forms
rec.total = 55
rec.rows = {
    { name = "Me", self = true, bags = 12, bank = 8, count = 20, age = 7200 },
    { name = "Bankmule", bank = 30, count = 30, age = 3 * DAY + 5 },
    { name = "Hunter", mail = 5, count = 5, age = 60 },
}
eq(plainName(linen.args.stock), "55 owned - 20 on this character, 35 on your other characters", "split summary")
eq(plainName(linen.args.stockRows),
    "  This character: 12 in bags, 8 in the bank\n  Bankmule: 30 in the bank (3 days ago)\n  Hunter: 5 in the mailbox (1 minute ago)",
    "three holder lines with ages")
eq(name(linen.args.stockRows):find("|cff999999(3 days ago)|r", 1, true) ~= nil, true, "age in grey")
eq(linen.args.stockRows.hidden(), false, "rows shown")
rec.rows[3].age = 3600; rec.rows[2].age = 5 * 3600
eq(plainName(linen.args.stockRows):find("Bankmule: 30 in the bank (5 hours ago)", 1, true) ~= nil, true, "plural hours")
eq(plainName(linen.args.stockRows):find("(1 hour ago)", 1, true) ~= nil, true, "singular hour")
rec.rows[3].age = DAY; rec.rows[2].age = 120
eq(plainName(linen.args.stockRows):find("(1 day ago)", 1, true) ~= nil, true, "singular day")
eq(plainName(linen.args.stockRows):find("(2 minutes ago)", 1, true) ~= nil, true, "plural minutes")
-- a holder appears and disappears without rebuilding the tree
rec.rows[4] = { name = "Zed", bags = 1, count = 1, age = 60 }; rec.total = 56
eq(plainName(linen.args.stockRows):find("Zed: 1 in bags", 1, true) ~= nil, true, "new holder shows without a rebuild")
rec.rows[4] = nil; rec.total = 55
eq(plainName(linen.args.stockRows):find("Zed", 1, true), nil, "removed holder disappears")
-- summary variants
rec.total = 30; rec.rows = { { name = "Bankmule", bank = 30, count = 30, age = 60 } }
eq(plainName(linen.args.stock), "30 owned, all on your other characters", "all elsewhere")
rec.total = 0; rec.rows = {}
rec.complete = true
eq(plainName(linen.args.stock), "None on any of your characters.", "none anywhere")
rec.complete = false
eq(plainName(linen.args.stock), "None counted yet.", "none counted while incomplete")
rec.complete = true
eq(linen.args.stockRows.hidden(), true, "no rows when nobody holds it")
-- incomplete range clamp: Still to get 0-15 style
rec.total = 25; rec.rows = { { name = "Me", self = true, bags = 25, count = 25 } }
eq(plainName(linen.args.toGet), "Still to get: 15", "need 40 minus 25")
-- unknown stock: live bags fallback, no to-get
rec.unknown = true
ns.Adapter.ItemCount = function() return 10 end
eq(plainName(linen.args.stock), "10 in bags", "unknown recorder falls back to live bags")
eq(linen.args.toGet.hidden(), true, "to-get hidden when unknown")
ns.Adapter.ItemCount = nil
eq(plainName(linen.args.stock), "Your stock is not known yet.", "no count API")
-- Review #4: a guide whose only steps left give no count: no count line, never "You have enough."
do
    local u = fresh({ skills = { tailoring = 75 } })
    u.Data.Routes.materials.tailoring[LINEN] = { 1, 1, 50, 40, 40, 0, 1, 75, 100, 0, 0, 0 }
    u.Context.Invalidate()
    local l = u.Options.Materials(2).args.tailoring.args["i" .. LINEN]
    u.StockRecorder = { Total = function() return 60, true, { { name = "Me", self = true, bags = 60, count = 60 } } end }
    eq(plainName(l.args.many), "No count in the guides for these steps.", "uncounted steps ahead: no count")
    eq(l.args.toGet.hidden(), true, "no to-get line")
    eq(plainName(l.args.toGet):find("enough", 1, true), nil, "never You have enough")
end
-- Review #12: a material only Profession Journal uses leaves the tree and /kt find when it is turned off,
-- and comes back when it is turned on, without a reload.
do
    local p = fresh()
    local DYE = 2325
    p.Data.Catalog.itemNames[DYE] = "Black Dye"
    local on = true
    p.ProfessionJournal = { PROFESSIONS = { "leatherworking" }, On = function() return on end,
        Items = function() return on and { DYE } or {} end }
    p.Context.extra = function() return nil end
    p.Context.Invalidate()
    local function inTree() local lw = p.Options.Tree().args.materials
        lw = lw and lw.args and lw.args.leatherworking
        return lw ~= nil and lw.args["i" .. DYE] ~= nil end
    eq(#p.Options.Find("black dye"), 1, "on: /kt find finds it")
    local first = p.Options.Tree()
    eq(p.Options.Tree(), first, "unchanged: the tree is not rebuilt")
    eq(inTree(), true, "on: in the Materials tree")
    on = false
    eq(#p.Options.Find("black dye"), 0, "off: /kt find does not")
    eq(p.Options.Tree() ~= first, true, "off: the tree is rebuilt")
    eq(inTree(), false, "off: not in the Materials tree")
    on = true
    eq(#p.Options.Find("black dye"), 1, "back on: found again")
    eq(inTree(), true, "back on: in the tree again")
end
local function scan(node, seen)
    if type(node) ~= "table" then return end
    for k, v in pairs(node) do
        if k == "name" or k == "desc" then
            local t = type(v) == "function" and v() or v
            if type(t) == "string" then
                eq(t:lower():find("open your bank", 1, true), nil, "no bank prompt: " .. t)
                eq(t:lower():find("bank count updates", 1, true), nil, "no bank count help: " .. t)
            end
        elseif type(v) == "table" then scan(v) end
    end
end
rec.unknown = nil
scan(linen)
eq(linen.args.stockHelp, nil, "stockHelp removed")
eq(ns.Options.bankSeen, nil, "bankSeen gone")

-- Toggles write disabled[...] (shared by every profession) and invalidate.
before = ns.invalidated
arc.args.keep_endgame.set(nil, false)
eq(P.disabled.endgame[ARC], true, "turning off stores disabled.endgame[id] = true")
eq(ns.invalidated, before + 1, "material toggle invalidates")
arc.args.keep_endgame.set(nil, true)
eq(P.disabled.endgame[ARC], nil, "turning back on removes the entry")
linen.args.keep_leveling.set(nil, false)
eq(P.disabled.leveling[LINEN], true, "leveling toggle writes disabled.leveling")
linen.args.keep_leveling.set(nil, true)

-- The list follows Home: endgame only hides leveling-only items; neither shows all with a note.
P.endgame, P.leveling = true, false
eq(linen.hidden(), true, "leveling off: a leveling-only material is not listed")
eq(mats.args.tailoring.hidden(), true, "and a profession with nothing left is hidden")
eq(arc.hidden(), false, "endgame materials stay")
eq(arc.args.keepOff_endgame.hidden(), true, "no off-note while endgame is on")
P.endgame = false
eq(linen.hidden(), false, "both off: everything is listed")
eq(mats.args.none.hidden(), false, "with a note that nothing is marked")
eq(arc.args.keepOff_endgame.hidden(), false, "the material page says endgame marks are off")
P.endgame, P.leveling = true, true

-- Profession page: count, and an export button per category it has.
eq(plain(bs.args.count.name()), "2 materials", "material count")
eq(bs.args.exportEndgame.name, "Export endgame list", "endgame export button")
eq(bs.args.exportLeveling.hidden(), true, "no leveling export without leveling materials")
eq(mats.args.tailoring.args.exportLeveling.hidden(), false, "leveling export where there are leveling materials")

-- Toggles survive a catalog update that adds a material.
P.disabled.endgame[THORIUM] = true
ns.Data.Catalog.endgame[99999] = { blacksmithing = { "New material", "Drops", 0 } }
ns.Data.Catalog.itemNames[99999] = "New Thing"
ns.Context.Invalidate()
local ends = ns.Options.Materials(2).args.blacksmithing.args
eq(ends.i99999.args.keep_endgame.get(), true, "a new material starts on")
eq(ends["i" .. THORIUM].args.keep_endgame.get(), false, "a material the player turned off stays off")

-- Search: one box, literal and case-insensitive, client and English names; it can be cleared from
-- the Materials page or any profession page.
local searchNS = fresh()
searchNS.addon.db.profile.leveling = true
local refreshed = 0
searchNS.Options.NotifyChange = function() refreshed = refreshed + 1 end
searchNS.Adapter.ItemName = function(id) if id == ARC then return "Localized % Bar." end end
local tree = searchNS.Options.Materials(2)
local input = tree.args.search
local smith = tree.args.blacksmithing
eq(tree.args.clearSearch.hidden(), true, "no Clear search button without a search")
input.set(nil, "LOCALIZED")
eq(input.width, "full", "search spans the page")
eq(smith.args.i12360.hidden(), false, "client name matches without case")
eq(smith.args.i12359.hidden(), true, "other materials hidden")
eq(smith.hidden(), false, "matching profession visible")
eq(plain(smith.args.count.name()), "1 of 2 materials match your search.", "the profession page counts matches")
eq(smith.args.searchBanner.hidden(), false, "the profession page says a search is active")
eq(smith.args.clearSearch.hidden(), false, "and offers Clear search")
input.set(nil, "arCANite")
eq(smith.args.i12360.hidden(), false, "English name matches even with a client name")
for _, query in ipairs({ "%", "." }) do
    input.set(nil, query)
    eq(smith.args.i12360.hidden(), false, "special character matches literally")
    eq(smith.args.i12359.hidden(), true, "special character is not a pattern")
end
input.set(nil, "missing")
eq(smith.hidden(), true, "empty profession hidden")
eq(tree.args.noMatches.hidden(), false, "no-match line visible")
eq(plainName(tree.args.noMatches), 'No materials match "missing".', "no-match sentence")
smith.args.clearSearch.func()
eq(input.get(), "", "Clear search on a profession page clears it")
eq(smith.args.i12359.hidden(), false, "and shows every material again")
eq(tree.args.noMatches.hidden(), true, "no-match line hidden again")
local found = searchNS.Options.Find("bar")
eq(#found, 2, "find searches material paths")
eq(found[1].itemID, ARC, "find sorts by client name")
eq(found[1].categoryName, "Materials", "find paths are in Materials")
eq(#searchNS.Options.Find("%"), 1, "find shares literal matching")

-- Integrations on WoW Forever: a toggle named after each addon, a short grey status line under it.
local integ = ns.Options.Integrations(3)
eq(integ.args.use_bagnon.name, "Bagnon", "the toggle is named after the addon")
eq(integ.args.era, nil, "no Classic Era line on Forever")
eq(integ.args.use_bagnon.get(), true, "integration toggle on by default")
eq(plain(name(integ.args.status_bagnon)), "Status not known yet.", "no Status function: state unknown, no error")
ns.Integrations = { Status = function(k)
    if k == "bagnon" then return { detected = false } end
    if k == "baganator" then return { detected = true, working = true } end
    if k == "ellesmereui" then return { detected = true, working = false, reason = "off" } end
    if k == "professionjournal" then return { detected = true, working = false, reason = "not started" } end
    return { detected = true, working = false, reason = "failed: hook failed" }
end }
eq(plain(name(integ.args.status_bagnon)), "Not detected.", "not installed")
eq(plain(name(integ.args.status_baganator)), "Detected and working.", "working")
eq(name(integ.args.status_auctionator), "|cffd9a066Stopped after an error. See /kt log.|r", "a failure is short and amber; the reason is in /kt log")
eq(ns.Options.StatusText("auctionator"), "Stopped after an error: hook failed", "the full reason is still available")
eq(plain(name(integ.args.status_ellesmereui)), "Detected, turned off here.", "turned off")
eq(plain(name(integ.args.status_professionjournal)), "Detected, starts when its setting is on.", "not started")
before = ns.invalidated
integ.args.use_bagnon.set(nil, false)
eq(ns.addon.db.profile.integrations.bagnon, false, "integration toggle writes the profile")
eq(ns.invalidated, before + 1, "integration toggle invalidates")
local names = {}
for _, row in ipairs(ns.Options.INTEGRATIONS) do names[#names + 1] = row.name end
eq(table.concat(names, "|"), "Baganator|Bagnon|EllesmereUI Bags|Auctionator|DFL Profession Journal", "the five integrations")

-- Estimate leveling cost (spec settings): a toggle under the Auctionator row, off by default, disabled with a reason.
do
    local box = integ.args.options_auctionator
    eq(box.type, "group", "the estimate controls sit in a box under the Auctionator row")
    eq(box.inline, true, "the box is inline, part of the page")
    eq(box.name, "Auctionator options", "the box is named after the addon")
    eq(box.order > integ.args.status_auctionator.order and box.order < integ.args.use_professionjournal.order, true, "the box sits between the Auctionator row and the next integration")
    local est = integ.args.options_auctionator.args.estimateLevelingCost
    eq(est.name, "Estimate leveling cost", "the estimate toggle is named")
    eq(est.get(), false, "the estimate is off by default")
    ns.AuctionatorExport = { EstimateReason = function() return "Auctionator is needed." end }
    eq(est.disabled(), true, "disabled while the estimate cannot be used")
    eq(integ.args.options_auctionator.args.why_estimate.hidden(), false, "the reason shows")
    eq(plain(name(integ.args.options_auctionator.args.why_estimate)), "Auctionator is needed.", "and says why")
    eq(integ.args.options_auctionator.args.help_estimate.hidden(), true, "no action help while the control is disabled")
    ns.AuctionatorExport = { EstimateReason = function() return nil end }
    eq(est.disabled(), false, "enabled while the estimate can be used")
    eq(integ.args.options_auctionator.args.why_estimate.hidden(), true, "no reason when enabled")
    eq(integ.args.options_auctionator.args.help_estimate.hidden(), false, "the action help shows when enabled")
    eq(plain(name(integ.args.options_auctionator.args.help_estimate)), "The profession page shows the estimated cost of the leveling list. Hold Shift over a material to see the estimated cost of the amount you still need.", "the help says both places")
    ns.AuctionatorExport = nil
    eq(est.disabled(), true, "no export module: disabled")
    before = ns.invalidated
    est.set(nil, true)
    eq(ns.addon.db.profile.estimateLevelingCost, true, "the toggle writes the profile")
    eq(ns.invalidated, before + 1, "the toggle refreshes the presentation")
    est.set(nil, false)
    eq(ns.addon.db.profile.estimateLevelingCost, false, "and turns off again")
    -- The estimate line on a profession page: hidden until there is something to show.
    local page = ns.Options.Materials(2).args.tailoring
    ns.AuctionatorExport = { Available = function() return true end, EstimateLines = function() return nil end }
    eq(page.args.exportEstimate.hidden(), true, "no estimate: the line is hidden")
    eq(page.args.exportEstimateGap.hidden(), true, "no estimate: no blank line either")
    eq(page.args.exportEstimate.order < page.args.h_shop.order, true, "the estimate is above the Shopping list section")
    eq(page.args.exportEstimateGap.order > page.args.exportEstimate.order and page.args.exportEstimateGap.order < page.args.h_shop.order, true, "a blank line separates the estimate from the Shopping list header")
    ns.AuctionatorExport.EstimateLines = function() return { "At least 10g from Auctionator's last scan.", "One material could not be priced." } end
    eq(page.args.exportEstimate.hidden(), false, "an estimate shows the line")
    eq(page.args.exportEstimateGap.hidden(), false, "and the blank line above it")
    eq(plain(name(page.args.exportEstimate)), "At least 10g from Auctionator's last scan. One material could not be priced.", "the sentences read together")
    ns.AuctionatorExport = nil
end

-- Integrations on Classic Era.
local era = fresh({ client = "era" })
local ip = era.Options.Integrations(3)
eq(plainName(ip.args.era), "Integrations are not yet available on Classic Era.", "Classic Era line")
eq(ip.args.use_baganator.disabled(), true, "toggles are disabled on Classic Era")
eq(ip.args.status_baganator, nil, "the message shows once, not under every addon")

-- Advanced: per-character profile toggle.
local current, switched = "Default", {}
ns.addon.db.GetCurrentProfile = function() return current end
ns.addon.db.SetProfile = function(_, p) current = p; switched[#switched + 1] = p end
ns.addon.db.keys = { char = "Pauly - Realm" }
local adv = ns.Options.Advanced(4)
eq(adv.args.charProfile.get(), false, "starts on the account profile")
before = ns.invalidated
adv.args.charProfile.set(nil, true)
eq(current, "Pauly - Realm", "switches to the character's profile")
adv.args.charProfile.set(nil, false)
eq(current, "Default", "and back to Default")
eq(ns.invalidated, before + 2, "profile switches invalidate")
adv.args.debug.set(nil, true)
eq(ns.addon.db.profile.debug, true, "debug toggle writes the profile")

-- About and the whole tree.
local about = ns.Options.About(6)
eq(about.args.title.name, "KeepThat", "about: the name, large")
eq(plain(about.args.version.name), "Version 9.9.9", "the version, small and grey")
eq(about.args.guide, nil, "no line listing the pages; the tree already names them")
eq(about.args.cmd_kt.name, "|cffdddddd/kt|r  |cffaaaaaaOpen these settings.|r", "one command per line, neutral then grey")
local tree = ns.Options.Build()
for _, k in ipairs({ "home", "materials", "integrations", "advanced", "about" }) do eq(tree.args[k] ~= nil, true, "page " .. k) end

-- Registration runs from ns.Start with the Ace libraries.
local registered, bliz, selected, opened = {}, {}, {}, 0
local callbacks = {}
local notified
-- One shared AceConfigDialog fake, so its session tree state survives between calls.
local treeGroups = {}
local collapsedAtOpen
local fakeAce = {
    Status = { KeepThat = { status = { groups = { groups = treeGroups } }, children = {} } },
    SetDefaultSize = function() end,
    AddToBlizOptions = function(_, app, title, parent, path)
        bliz[#bliz + 1] = (app ~= "KeepThat" and app .. ":" or "") .. title .. ">" .. tostring(parent) .. ">" .. tostring(path)
    end,
    Open = function() opened = opened + 1; collapsedAtOpen = treeGroups["materials\001tailoring"] == nil end,
    SelectGroup = function(_, app, ...) selected[#selected + 1] = table.concat({...}, "/") end,
}
_G.LibStub = function(lib)
    if lib == "AceConfigRegistry-3.0" then
        return { RegisterOptionsTable = function(_, app, o) registered[app] = o end,
            NotifyChange = function(_, app) notified = app end }
    end
    return fakeAce
end
ns.addon.db.RegisterCallback = function(_, event) callbacks[#callbacks + 1] = event end
eq(#ns.started, 1, "Options registers one starter")
ns.started[1](ns.addon)
eq(type(registered.KeepThat), "function", "options table registered")
eq(registered.KeepThat().args.home ~= nil, true, "registered table has the pages")
eq(bliz[1], "KeepThat>nil>home", "Home is the AddOns entry")
eq(bliz[2], "KeepThat Materials:Materials>KeepThat>nil", "Materials in the game's Settings window is the launcher")
eq(bliz[3], "Integrations>KeepThat>integrations", "sub pages are listed under it")
eq(bliz[6], "About>KeepThat>about", "in the same order")
eq(#bliz, 6, "six pages")
eq(type(registered["KeepThat Materials"]), "table", "launcher table registered")
local launcher = registered["KeepThat Materials"]
eq(launcher.args.open.name, "Open KeepThat", "launcher offers Open KeepThat")
for _, w in pairs(launcher.args) do eq(w.type ~= "group", true, "launcher holds no material tree") end
local closedSettings = 0
ns.Adapter.CloseGameSettings = function() closedSettings = closedSettings + 1 end
launcher.args.open.func()
eq(closedSettings, 1, "Open KeepThat closes the game's Settings window")
eq(selected[#selected], "materials", "and opens KeepThat on Materials")
eq(opened, 1, "the KeepThat window opened")
opened, selected = 0, {}
eq(#callbacks, 3, "profile callbacks registered")
ns.Options.Open()
eq(opened, 1, "Open opens the dialog")
eq(selected[1], "home", "on the Home page")
ns.realNotify()
eq(notified, "KeepThat", "search refresh notifies the KeepThat registry")
-- Professions under Materials start collapsed; other open nodes and Materials itself stay.
-- AceConfigDialog's own layout: the tree's status is Status[app].status.groups, expanded nodes in its .groups.
local fakeDialog = { Status = { KeepThat = {
    status = { groups = { selected = "materials", groups = { materials = true, ["materials\001blacksmithing"] = true,
        ["materials\001blacksmithing\001i12360"] = true, appearance = true } } },
    children = {},
} } }
ns.Options.CollapseMaterials(fakeDialog)
local tree = fakeDialog.Status.KeepThat.status.groups.groups
eq(tree["materials\001blacksmithing"], nil, "profession under Materials collapses")
eq(tree["materials\001blacksmithing\001i12360"], nil, "nested node collapses")
eq(tree.materials, true, "Materials itself keeps its state")
eq(tree.appearance, true, "other pages keep their state")
eq(fakeDialog.Status.KeepThat.status.groups.selected, "materials", "the selected page is kept")
ns.Options.CollapseMaterials({})
ns.Options.CollapseMaterials(nil)
treeGroups["materials\001tailoring"] = true
ns.Options.OpenMaterial({ category = "endgame", profession = "blacksmithing", itemID = ARC })
eq(collapsedAtOpen, true, "opening a material collapses the other professions first")
eq(opened, 2, "material opens dialog")
eq(selected[2], "materials/blacksmithing/i12360", "material selects complete path")
-- /kt find with several matches: Materials filtered, only professions with a visible match expanded.
treeGroups["materials\001tailoring"] = true
ns.Options.OpenSearch("arcanite bar", { { profession = "blacksmithing", visible = true },
    { profession = "engineering" }, { profession = "alchemy", visible = false } })
eq(treeGroups["materials\001blacksmithing"], true, "a profession with a match is expanded")
eq(treeGroups["materials\001engineering"], true, "every one with a match")
eq(treeGroups["materials\001alchemy"], nil, "one whose match is hidden by Home is not")
eq(treeGroups["materials\001tailoring"], nil, "others are collapsed")
eq(selected[#selected], "materials", "the window opens on Materials")
eq(ns.Options.Materials(2).args.search.get(), "arcanite bar", "with the search set to the query")
ns.Options.ClearSearch()
-- Page context follows current scope and feature state, including nested pages.
local contextual = ns.Options.Build()
for _, key in ipairs({ "home", "materials", "integrations", "appearance", "about" }) do
    eq(contextual.args[key].args.scope, nil, key .. " does not repeat scope notice")
end
eq(contextual.args.advanced.args.scope, nil, "scope appears in Advanced context, not a repeated notice")
eq(contextual.args.advanced.args.profileContext ~= nil, true, "Advanced explains profile scope and effect")
local appearance = contextual.args.appearance.args
ns.addon.db.profile.toast = false
eq(appearance.toastHelp.hidden(), false, "disabled toast has visible next step")
ns.addon.db.profile.toast = true
eq(appearance.toastHelp.hidden(), true, "enabled toast hides obsolete enabling instruction")
ns.addon.db.profile.toastLocked = true
eq(plainName(appearance.positionHelp):find("Position is locked", 1, true) ~= nil, true, "locked context explains prerequisite")
ns.addon.db.profile.toastLocked = false
ns.Toast = { move = {} }
eq(plainName(appearance.positionHelp):find("Move is active", 1, true) ~= nil, true, "active Move context explains save and rollback")
ns.Toast.move = nil
eq(plainName(appearance.positionHelp):find("Reset position", 1, true) ~= nil, true, "idle context explains reset scope")
eq(appearance.previewTooltip.name, "Preview item tooltip", "preview identifies its surface")
eq(contextual.args.materials.args.blacksmithing.args.scope, nil, "profession page does not repeat scope")
eq(contextual.args.materials.args.blacksmithing.args.i12360.args.scope, nil, "material page does not repeat scope")
_G.LibStub = nil

-- Appearance > Loot toast: Sound and Sound channel pickers (spec settings, "Toast sound picker").
do
    local ns = fresh()
    local plays, packs = {}, nil
    ns.Adapter.SoundPacks = function() return packs end
    ns.Adapter.PlaySound = function(id, ch) plays[#plays + 1] = { id, ch }; return true end
    ns.Adapter.PlaySoundFile = function(p, ch) plays[#plays + 1] = { p, ch }; return true end
    local a = ns.Options.Appearance(4).args
    local s, c = a.toastSound, a.toastSoundChannel
    eq(s.type, "select", "sound is a dropdown")
    eq(s.order > a.scale.order and c.order == s.order + 1, true, "after Scale, then channel")
    local order = s.sorting()
    eq(#order, 11, "None and ten sounds without the library")
    eq(order[1], "none", "None first"); eq(order[2], "auction", "Auction open next"); eq(order[8], "murloc", "Murloc aggro listed")
    eq(s.values().murloc, "Murloc aggro", "label")
    packs = { ["Air Horn"] = "horn.ogg" }
    order = s.sorting()
    eq(order[12], "lsm:Air Horn", "sound pack after the built-in sounds")
    eq(s.values()["lsm:Air Horn"], "Air Horn (sound pack)", "pack label")
    eq(s.get(), "auction", "default shown")

    -- Choosing plays once and saves; None saves and plays nothing.
    s.set(nil, "levelup")
    eq(ns.addon.db.profile.toastSound, "levelup", "saved"); eq(#plays, 1, "played once"); eq(plays[1][1], 888, "the chosen sound")
    eq(plays[1][2], "Master", "on the chosen channel")
    s.set(nil, "none")
    eq(ns.addon.db.profile.toastSound, "none", "None saved"); eq(#plays, 1, "None plays nothing")

    -- A saved pack that is gone shows the default without overwriting the saved choice.
    ns.addon.db.profile.toastSound = "lsm:Air Horn"
    eq(s.get(), "lsm:Air Horn", "present pack shown")
    packs = nil
    eq(s.get(), "auction", "missing pack shows Auction open")
    eq(ns.addon.db.profile.toastSound, "lsm:Air Horn", "saved choice kept")

    -- Channel.
    eq(c.values.Master, "Master", "Master label"); eq(c.values.SFX, "Sound effects", "Sound effects label")
    eq(c.get(), "Master", "Master by default")
    c.set(nil, "SFX"); eq(ns.addon.db.profile.toastSoundChannel, "SFX", "channel saved"); eq(c.get(), "SFX", "shown")

    -- Disabled while the toast is off, like opacity and scale.
    ns.addon.db.profile.toast = false
    eq(s.disabled(), true, "sound disabled with toast off"); eq(c.disabled(), true, "channel disabled with toast off")
    ns.addon.db.profile.toast = true
    eq(s.disabled(), false, "enabled with toast on")
end

H.done()
