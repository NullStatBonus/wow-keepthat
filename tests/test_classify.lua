-- Model/Classify.lua against the material-catalog classification scenarios, with the real Era data.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ns = {}
H.load("Data/Catalog_Era.lua", ns)
H.load("Data/Routes_Era.lua", ns)
H.load("Core/Client.lua", ns)
H.load("Model/Leveling.lua", ns)
H.load("Model/Classify.lua", ns)
local Item = ns.Classify.Item

local ARCANITE, ARCANE_CRYSTAL, THORIUM_ORE, BOLT_RUNE, ROUGH_STONE = 12360, 12363, 10620, 14048, 2835
local function ctx(settings, skills)
    return { catalog = ns.Data.Catalog, routes = ns.Data.Routes, settings = settings, skills = skills or {} }
end
local DEFAULTS = { endgame = true, leveling = false, disabled = { endgame = {}, leveling = {} } }

-- Endgame on by default; listed and expanded materials.
local r = Item(ARCANITE, ctx(DEFAULTS))
eq(r.endgame[1].profession, "blacksmithing", "Arcanite Bar: endgame Blacksmithing")
eq(r.endgame[1].via, nil, "a listed material has no via")
r = Item(ARCANE_CRYSTAL, ctx(DEFAULTS))
local bs
for _, e in ipairs(r.endgame) do if e.profession == "blacksmithing" then bs = e end end
eq(bs and bs.via, ARCANITE, "Arcane Crystal: used to make Arcanite Bar for Blacksmithing")
r = Item(THORIUM_ORE, ctx(DEFAULTS))
eq(r ~= nil and r.endgame ~= nil, true, "Thorium Ore: two levels down")

-- Leveling off by default: a leveling-only material is unmarked.
eq(Item(ROUGH_STONE, ctx(DEFAULTS)), nil, "leveling off: Rough Stone unmarked")
local LEVEL = { endgame = true, leveling = true, disabled = { endgame = {}, leveling = {} } }
r = Item(ROUGH_STONE, ctx(LEVEL))
eq(r.leveling[1].profession, "blacksmithing", "leveling on: Rough Stone for Blacksmithing")
eq(r.leveling[1].need.low > 0, true, "with a count")

-- Steps passed: not a leveling material for this player, while another profession still counts.
eq(Item(ROUGH_STONE, ctx(LEVEL, { blacksmithing = 300, engineering = 300, enchanting = 300 })), nil, "every step passed")
r = Item(ROUGH_STONE, ctx(LEVEL, { blacksmithing = 300, engineering = 300 }))
eq(#r.leveling == 1 and r.leveling[1].profession, "enchanting", "a profession not known still counts its whole route")

-- Both categories.
r = Item(BOLT_RUNE, ctx(LEVEL))
eq(r.endgame ~= nil and r.leveling ~= nil, true, "Bolt of Runecloth: endgame and leveling")

-- Material turned off in the Materials review.
local off = { endgame = true, leveling = false, disabled = { endgame = { [ARCANITE] = true }, leveling = {} } }
eq(Item(ARCANITE, ctx(off)), nil, "Arcanite Bar off: unmarked")
eq(Item(ARCANE_CRYSTAL, ctx(off)) ~= nil, true, "other endgame materials stay marked")
off = { endgame = true, leveling = true, disabled = { endgame = {}, leveling = { [BOLT_RUNE] = true } } }
r = Item(BOLT_RUNE, ctx(off))
eq(r.endgame ~= nil and r.leveling == nil, true, "leveling turned off for one material keeps its endgame mark")

-- Categories off.
eq(Item(ARCANITE, ctx({ endgame = false, leveling = false })), nil, "both categories off")

-- Unknown items and bad input never error.
eq(Item(1, ctx(LEVEL)), nil, "unknown item")
eq(Item(nil, ctx(LEVEL)), nil, "no item")
eq(Item(ARCANITE, nil), nil, "no context")
eq(Item(ARCANITE, { settings = LEVEL }), nil, "no data loaded")

-- An extra source can add a profession.
local c = ctx(LEVEL)
c.extraProfessions = function(id) return id == 4 and { "alchemy" } or nil end
c.extra = function(p, id) return p == "alchemy" and id == 4 and { { name = "PJ", segments = { 1, 50, 3, 3, 0 } } } or nil end
r = Item(4, c)
eq(r and r.leveling[1].need.high, 3, "an item only an extra source uses")

H.done()
