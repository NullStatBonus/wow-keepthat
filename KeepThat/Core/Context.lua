-- Builds the context Model/Classify.lua needs (catalog, routes, settings, the player's skills) and
-- caches it until something it depends on changes (ns.Context.Invalidate()).
local _, ns = ...

local Context = { listeners = {} }
ns.Context = Context

local cached

-- Professions the player knows: { [profession] = rank }, read through the adapter.
-- Also the header each profession sits under on the Skills list (Adapter.ProfessionSkills).
function Context.Skills()
    if not ns.Adapter.ProfessionSkills then return {}, {} end
    local skills, _, under = ns.Adapter.ProfessionSkills()
    return skills or {}, under or {}
end

-- While debugging, record the profession ranks each time they change, with the Skills headers collapsed
-- now, so an in-game check reads them from the saved variables (test plan section 13).
local lastSkillsLine
function Context.LogSkills(skills)
    local Log = ns.Log
    if not (Log and Log.Enabled and Log.Enabled()) then return end
    local parts = {}
    for k, v in pairs(skills or {}) do parts[#parts + 1] = k .. "=" .. tostring(v) end
    table.sort(parts)
    local A, headers = ns.Adapter, {}
    if A.ProfessionSkills then
        local _, hidden = A.ProfessionSkills(true)   -- visible rows only: changes nothing
        for name in pairs(type(hidden) == "table" and hidden or {}) do headers[#headers + 1] = tostring(name) end
        table.sort(headers)
    end
    local line = ("%s; collapsed headers: %s"):format(#parts > 0 and table.concat(parts, " ") or "(none)",
        #headers > 0 and table.concat(headers, ", ") or "(none)")
    if line == lastSkillsLine then return end
    lastSkillsLine = line
    Log.Record("skills", line)
end

function Context.Get()
    if cached then return cached end
    local profile = ns.addon and ns.addon.db and ns.addon.db.profile or ns.defaults.profile
    local skills, skillHeaders = Context.Skills()
    Context.LogSkills(skills)
    cached = {
        catalog = ns.Data and ns.Data.Catalog,
        routes = ns.Data and ns.Data.Routes,
        settings = profile,
        skills = skills,
        skillHeaders = skillHeaders,
        extra = Context.extra,                     -- set by Integrations/ProfessionJournal.lua when it works
        extraProfessions = Context.extraProfessions,
    }
    return cached
end

-- Something changed (a setting, a skill rank, an integration): rebuild on next use and tell listeners
-- (the tooltip, the overlay) so they can refresh what is on screen.
function Context.Invalidate()
    cached = nil
    for _, fn in ipairs(Context.listeners) do pcall(fn) end
end

-- A skill event: invalidate only when a rank changed or a profession is gone. SKILL_LINES_CHANGED reads
-- only the visible rows: reading every rank on Classic Era expands and collapses Skills headers, which
-- fires this event again, so this read must not. A profession missing under a header that is collapsed
-- now is out of view, not gone. full (CHAT_MSG_SKILL, "Your skill in Tailoring has increased") reads
-- every rank, so a rank-up under a collapsed header is seen; that message is not fired by expanding,
-- and a weapon skill-up changes no profession rank, so it refreshes nothing. With no cached context
-- nothing has been read since the last invalidation, so there is nothing to refresh (and a read in
-- progress cannot recurse).
function Context.SkillsChanged(full)
    local before = cached
    if not before then return end
    local A = ns.Adapter
    if not A.ProfessionSkills then return end
    local seen, hidden = A.ProfessionSkills(not full)
    -- A full read can fire SKILL_LINES_CHANGED at once, and that nested call may already have refreshed.
    if cached ~= before then return end
    seen, hidden = seen or {}, type(hidden) == "table" and hidden or {}
    local was, under = before.skills or {}, before.skillHeaders or {}
    for k, v in pairs(seen) do if was[k] ~= v then return Context.Invalidate() end end
    for k in pairs(was) do
        if seen[k] == nil and not (under[k] and hidden[under[k]]) then return Context.Invalidate() end
    end
end

function Context.OnChange(fn)
    Context.listeners[#Context.listeners + 1] = fn
end

-- A sample classification for /kt demo, so its tooltip always shows KeepThat's lines through the normal
-- renderer. It ends on its own after `seconds`.
function Context.SetDemo(itemID, result, now, seconds)
    Context.demo = { itemID = itemID, result = result, untilTime = (now or 0) + (seconds or 15) }
end

-- True while /kt demo's sample is active for this item (not yet expired).
function Context.DemoActive(itemID, now)
    local d = Context.demo
    if not d or d.itemID ~= itemID then return false end
    return (now or (ns.Adapter.Now and ns.Adapter.Now()) or 0) <= d.untilTime
end

-- Classify an item with the current context.
function Context.Classify(itemID, now)
    local d = Context.demo
    if d and itemID == d.itemID then
        if (now or (ns.Adapter.Now and ns.Adapter.Now()) or 0) <= d.untilTime then return d.result end
        Context.demo = nil
    end
    return ns.Classify.Item(itemID, Context.Get())
end
