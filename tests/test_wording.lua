-- Model/Wording.lua against the material-tooltip scenarios.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ns = H.locale({})
H.load("Model/RecipeKnowledge.lua", ns)
H.load("Model/Wording.lua", ns)
local W = ns.Wording

-- One line, by category.
eq(W.Line({ endgame = { { profession = "blacksmithing" } } }), "Endgame: Blacksmithing", "endgame line")
eq(select(2, W.Line({ endgame = { { profession = "blacksmithing" } } })), "endgame", "endgame kind")
eq(W.Line({ leveling = { { profession = "tailoring" } } }), "Leveling: Tailoring", "leveling line")
eq(W.Line(nil), nil, "unmarked: no line")
eq(W.Line({}), nil, "empty result: no line")

-- Several professions: two by name, then +N.
eq(W.Line({ endgame = { { profession = "blacksmithing" }, { profession = "alchemy" } } }),
    "Endgame: Alchemy, Blacksmithing", "two professions, by name")
eq(W.Line({ endgame = { { profession = "alchemy" }, { profession = "blacksmithing" }, { profession = "tailoring" },
    { profession = "engineering" } } }), "Endgame: Alchemy, Blacksmithing +2", "four professions")

-- Both categories, one profession listed once.
local line, kind = W.Line({ endgame = { { profession = "blacksmithing" } }, leveling = { { profession = "blacksmithing" } } })
eq(line, "Endgame + Leveling: Blacksmithing", "both categories")
eq(kind, "both", "both kind (shown in the endgame color)")
eq(W.Line({ endgame = { { profession = "firstaid" } } }), "Endgame: First Aid", "display name")

-- The client's own profession names win over the English ones (localization fix 2).
W.UseClientNames({ blacksmithing = "Schmiedekunst" })
eq(W.Line({ endgame = { { profession = "blacksmithing" } } }), "Endgame: Schmiedekunst", "client name used")
eq(W.Line({ endgame = { { profession = "alchemy" } } }), "Endgame: Alchemy", "missing client name: English")
W.UseClientNames(nil)
eq(W.Display("blacksmithing"), "Blacksmithing", "reset to English")

-- Counts.
eq(W.Count({ low = 40, high = 40 }), "40", "agree")
eq(W.Count({ low = 40, high = 55 }), "40-55", "differ")
eq(W.Count({}), nil, "no count")

-- Details: leveling with the intermediate share, carried count and guides.
local RUNE, BOLT = 14047, 14048
local ctx = {
    itemID = RUNE,
    catalog = { itemNames = { [RUNE] = "Runecloth", [BOLT] = "Bolt of Runecloth" }, recipes = {}, endgame = {} },
    routes = { materials = { tailoring = { [RUNE] = {}, [BOLT] = {} } } },
    carried = function() return 12 end,
}
-- Shift details: a block per category and profession (Codex style review).
local d = W.Details({ leveling = { { profession = "tailoring",
    need = { low = 600, high = 1195, from = 260, to = 300, via = { [BOLT] = 956, [77] = 239 }, sources = { "A", "B" } } } } }, ctx)
eq(d[1].text, "  Leveling - Tailoring, skill 260-300", "leveling heading")
eq(d[1].kind, "leveling", "in the leveling color")
eq(d[2].text, "    600-1195 needed, 12 in bags", "count and bags")
eq(d[2].kind, "body", "neutral")
eq(d[3].text, "    Includes 956 for Bolt of Runecloth", "the intermediate share")
eq(d[3].kind, "note", "grey")
eq(d[4].text, "    Guides: A, B", "guides named")
d = W.Details({ leveling = { { profession = "tailoring", need = { low = 40, high = 40, from = 260, to = 300, sources = {} } } } },
    { itemID = RUNE, catalog = ctx.catalog, routes = ctx.routes })
