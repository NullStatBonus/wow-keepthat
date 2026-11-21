-- How much of a leveling material to keep (spec leveling-guidance, design D3). Plain Lua, no game calls.
--
-- routes.materials[profession][itemID] is a flat list of segments: guide, from, to, low, high, via, ...
-- A segment the player has passed adds nothing; one they are partway through counts in proportion.
-- Each source (guide) adds up its own segments; the count to keep runs from the smallest to the
-- largest source total. Segments with 0, 0 come from steps the guide gives no count for: they still
-- mark the material but take no part in the count. A source counts when it has a counted step still
-- ahead, or, next to such a source, when all its steps are passed and some had a count (0: a lower
-- bound, never the whole count). A source left only with uncounted
-- steps has no count: never 0 for steps still ahead (review #4).
local _, ns = ...

local Leveling = {}
ns.Leveling = Leveling

local SEG = 6

-- Round a count up, never below 0 (and never to -0, which LuaJIT prints as "-0").
local function count(x)
    local n = math.ceil(x - 1e-9)
    if n <= 0 then return 0 end
    return n
end

-- The share of a segment still ahead of skill (1 when skill is nil: the whole route).
local function remaining(from, to, skill)
    if not skill or skill <= from then return 1 end
    if skill >= to then return 0 end
    return (to - skill) / (to - from)
end

-- Need for one material in one profession, or nil when no source has a step left that uses it.
-- extra: optional list of more sources, each { name = ..., segments = { from, to, low, high, via, ... } }
-- (DFL Profession Journal when installed). Returns:
--   { low, high (nil when no source has a count), from, to (the skill range still ahead),
--     sources = { name, ... } still using it, in route order,
--     via = { [itemID] = count for that item, the largest over the sources } }
-- A source with counts whose steps are all passed takes part in the range as 0: the guides disagree
-- about whether more is needed, and the range shows it. via comes from the source that gives high, each
-- share rounded down, so the shares never add up to more than high.
function Leveling.Need(routes, profession, itemID, skill, extra)
    local order, bySource = {}, {}
    local from, to
    local function add(name, low, high, f, t, v)
        local e = bySource[name]
        if not e then
            e = { low = 0, high = 0, counted = false, passed = false, active = false, via = {} }
            bySource[name] = e
            order[#order + 1] = name
        end
        local share = remaining(f, t, skill)
        if share <= 0 then
            if high > 0 then e.passed = true end
            return
        end
        e.active = true
        if high > 0 then
            e.counted = true
            e.low = e.low + low * share
            e.high = e.high + high * share
            if v and v ~= 0 then e.via[v] = (e.via[v] or 0) + high * share end
        end
        local start = skill and math.max(f, skill) or f
        from = from and math.min(from, start) or start
        to = to and math.max(to, t) or t
    end

    local list = routes and routes.materials and routes.materials[profession]
    local segs = list and list[itemID]
    if segs then
        local guides = routes.guides or {}
        for i = 1, #segs, SEG do
            local g = segs[i]
            local name = guides[g] and guides[g].name or ("guide " .. tostring(g))
            add(name, segs[i + 3], segs[i + 4], segs[i + 1], segs[i + 2], segs[i + 5])
        end
    end
    for _, source in ipairs(extra or {}) do
        local s = source.segments or {}
        for i = 1, #s, 5 do add(source.name, s[i + 2], s[i + 3], s[i], s[i + 1], s[i + 4]) end
    end

    -- A finished guide's 0 is only a lower bound: it takes part only next to a source still counting.
    local sources, low, high, via, ahead = {}, nil, nil, {}, false
    for _, name in ipairs(order) do
        if bySource[name].counted then ahead = true end
    end
    for _, name in ipairs(order) do
        local e = bySource[name]
        if e.active then sources[#sources + 1] = name end
        if ahead and (e.counted or (e.passed and not e.active)) then
            local l, h = count(e.low), count(e.high)
            low = low and math.min(low, l) or l
            if not high or h > high then
                high = h
                via = {}
                for k, n in pairs(e.via) do
                    local share = math.floor(n + 1e-9)
                    if share > 0 then via[k] = share end
                end
            end
        end
    end
    if #sources == 0 then return nil end
    return { low = low, high = high, from = from, to = to, sources = sources, via = via }
end

-- Every profession whose routes use itemID.
function Leveling.Professions(routes, itemID)
    local out = {}
    for profession, items in pairs(routes and routes.materials or {}) do
        if items[itemID] then out[#out + 1] = profession end
    end
    table.sort(out)
    return out
end
