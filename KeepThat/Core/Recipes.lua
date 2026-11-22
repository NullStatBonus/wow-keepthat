-- Recipe knowledge recorder (spec recipe-knowledge; design D3-D5): reads the open profession window into
-- db.global.recipes[realm][name] (the stock recorder's character identity, design D4), applies learn
-- events, and answers the tooltip's recipe status. Game calls go through ns.Adapter.
local _, ns = ...

local R = {}
ns.Recipes = R

local K = function() return ns.RecipeKnowledge end
local A = function() return ns.Adapter end

local function log(message)
    local Log = ns.Log
    if Log and Log.Enabled and Log.Enabled() then Log.Record("recipes", message) end
end

local function catalog()
    return ns.Data and ns.Data.Catalog
end

-- This character's records, or nil when the game gives no identity. The key is the stock recorder's
-- (realm, name), read from the same adapter call, so recipes do not depend on stock being on.
function R.Records(create)
    local db = ns.addon and ns.addon.db
    if not (db and db.global and A().PlayerIdentity) then return nil end
    local name, realm = A().PlayerIdentity()
    if type(name) ~= "string" or type(realm) ~= "string" then return nil end
    local all = db.global.recipes
    if type(all) ~= "table" then
        if not create then return nil end
        all = {}; db.global.recipes = all
    end
    if type(all[realm]) ~= "table" then
        if not create then return nil end
        all[realm] = {}
    end
    if type(all[realm][name]) ~= "table" then
        if not create then return nil end
        all[realm][name] = {}
    end
    return all[realm][name]
end

local function summary(rec)
    return ("complete=%s known=%d"):format(tostring(rec and rec.complete or false), K().Count(rec))
end

-- Debug only (task 1.2): the client's own difficulty next to the computed one, and the spell-known check.
local lastProbe = {}
function R.Probe(read)
    local Log = ns.Log
    if not (Log and Log.Enabled and Log.Enabled()) or type(read) ~= "table" then return end
    local cat = catalog() or {}
    local rank = (ns.Context.Get().skills or {})[read.profession]
    local mismatches, apiYes, apiNo, apiNil, out = 0, 0, 0, 0, {}
    for _, row in ipairs(read.rows or {}) do
        local rec = cat.recipes and cat.recipes[row.spell]
        local mine = K().Difficulty(rec, rank, row.learned)
        -- Not learned below yellow: the client says orange, KeepThat shows no color by design (D1).
        if row.client and mine ~= row.client and not (mine == nil and not row.learned) then
            mismatches = mismatches + 1
            if #out < 10 then
                out[#out + 1] = ("recipe probe: %s %d client=%s computed=%s y=%s gy=%s rank=%s"):format(read.profession,
                    row.spell, tostring(row.client), tostring(mine), tostring(rec and rec.y), tostring(rec and rec.gy), tostring(rank))
            end
        end
        local api = A().IsPlayerSpell(row.spell)
        if api == nil then apiNil = apiNil + 1 elseif api == row.learned then apiYes = apiYes + 1 else apiNo = apiNo + 1 end
    end
    -- Catalog recipes the window did not list: with a complete read these are not learned.
    local unlisted, unlistedTrue = 0, 0
    if read.complete then
        for spell, rec in pairs(cat.recipes or {}) do
            if rec.p == read.profession and not read.known[spell] then
                unlisted = unlisted + 1
                if A().IsPlayerSpell(spell) == true then unlistedTrue = unlistedTrue + 1 end
            end
        end
    end
    local line = ("recipe probe: %s source=%s rows=%d complete=%s filtered=%s collapsed=%s unkeyed=%s stale=%s rank=%s mismatches=%d api agrees=%d disagrees=%d unknown=%d; unlisted=%d api true=%d"):format(
        read.profession, tostring(read.source), #(read.rows or {}), tostring(read.complete), tostring(read.filtered or false),
        tostring(read.collapsed or false), tostring(read.unkeyed or 0), tostring(read.stale or 0), tostring(rank), mismatches, apiYes, apiNo, apiNil, unlisted, unlistedTrue)
    if lastProbe[read.profession] == line then return end
    lastProbe[read.profession] = line
    Log.Record("recipes", line)
    for _, l in ipairs(out) do Log.Record("recipes", l) end
end

local seen = {}   -- professions read this session

-- A profession window opened or changed: record what it shows.
function R.OnWindow(kind)
    local read = A().RecipeWindow(kind, catalog())
    if not read then return end
    R.Probe(read)
    local records = R.Records(true)
    if not records then return end
    local before = summary(records[read.profession])
    local rec = K().Apply(records, read, A().Clock and A().Clock() or nil)
    local after = summary(rec)
    -- Logged on a change, and on the first read of each profession this session (test plan section 10).
    if before ~= after or not seen[read.profession] then log(("%s %s"):format(read.profession, after)) end
    seen[read.profession] = true
    if before ~= after then ns.Context.Invalidate() end
end

-- A learn event (design D5): a catalog recipe ID becomes learned; any other spell changes nothing.
function R.OnLearned(event, spellID)
    log(("learn event %s %s"):format(tostring(event), tostring(spellID)))
    local records = R.Records(true)
    if not records then return end
    local p = K().Learned(records, catalog(), spellID)
    if p then
        log(("%s %s"):format(p, summary(records[p])))
        ns.Context.Invalidate()
    end
end

-- Professions the character no longer has lose their record (design D4). skills is a full read; when
-- any Skills header stayed collapsed, nothing is dropped.
function R.Drop(skills, hidden)
    if type(skills) ~= "table" or not next(skills) then return end
    if type(hidden) == "table" and next(hidden) then return end
    local records = R.Records(false)
    if not records then return end
    for _, p in ipairs(K().Drop(records, skills)) do log(("%s dropped"):format(p)) end
end

-- The tooltip's status for a recipe: { learned = true|false|nil, difficulty = "yellow"|... }, or nil when
-- the character does not have the profession.
function R.Status(profession, spellID, skills)
    local rank = skills and skills[profession]
    if rank == nil then return nil end
    local records = R.Records(false)
    local learned = K().State(records and records[profession], spellID)
    local rec = catalog() and catalog().recipes and catalog().recipes[spellID]
    return { learned = learned, difficulty = K().Difficulty(rec, rank, learned) }
end

-- True when the tooltip should ask the player to open the profession (spec "Hint when recipe knowledge is
-- unknown"): the character has it, this client can record it, and no complete record exists.
function R.NeedsHint(profession, skills)
    if not (skills and skills[profession]) then return false end
    if not (A().RecipeRecordable and A().RecipeRecordable(profession)) then return false end
    local records = R.Records(false)
    local rec = records and records[profession]
    return not (rec and rec.complete)
end

-- Report lines (spec "Knowledge sources in the debug report").
function R.ReportLines(skills)
    local out = {}
    local records = R.Records(false) or {}
    local names = {}
    for p in pairs(skills or {}) do names[#names + 1] = p end
    table.sort(names)
    for _, p in ipairs(names) do
        local rec = records[p]
        local source = rec and "window" or "none"
        out[#out + 1] = ("  %s: source=%s complete=%s known=%d recordable=%s"):format(p, source,
            tostring(rec and rec.complete or false), K().Count(rec), tostring(A().RecipeRecordable and A().RecipeRecordable(p) or false))
    end
    if #out == 0 then out[1] = "  (no professions)" end
    return out
end

local WINDOW = { TRADE_SKILL_SHOW = "trade", TRADE_SKILL_UPDATE = "trade", TRADE_SKILL_LIST_UPDATE = "trade",
    CRAFT_SHOW = "craft", CRAFT_UPDATE = "craft" }
local LEARN = { "NEW_RECIPE_LEARNED", "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE" }

-- Events go to a module of their own: AceEvent keeps one handler per event per object, and Core/Addon.lua
-- already listens for the learn events on the addon.
ns.Start(function(a)
    local target = a
    if type(a.NewModule) == "function" then
        local ok, module = pcall(a.NewModule, a, "Recipes", "AceEvent-3.0")
        if ok and module then target = module end
    end
    local function guarded(fn)
        return function(...)
            local ok, err = pcall(fn, ...)
            if not ok and ns.Log then ns.Log.Failure("recipes", err) end
        end
    end
    for event, kind in pairs(WINDOW) do ns.Listen(target, event, guarded(function() R.OnWindow(kind) end)) end
    for _, event in ipairs(LEARN) do ns.Listen(target, event, guarded(function(e, id) R.OnLearned(e, id) end)) end
end)
