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

local function details(result, itemID)
    local A = ns.Adapter
    local ctx = ns.Context.Get() or {}
    local catalog = ctx.catalog or {}
    return ns.Wording.Details(result, {
        catalog = catalog,
        routes = ctx.routes,
        itemID = itemID,
        itemName = function(id) return A.ItemName(id) or (catalog.itemNames or {})[id] or ("#" .. id) end,
        spellName = function(id) return A.SpellName(id) or (catalog.spellNames or {})[id] or ("#" .. id) end,
        carried = A.ItemCount,
        colors = profile() and profile().colors or {},
    })
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
    -- "KeepThat:" grey, only the category word colored, professions neutral; a grey "(Shift)" hint
    -- while the details are collapsed.
    local colors = profile() and profile().colors or {}
    add(tooltip, ns.Wording.ColoredLine(result, colors, { hint = not shift }), "line")
    if shift then
        for _, line in ipairs(details(result, itemID)) do add(tooltip, line.text, line.kind) end
    end
    ns.Adapter.TooltipShow(tooltip)
end

-- Called by the hook for every item tooltip.
function Tooltip.OnItem(tooltip, itemID)
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
