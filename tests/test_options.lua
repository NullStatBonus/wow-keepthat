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
    H.load("Model/Leveling.lua", ns)
    H.load("Model/Classify.lua", ns)
    H.load("Model/Wording.lua", ns)
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
eq(d.colors.endgame.b > d.colors.endgame.g and d.colors.endgame.r > d.colors.endgame.g, true, "endgame color is purple")
eq(d.colors.leveling.g > d.colors.leveling.r and d.colors.leveling.g > d.colors.leveling.b, true, "leveling color is green")
eq(d.locations.bags and d.locations.bank and d.locations.merchant, true, "bags, bank and merchant checked")
local n = 0
for _ in pairs(d.locations) do n = n + 1 end
eq(n, 3, "only the three v1 locations (auction house, mail, loot and trade are deferred)")

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
local c = home.args.color_endgame
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
ns.Adapter.ItemCount = function(_, bank) return bank and 25 or 10 end
eq(plainName(linen.args.stock), "10 in bags, 15 in the bank", "bags and bank")
eq(plainName(linen.args.toGet), "Still to get: 15", "still to get: needed minus bags and bank")
ns.Adapter.ItemCount = function(_, bank) return bank and 60 or 10 end
eq(plainName(linen.args.toGet), "You have enough.", "enough on hand")
ns.Adapter.ItemCount = function() return 10 end
eq(linen.args.toGet.hidden(), true, "no shortfall while the bank is not known")
eq(plainName(linen.args.stock), "10 in bags (open your bank to count it)", "a bank of 0 is not trusted before the bank is opened")
ns.Options.bankSeen = true
eq(plainName(linen.args.stock), "10 in bags, 0 in the bank", "after the bank was opened, 0 is real")
ns.Options.bankSeen = nil
ns.Adapter.ItemCount = nil
eq(plainName(linen.args.stock), "Your stock is not known yet.", "no count API")
eq(linen.args.toGet.hidden(), true, "no shortfall while the stock is unknown")

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
eq(about.args.cmd_kt.name, "|cffdddddd/kt|r  |cffaaaaaaOpen these settings.|r", "one command per line, neutral then grey")
local tree = ns.Options.Build()
for _, k in ipairs({ "home", "materials", "integrations", "advanced", "about" }) do eq(tree.args[k] ~= nil, true, "page " .. k) end

-- Registration runs from ns.Start with the Ace libraries.
local registered, bliz, selected, opened = {}, {}, {}, 0
local callbacks = {}
local notified
_G.LibStub = function(lib)
    if lib == "AceConfigRegistry-3.0" then
        return { RegisterOptionsTable = function(_, app, o) registered[app] = o end,
            NotifyChange = function(_, app) notified = app end }
    end
    return {
        AddToBlizOptions = function(_, app, title, parent, path) bliz[#bliz + 1] = title .. ">" .. tostring(parent) .. ">" .. path end,
        Open = function() opened = opened + 1 end,
        SelectGroup = function(_, app, ...) selected[#selected + 1] = table.concat({...}, "/") end,
    }
end
ns.addon.db.RegisterCallback = function(_, event) callbacks[#callbacks + 1] = event end
eq(#ns.started, 1, "Options registers one starter")
ns.started[1](ns.addon)
eq(type(registered.KeepThat), "function", "options table registered")
eq(registered.KeepThat().args.home ~= nil, true, "registered table has the pages")
eq(bliz[1], "KeepThat>nil>home", "Home is the AddOns entry")
eq(bliz[2], "Materials>KeepThat>materials", "sub pages are listed under it")
eq(#bliz, 5, "five pages")
eq(#callbacks, 3, "profile callbacks registered")
ns.Options.Open()
eq(opened, 1, "Open opens the dialog")
eq(selected[1], "home", "on the Home page")
ns.Options.NotifyChange()
eq(notified, "KeepThat", "search refresh notifies the KeepThat registry")
ns.Options.OpenMaterial({ category = "endgame", profession = "blacksmithing", itemID = ARC })
eq(opened, 2, "material opens dialog")
eq(selected[2], "materials/blacksmithing/i12360", "material selects complete path")
_G.LibStub = nil

H.done()
