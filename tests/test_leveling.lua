-- Model/Leveling.lua against the leveling-guidance scenarios.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ns = {}
H.load("Model/Leveling.lua", ns)
local Need = ns.Leveling.Need

local RUNE, BOLT, WOOL, BELT = 14047, 14048, 2592, 14143
local routes = {
    guides = { { name = "Guide A" }, { name = "Guide B" }, { name = "Guide C" } },
    materials = { tailoring = {
        -- guide, from, to, low, high, via
        [BOLT] = { 1, 260, 280, 40, 40, BELT, 2, 260, 280, 55, 55, BELT },
        [RUNE] = { 1, 250, 260, 956, 956, BOLT, 1, 260, 280, 100, 100, BELT },
        [WOOL] = { 1, 81, 150, 100, 120, 0, 2, 81, 150, 110, 110, 0 },
        [999] = { 3, 1, 50, 0, 0, 1 },
    } },
}

-- Guides differ: a range. Agree: one number (low == high).
local n = Need(routes, "tailoring", BOLT, nil)
eq(n.low .. "-" .. n.high, "40-55", "guides differ: smallest to largest")
eq(table.concat(n.sources, ","), "Guide A,Guide B", "both guides named, in route order")
local agree = Need({ guides = routes.guides, materials = { t = { [1] = { 1, 1, 10, 40, 40, 0, 2, 1, 10, 40, 40, 0 } } } }, "t", 1)
eq(agree.low == agree.high and agree.low, 40, "guides agree: one number")

-- A guide that gives a range itself.
n = Need(routes, "tailoring", WOOL, nil)
eq(n.low .. "-" .. n.high, "100-120", "a guide's own range and another's 110")

-- Partway through: only what is still ahead, in proportion.
n = Need(routes, "tailoring", BOLT, 270)
eq(n.low .. "-" .. n.high, "20-28", "half of each 260-280 segment remains (rounded up)")
eq(n.from .. "-" .. n.to, "270-280", "the range still ahead starts at the current skill")

-- Passed in every guide: not a leveling material for this player.
eq(Need(routes, "tailoring", BOLT, 280), nil, "every step passed")
eq(Need(routes, "tailoring", BOLT, 300), nil, "skill 300")

-- Profession not known: the whole route.
n = Need(routes, "tailoring", RUNE, nil)
eq(n.high, 1056, "the whole route from skill 1")
eq(n.via[BOLT], 956, "the part that goes into Bolt of Runecloth")
eq(n.via[BELT], 100, "the part that goes into the belts")
n = Need(routes, "tailoring", RUNE, 255)
eq(n.high, 578, "half the bolt segment and all of the belt segment")

-- Count-less sources mark but do not count.
n = Need(routes, "tailoring", 999, nil)
eq(n ~= nil, true, "still a leveling material")
eq(n.low, nil, "no count")
eq(n.sources[1], "Guide C", "the source is named")

-- Unknown item and profession.
eq(Need(routes, "tailoring", 1, nil), nil, "unknown item")
eq(Need(routes, "alchemy", BOLT, nil), nil, "unknown profession")
eq(Need(nil, "tailoring", BOLT, nil), nil, "no routes loaded")

-- An extra source (Profession Journal) joins the range.
n = Need(routes, "tailoring", BOLT, nil, { { name = "DFL Profession Journal", segments = { 260, 280, 70, 70, BELT } } })
eq(n.low .. "-" .. n.high, "40-70", "the extra source raises the top of the range")
eq(n.sources[3], "DFL Profession Journal", "and is named")
n = Need(routes, "alchemy", 5, nil, { { name = "PJ", segments = { 1, 20, 7, 7, 0 } } })
eq(n.high, 7, "an extra source alone can make a leveling material")

-- A guide whose steps are all passed counts as 0 in the range (review finding 2).
local split = { guides = routes.guides, materials = { t = { [5] = { 1, 260, 280, 40, 40, 0, 2, 280, 300, 55, 55, 0 } } } }
n = Need(split, "t", 5, 280)
eq(n.low .. "-" .. n.high, "0-55", "one guide is done, the other needs 55")
eq(table.concat(n.sources, ","), "Guide B", "only the guide still using it is named")

-- The intermediate breakdown takes the largest over guides, not their sum (review finding 3).
local twoGuides = { guides = routes.guides, materials = { t = { [6] = { 1, 1, 50, 40, 40, BOLT, 2, 1, 50, 55, 55, BOLT } } } }
n = Need(twoGuides, "t", 6, nil)
eq(n.via[BOLT], 55, "breakdown is the largest guide's share")

-- Professions using an item.
eq(table.concat(ns.Leveling.Professions(routes, RUNE), ","), "tailoring", "professions using Runecloth")

H.done()
