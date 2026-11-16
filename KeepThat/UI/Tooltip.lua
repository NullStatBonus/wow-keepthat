-- The tooltip line (spec material-tooltip, design D5): one colored line on every marked item's tooltip,
-- and the details below it while Shift is held. All game calls go through ns.Adapter. Any error turns
-- the line off for the session and is recorded in the debug report; it never raises.
local _, ns = ...

local Tooltip = {}
ns.Tooltip = Tooltip

local NOTE = { r = 0.6, g = 0.6, b = 0.6 }       -- #999999: recipes, guides
local BODY = { r = 0.867, g = 0.867, b = 0.867 } -- #DDDDDD: purposes and counts
local WHITE = { r = 1, g = 1, b = 1 }

local added = {}     -- [tooltip] = true once our line is on it; cleared on OnTooltipCleared
local watched = {}   -- [tooltip] = true once its OnTooltipCleared is hooked
local disabled = false

local function profile()
    return ns.addon and ns.addon.db and ns.addon.db.profile
end

local function color(kind)
    local colors = profile() and profile().colors or {}
    if kind == "both" then kind = "endgame" end
    if kind == "note" then return NOTE end
    if kind == "body" then return BODY end
    if kind == "line" then return WHITE end           -- the main line carries its own color codes
    return colors[kind] or WHITE
end

local function fail(err)
    disabled = true
    if ns.Log then ns.Log.Failure("tooltip", err) end
end

local function add(tooltip, text, kind)
    local c = color(kind)
    local ok, err = ns.Adapter.TooltipAddLine(tooltip, text, c.r, c.g, c.b)
    if not ok then error(err or "AddLine failed", 0) end
end

-- The realm-and-faction stock { total, rows }, or nil when the recorder does not know.
local function liveStock(itemID)
    local R = ns.StockRecorder
    if not (R and R.Total) then return nil end
    local total, _, rows = R.Total(itemID)
    if total == nil then return nil end
    return { total = total, rows = rows }
end

local function details(result, itemID, carried, stock)
    local A = ns.Adapter
    local ctx = ns.Context.Get() or {}
    local catalog = ctx.catalog or {}
    return ns.Wording.Details(result, {
        catalog = catalog,
        routes = ctx.routes,
        itemID = itemID,
        itemName = function(id) return A.ItemName(id) or (catalog.itemNames or {})[id] or ("#" .. id) end,
        spellName = function(id) return A.SpellName(id) or (catalog.spellNames or {})[id] or ("#" .. id) end,
        carried = carried or A.ItemCount,
        colors = profile() and profile().colors or {},
        stock = stock and stock.rows,
    })
end

-- Both live tooltips and previews draw the same rows with the same semantic ink.
-- stock = { total, rows } for a preview; nil reads the recorder.
function Tooltip.Draw(tooltip, itemID, result, shift, carried, stock)
    local colors = profile() and profile().colors or {}
    stock = stock or liveStock(itemID)
    add(tooltip, ns.Wording.ColoredLine(result, colors, { hint = not shift, owned = stock and stock.total }), "line")
    if shift then
        for _, line in ipairs(details(result, itemID, carried, stock)) do add(tooltip, line.text, line.kind) end
    end
end

local function fill(tooltip, itemID)
    if not watched[tooltip] then
        watched[tooltip] = true
        ns.Adapter.OnTooltipCleared(tooltip, function(self) added[self] = nil end)
    end
    if added[tooltip] then return end
    local result = ns.Context.Classify(itemID)
    if not ns.Wording.Line(result) then return end
    added[tooltip] = true
    local shift = ns.Adapter.IsShiftDown()
    Tooltip.Draw(tooltip, itemID, result, shift)
    ns.Adapter.TooltipShow(tooltip)
end

-- Called by the hook for every item tooltip.
function Tooltip.OnItem(tooltip, itemID)
    if ns.Adapter.IsSampleTooltip and ns.Adapter.IsSampleTooltip(tooltip) then return end
    if disabled then return end
    local p = profile()
    -- /kt demo shows its sample tooltip whatever the setting.
    local demo = ns.Context.DemoActive and ns.Context.DemoActive(itemID)
    if not p or not (p.tooltip or demo) then return end
    local ok, err = pcall(fill, tooltip, itemID)
    if not ok then fail(err) end
end

-- Shift pressed or released: redraw the shown tooltips so the details appear or go away. The shopping
-- (comparison) tooltips are redrawn by the game along with GameTooltip.
function Tooltip.OnModifier(_, key)
    if disabled or not (key == "LSHIFT" or key == "RSHIFT") then return end
    local p = profile()
    -- The /kt demo sample expands with Shift even when the tooltip setting is off.
    local demo = ns.Context.demo and ns.Context.DemoActive and ns.Context.DemoActive(ns.Context.demo.itemID)
    if not p or not (p.tooltip or demo) then return end
    local A = ns.Adapter
    for _, name in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
        local tooltip = A.Resolve(name)
        if tooltip and added[tooltip] and A.TooltipIsShown(tooltip) then
            added[tooltip] = nil
            A.RefreshTooltip(tooltip)
        end
    end
end

ns.Start(function(addon)
    local path = ns.Adapter.HookItemTooltips(Tooltip.OnItem)
    Tooltip.path = path
    if not path then
        fail("no item tooltip hook on this client")
        return
    end
    addon:RegisterEvent("MODIFIER_STATE_CHANGED", Tooltip.OnModifier)
end)

-- Choose real material metadata, but classify a private hypothetical character: both categories
-- enabled, no disabled items or integrations, and skills at the start of this item's route segments.
function Tooltip.Sample(random)
    local ctx = ns.Context.Get() or {}
    local catalog, routes = ctx.catalog or {}, ctx.routes or {}
    local candidates = {}
    for id in pairs(catalog.endgame or {}) do candidates[id] = true end
    for _, items in pairs(routes.materials or {}) do for id in pairs(items) do candidates[id] = true end end
    local ids = {}; for id in pairs(candidates) do ids[#ids + 1] = id end; table.sort(ids)
    if #ids == 0 then return nil end
    local id = ids[(random or math.random)(#ids)]
    local skills = {}
    for profession, items in pairs(routes.materials or {}) do
        local segments = items[id] or {}
        for i = 1, #segments, 6 do
            skills[profession] = math.min(skills[profession] or 300, segments[i + 1])
        end
    end
    local result = ns.Classify.Item(id, { catalog = catalog, routes = routes, skills = skills,
        settings = { endgame = true, leveling = true } })
    local name = (ns.Adapter.ItemName and ns.Adapter.ItemName(id)) or (catalog.itemNames or {})[id] or ns.L["Item %d"]:format(id)
    return { itemID = id, name = name, result = result, carried = 12, stock = {
        total = 55, rows = { { name = "", self = true, count = 20 }, { name = "Bankmule", count = 30 }, { name = "Hunter", count = 5 } } } }
end

-- Private native item tooltip: sample counts never enter live Context or production hooks.
function Tooltip.Preview()
    if not ns.Adapter.ShowSampleTooltip then return false end
    local sample = Tooltip.Sample()
    if not sample then return false end
    return ns.Adapter.ShowSampleTooltip(sample.itemID, sample.name, function(tooltip, shift)
        Tooltip.Draw(tooltip, sample.itemID, sample.result, shift, function() return sample.carried end, sample.stock)
    end)
end
