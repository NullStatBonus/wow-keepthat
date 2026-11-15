-- Which marks an item gets under the player's settings (spec material-catalog, "Classification follows
-- settings"). Plain Lua, no game calls.
--
-- ctx = {
--   catalog = ns.Data.Catalog, routes = ns.Data.Routes,
--   settings = { endgame = bool, leveling = bool, disabled = { endgame = { [itemID] = true }, leveling = { ... } } },
--   skills = { [profession] = rank }   (professions the player knows; others count the whole route)
--   extra = function(profession, itemID) -> list of extra leveling sources, or nil (Profession Journal)
-- }
-- Returns nil when the item is unmarked, else
--   { endgame = { { profession, reason, source, via }, ... } or nil,
--     leveling = { { profession, need }, ... } or nil }   (each list sorted by profession)
local _, ns = ...

local Classify = {}
ns.Classify = Classify

local function off(settings, category, itemID)
    local d = settings.disabled and settings.disabled[category]
    return d and d[itemID] or false
end

function Classify.Item(itemID, ctx)
    if type(itemID) ~= "number" or not ctx then return nil end
    local settings = ctx.settings or {}
    local result

    if settings.endgame and not off(settings, "endgame", itemID) then
        local entry = ctx.catalog and ctx.catalog.endgame and ctx.catalog.endgame[itemID]
        if entry then
            local list = {}
            for profession, e in pairs(entry) do
                list[#list + 1] = { profession = profession, reason = e[1], source = e[2], via = e[3] ~= 0 and e[3] or nil }
            end
            table.sort(list, function(a, b) return a.profession < b.profession end)
            result = { endgame = list }
        end
    end

    if settings.leveling and not off(settings, "leveling", itemID) then
        local professions = ns.Leveling.Professions(ctx.routes, itemID)
        local seen = {}
        for _, p in ipairs(professions) do seen[p] = true end
        -- An extra source can add a profession the built-in routes do not have for this item.
        if ctx.extraProfessions then
            for _, p in ipairs(ctx.extraProfessions(itemID) or {}) do
                if not seen[p] then seen[p] = true; professions[#professions + 1] = p end
            end
            table.sort(professions)
        end
        local list = {}
        for _, profession in ipairs(professions) do
            local skills = ctx.skills or {}
            local extra = ctx.extra and ctx.extra(profession, itemID) or nil
            local need = ns.Leveling.Need(ctx.routes, profession, itemID, skills[profession], extra)
            if need then list[#list + 1] = { profession = profession, need = need } end
        end
        if #list > 0 then
            result = result or {}
            result.leveling = list
        end
    end
    return result
end