eq(d[2].text, "    40 needed", "no bag count")
d = W.Details({ leveling = { { profession = "tailoring", need = { from = 1, to = 50, sources = { "A" } } } } }, ctx)
eq(#d, 2, "no count: the heading and the guides only")

-- Shortfall cost (ctx.cost): a line at the end of the leveling block; no line when the input gives nothing.
do
    local result = { leveling = { { profession = "tailoring", need = { low = 40, high = 40, from = 260, to = 300, sources = { "A" } } } } }
    local function with(cost)
        return W.Details(result, { itemID = RUNE, catalog = ctx.catalog, routes = ctx.routes, carried = ctx.carried,
            cost = function(id, profession) eq(id, RUNE, "cost is asked for the hovered item"); eq(profession, "tailoring", "and the profession"); return cost end })
    end
    local lines = with({ quantity = 28, cost = "14g" })
    eq(lines[2].text, "    40 needed, 12 in bags", "the count comes first")
    eq(lines[3].text, "    Estimated cost for 28: 14g, from Auctionator's last scan.", "the cost line is directly below the count")
    eq(lines[3].kind, "body", "cost line is neutral")
    eq(lines[#lines].text, "    Guides: A", "the guides stay last")
    lines = with({ quantity = 28 })
    eq(lines[3].text, "    No recent Auctionator price for this item.", "no price: says so, no amount")
    eq(#with(nil), 3, "no cost input result: no cost line")
    eq(#with({ quantity = 0, cost = "0s" }), 3, "nothing still needed: no cost line")
    eq(#W.Details(result, { itemID = RUNE, catalog = ctx.catalog, routes = ctx.routes, carried = ctx.carried }), 3, "no cost input: no cost line")
end

-- Endgame block: purpose, recipes, and chains.
local ARC, CRYSTAL, ORE, BAR = 12360, 12363, 10620, 12359
local cat = {
    itemNames = { [ARC] = "Arcanite Bar", [BAR] = "Thorium Bar" },
    spellNames = { [1] = "Arcanite Reaper", [2] = "Lionheart Helm", [3] = "Low Thing", [4] = "Mid Thing" },
    recipes = {
        [1] = { p = "blacksmithing", learn = 300, r = { ARC, 12 }, y = 300, gy = 320 },
        [2] = { p = "blacksmithing", learn = 300, r = { ARC, 12, 1, 1 }, y = 300, gy = 320 },
        [3] = { p = "blacksmithing", learn = 1, r = { ARC, 1 }, y = 200, gy = 220 },
        [4] = { p = "blacksmithing", learn = 1, r = { ARC, 2 }, y = 250, gy = 270 },
    },
    endgame = { [BAR] = { blacksmithing = { "Used to make Arcanite Bar", "s", ARC } } },
}
d = W.Details({ endgame = { { profession = "blacksmithing", reason = "Best-in-slot crafted gear" } } }, { catalog = cat, itemID = ARC })
eq(d[1].text, "  Endgame - Blacksmithing", "endgame heading")
eq(d[2].text, "    Best-in-slot crafted gear", "the purpose")
eq(d[3].text, "    Arcanite Reaper - 12 per craft", "highest yellow rank first, per craft")
eq(d[5].text, "    Mid Thing - 2 per craft", "three recipes at most")
eq(d[6].text, "    and 1 more recipes", "the rest counted")
eq(#d, 6, "no status and no hint without recipe knowledge")

-- Recipe status (material-tooltip "Recipe status on endgame recipe lines"): grey text, the difficulty word colored.
local YELLOW, GREEN, GRAY = "|cffffff00Yellow|r", "|cff40bf40Green|r", "|cff808080Gray|r"
eq(W.RecipeStatus({ learned = true, difficulty = "yellow" }), "Learned · " .. YELLOW, "learned and still raising skill")
eq(W.RecipeStatus({ learned = true, difficulty = "gray" }), "Learned · " .. GRAY, "learned but gray")
eq(W.RecipeStatus({ learned = true }), "Learned", "learned, difficulty unknown")
eq(W.RecipeStatus({ learned = false }), "Not learned", "not learned, below yellow: no difficulty word")
eq(W.RecipeStatus({ learned = false, difficulty = "green" }), "Not learned · " .. GREEN, "not learned at or above yellow")
eq(W.RecipeStatus({ difficulty = "yellow" }), YELLOW, "knowledge unknown: the difficulty alone")
eq(W.RecipeStatus({}), nil, "both parts unknown: no status")
eq(W.RecipeStatus(nil), nil, "a profession the character does not have: no status")

local states = { [1] = false, [2] = false, [3] = true, [4] = nil }
local function withStatus(order, hint, statusOf)
    return W.Details({ endgame = { { profession = "blacksmithing", reason = "Best-in-slot crafted gear" } } }, {
        catalog = cat, itemID = ARC, recipeOrder = order,
        recipeStatus = statusOf or function(_, spell) return { learned = states[spell], difficulty = spell == 3 and "yellow" or nil } end,
        needsHint = function() return hint end,
    })
end
-- Learned first (the default): the one learned recipe leads, though its yellow rank is the lowest.
d = withStatus(nil, false)
eq(d[3].text, "    Low Thing - 1 per craft (Learned · " .. YELLOW .. ")", "learned recipe first, with its status")
eq(d[3].kind, "note", "the status is on the grey recipe line")
eq(d[4].text, "    Mid Thing - 2 per craft", "then unknown, with no status")
eq(d[5].text, "    Arcanite Reaper - 12 per craft (Not learned)", "then not learned, highest yellow rank first")
eq(d[6].text, "    and 1 more recipes", "the three-line limit stays")
eq(#d, 6, "no hint when knowledge is recorded")
-- Not learned first.
d = withStatus("unlearned", false)
eq(d[3].text, "    Arcanite Reaper - 12 per craft (Not learned)", "not learned first")
eq(d[4].text, "    Lionheart Helm - 12 per craft (Not learned)", "both not-learned recipes before the rest")
eq(d[5].text, "    Mid Thing - 2 per craft", "then unknown")
-- Highest skill first ignores learned status.
d = withStatus("skill", false)
eq(d[3].text, "    Arcanite Reaper - 12 per craft (Not learned)", "highest yellow rank first")
eq(d[5].text, "    Mid Thing - 2 per craft", "learned status ignored")
-- Knowledge unknown: every order gives the yellow-rank order, and the hint ends the block.
for _, order in ipairs({ "learned", "unlearned", "skill" }) do
    d = withStatus(order, true, function() return {} end)
    eq(d[3].text, "    Arcanite Reaper - 12 per craft", order .. ": unknown knowledge, yellow-rank order")
    eq(d[5].text, "    Mid Thing - 2 per craft", order .. ": unknown knowledge, third line")
    eq(#d, 7, order .. ": the hint adds one line")
    eq(d[7].text, "    Open Blacksmithing to see which recipes you know", order .. ": hint after the 'and N more' line")
    eq(d[7].kind, "note", "the hint is grey")
end
d = W.Details({ endgame = { { profession = "blacksmithing", via = BAR } } }, { catalog = cat, itemID = ORE })
eq(d[2].text, "    Used to make Thorium Bar for Arcanite Bar", "two-level chain")
d = W.Details({ endgame = { { profession = "blacksmithing", via = ARC } } }, { catalog = cat, itemID = CRYSTAL })
eq(d[2].text, "    Used to make Arcanite Bar", "one-level chain")

-- The colored line: "KeepThat:" grey, only the category word colored, professions neutral, hint grey.
local colors = { endgame = { r = 1, g = 0, b = 0 }, leveling = { r = 0, g = 1, b = 0 } }
local both = { endgame = { { profession = "tailoring" } }, leveling = { { profession = "tailoring" } } }
eq(W.ColoredLine(both, colors, { hint = true }),
    "|cffaaaaaaKeepThat:|r |cffff0000Endgame|r + |cff00ff00Leveling|r: |cffddddddTailoring|r |cff999999(Shift)|r", "both, with the hint")
eq(W.ColoredLine({ endgame = { { profession = "alchemy" } } }, colors, { prefix = false }),
    "|cffff0000Endgame|r: |cffddddddAlchemy|r", "without the prefix (the toast)")
eq(W.ColoredLine(nil, colors), nil, "unmarked: nothing")

-- Owned across characters: grey dash, neutral count, before the grey (Shift) hint.
local tail = { endgame = { { profession = "alchemy" } } }
eq(W.ColoredLine(tail, colors, { hint = true, owned = 55 }),
    "|cffaaaaaaKeepThat:|r |cffff0000Endgame|r: |cffddddddAlchemy|r |cffaaaaaa-|r |cffdddddd55 owned|r |cff999999(Shift)|r", "owned before the hint")
eq(W.ColoredLine(tail, colors, { owned = 55 }):sub(-34), "|cffaaaaaa-|r |cffdddddd55 owned|r", "owned last without the hint")
eq(W.ColoredLine(tail, colors, { hint = true, owned = 0 }), W.ColoredLine(tail, colors, { hint = true }), "0 owned omitted")
eq(W.ColoredLine(tail, colors, { hint = true, owned = nil }):find("owned", 1, true), nil, "nil owned omitted")

-- The Stock block: after the category blocks, grey heading, rows as given, 5 at most, then "+N more".
local function holders(n)
    local rows = { { name = "Me", self = true, count = 20 } }
    for i = 2, n do rows[i] = { name = "Alt" .. i, count = 30 - i } end
    return rows
end
local mixed = { endgame = { { profession = "blacksmithing", reason = "x" } }, leveling = { { profession = "tailoring", need = { from = 1, to = 50, low = 40, high = 55 } } } }
local sd = W.Details(mixed, { catalog = cat, itemID = ORE, carried = function() return 7 end, stock = holders(3) })
local n = #sd
eq(sd[n - 3].text, "|cffaaaaaa  Stock|r", "grey Stock heading")
eq(sd[n - 3].kind, "line", "Stock heading is a colored line")
eq(sd[n - 2].text, "    This character: 20", "own row first")
eq(sd[n - 1].text, "    Alt2: 28", "others in the given order")
eq(sd[n].text, "    Alt3: 27", "last holder")
local sd8 = W.Details(mixed, { catalog = cat, itemID = ORE, stock = holders(8) })
eq(sd8[#sd8].text, "    +3 more", "more than five holders: +3 more")
eq(sd8[#sd8 - 1].text, "    Alt5: 25", "five holder rows shown")
eq(sd8[#sd8].kind, "note", "+N more is a grey note")
local sd5 = W.Details(mixed, { catalog = cat, itemID = ORE, stock = holders(5) })
eq(sd5[#sd5].text, "    Alt5: 25", "exactly five: no +N more")
local plainDetails = W.Details(mixed, { catalog = cat, itemID = ORE })
local function hasStock(d) for _, r in ipairs(d) do if r.text:find("Stock", 1, true) then return true end end return false end
eq(hasStock(plainDetails), false, "no stock: no block")
eq(hasStock(W.Details(mixed, { catalog = cat, itemID = ORE, stock = {} })), false, "empty stock: no block")
local eo = W.Details({ endgame = { { profession = "blacksmithing", reason = "x" } } }, { catalog = cat, itemID = ORE, stock = holders(2) })
eq(hasStock(eo), true, "endgame-only item shows stock")
local need = W.Details({ leveling = { { profession = "tailoring", need = { from = 1, to = 50, low = 40, high = 55 } } } },
    { catalog = cat, itemID = ORE, carried = function() return 12 end, stock = holders(2) })
eq(need[2].text, "    40-55 needed, 12 in bags", "need row unchanged by stock")

H.done()
