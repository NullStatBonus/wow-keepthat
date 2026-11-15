-- Builds the context Model/Classify.lua needs (catalog, routes, settings, the player's skills) and
-- caches it until something it depends on changes (ns.Context.Invalidate()).
local _, ns = ...

local Context = { listeners = {} }
ns.Context = Context

local cached

-- Professions the player knows: { [profession] = rank }, read through the adapter.
function Context.Skills()
    return ns.Adapter.ProfessionSkills and ns.Adapter.ProfessionSkills() or {}
end

function Context.Get()
    if cached then return cached end
    local profile = ns.addon and ns.addon.db and ns.addon.db.profile or ns.defaults.profile
    cached = {
        catalog = ns.Data and ns.Data.Catalog,
        routes = ns.Data and ns.Data.Routes,
        settings = profile,
        skills = Context.Skills(),
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
