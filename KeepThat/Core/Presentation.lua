-- Local shared presentation contract, version 1. No sibling addon dependency.
local _, ns = ...
local L = ns.L
local P = { version = 1, spacing = 4, padding = 8, contentPadding = 12, sectionGap = 16,
    width = 280, height = 40, icon = 28, keys = {}, pages = { home = true, materials = true,
        integrations = true, appearance = true, advanced = true, about = true } }
ns.Presentation = P
function P.Profile()
    return ns.addon and ns.addon.db and ns.addon.db.profile or ns.defaults.profile
end
function P.Migrate(p)
    -- Leave the legacy key intact; both effective layers inherit its exact alpha once per profile.
    local old = type(p.toastOpacity) == "number" and p.toastOpacity or 1
    if p.toastBackgroundOpacity == nil then p.toastBackgroundOpacity = old end
    if p.toastTextOpacity == nil then p.toastTextOpacity = old end
end
function P.Scope()
    local db = ns.addon and ns.addon.db
    return db and db.GetCurrentProfile and db:GetCurrentProfile() ~= "Default" and L["This character"] or L["Shared settings"]
end
function P.Refresh()
    if ns.Context then ns.Context.Invalidate() end
    if ns.Toast and ns.Toast.Refresh then ns.Toast.Refresh() end
    if ns.Adapter and ns.Adapter.RefreshSamples then ns.Adapter.RefreshSamples() end
    if ns.Options and ns.Options.NotifyChange then ns.Options.NotifyChange() end
end
local function entry(key, storage, kind, min, max, default, factor)
    local e = { storage = storage, type = kind, min = min, max = max, default = default,
        scope = "active profile", factor = factor or 1, refresh = P.Refresh }
    function e.get()
        local p = P.Profile()
        local v = p[storage]
        if v == nil and (storage == "toastBackgroundOpacity" or storage == "toastTextOpacity") then v = p.toastOpacity end
        if v == nil then return default end
        if kind == "boolean" then return v end
        return v * e.factor
    end
    function e.set(v)
        if kind == "boolean" then P.Profile()[storage] = v else P.Profile()[storage] = v / e.factor end
    end
    P.keys[key] = e
end
entry("toast", "toast", "boolean", nil, nil, false)
entry("tooltip", "tooltip", "boolean", nil, nil, true)
entry("appearance.toast.background-opacity", "toastBackgroundOpacity", "integer", 0, 100, 100, 100)
entry("appearance.toast.text-opacity", "toastTextOpacity", "integer", 0, 100, 100, 100)
entry("appearance.toast.scale", "toastScale", "integer", 50, 200, 100, 100)
entry("appearance.toast.locked", "toastLocked", "boolean", nil, nil, false)
entry("stock.reminder", "stockReminder", "boolean", nil, nil, true)
function P.Value(key)
    local e = P.keys[key]; if not e then return nil end
    local v = e.get()
    if e.type == "boolean" then return v and "on" or "off" end
    return tostring(v)
end
function P.Syntax(key)
    local e = P.keys[key]
    if not e then return L["Unknown setting. Use /kt help appearance for valid keys."] end
    return L["Usage: /kt set %s %s"]:format(key, e.type == "boolean" and "on|off" or ("%d-%d"):format(e.min, e.max))
end
function P.Set(key, raw)
    local e = P.keys[key]; if not e then return false, P.Syntax(key) end
    local v
    if e.type == "boolean" then
        local s = tostring(raw):lower()
        if s ~= "on" and s ~= "off" then return false, P.Syntax(key) end
        v = s == "on"
    else
        v = tonumber(raw)
        if not v or v ~= math.floor(v) or v < e.min or v > e.max then return false, P.Syntax(key) end
    end
    if key == "appearance.toast.locked" and v and ns.Toast then ns.Toast.CancelMove() end
    e.set(v); e.refresh()
    return true, L["%s = %s"]:format(key, P.Value(key))
end
function P.Status()
    local out = { P.Scope() }
    local keys = {}; for k in pairs(P.keys) do keys[#keys + 1] = k end; table.sort(keys)
    for _, k in ipairs(keys) do out[#out + 1] = L["%s = %s"]:format(k, P.Value(k)) end
    if ns.Options then for _, row in ipairs(ns.Options.INTEGRATIONS) do
        out[#out + 1] = L["%s: %s"]:format(row.name, ns.Options.StatusText(row.key))
    end end
    return out
end
