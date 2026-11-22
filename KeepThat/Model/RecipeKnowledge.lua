-- Which recipes this character knows, and how hard each one is at the current rank (spec recipe-knowledge,
-- material-tooltip; design D1-D5, D8). Plain Lua, no game calls.
-- A record is { [profession] = { complete = bool, known = { [spellID] = true }, at = time } }.
local _, ns = ...

local K = {}
ns.RecipeKnowledge = K

-- Orange, Yellow, Green or Gray at rank, or nil when unknown (design D1, D2). recipe = { y, gy } from the
-- catalog. Below yellow only a learned recipe is Orange: unlearned, it may be too high to learn yet.
function K.Difficulty(recipe, rank, learned)
    local y, gy = recipe and recipe.y, recipe and recipe.gy
    if type(y) ~= "number" or type(gy) ~= "number" or type(rank) ~= "number" then return nil end
    if rank >= gy then return "gray" end
    if rank >= math.floor((y + gy) / 2) then return "green" end
    if rank >= y then return "yellow" end
    if learned == true then return "orange" end
    return nil
end

-- true (learned), false (a complete record lacks it) or nil (unknown).
function K.State(record, spellID)
    if type(record) ~= "table" then return nil end
    if type(record.known) == "table" and record.known[spellID] then return true end
    if record.complete then return false end
    return nil
end

-- Folds a window read { profession, complete, known } into records. A complete read replaces the
-- profession's record; an incomplete one only adds what it saw. Returns the profession's record.
function K.Apply(records, read, now)
    if type(records) ~= "table" or type(read) ~= "table" or type(read.profession) ~= "string" then return nil end
    local p = read.profession
    if read.complete then
        local known = {}
        for id in pairs(read.known or {}) do known[id] = true end
        records[p] = { complete = true, known = known, at = now }
    else
        local rec = records[p] or { complete = false, known = {} }
        rec.known = rec.known or {}
        for id in pairs(read.known or {}) do rec.known[id] = true end
        rec.at = now or rec.at
        records[p] = rec
    end
    return records[p]
end

-- A learn event with spellID (design D5). A catalog recipe is added to its profession and its profession
-- is returned; any other spell (class spells at level-up) changes nothing and returns nil.
function K.Learned(records, catalog, spellID)
    local rec = type(spellID) == "number" and catalog and catalog.recipes and catalog.recipes[spellID]
    if type(records) ~= "table" or not rec then return nil end
    local r = records[rec.p] or { complete = false, known = {} }
    r.known = r.known or {}
    r.known[spellID] = true
    records[rec.p] = r
    return rec.p
end

-- Every record becomes incomplete: what was learned stays learned, the rest becomes unknown.
function K.Unsure(records)
    for _, rec in pairs(type(records) == "table" and records or {}) do
        if type(rec) == "table" then rec.complete = false end
    end
end

-- Removes the records of professions the character no longer has. skills = { [profession] = rank }
-- from a full read; kept = { [profession] = true } for professions out of view, not gone.
function K.Drop(records, skills, kept)
    local dropped = {}
    for p in pairs(type(records) == "table" and records or {}) do
        if skills[p] == nil and not (kept and kept[p]) then dropped[#dropped + 1] = p end
    end
    table.sort(dropped)
    for _, p in ipairs(dropped) do records[p] = nil end
    return dropped
end

-- "Recipe order" (design D8): the rank of a state within each order. Lower comes first.
K.ORDERS = {
    learned = function(s) return s == true and 1 or s == nil and 2 or 3 end,
    unlearned = function(s) return s == false and 1 or s == nil and 2 or 3 end,
    skill = function() return 1 end,
}
K.DEFAULT_ORDER = "learned"

-- Sorts { { spell, y, state }, ... } in place: by group for the order, then yellow rank highest first,
-- recipes without one last, then spell ID.
function K.Sort(list, order)
    local group = K.ORDERS[order] or K.ORDERS[K.DEFAULT_ORDER]
    table.sort(list, function(a, b)
        local ga, gb = group(a.state), group(b.state)
        if ga ~= gb then return ga < gb end
        if (a.y ~= nil) ~= (b.y ~= nil) then return a.y ~= nil end
        if a.y and b.y and a.y ~= b.y then return a.y > b.y end
        return a.spell < b.spell
    end)
    return list
end

-- The number of known recipes in a record.
function K.Count(record)
    local n = 0
    for _ in pairs(type(record) == "table" and record.known or {}) do n = n + 1 end
    return n
end
