-- Loot toast (spec loot-toast, design D6): a short pop-up when the player loots a marked material.
-- Plain-Lua core (Parse, Handle, Tick) driven by an injectable frame factory; the real frames are
-- three mouse-transparent black panels near the top center.
local _, ns = ...
local L = ns.L

local Toast = {
    MAX = 3,          -- toasts visible at once
    SHOW = 4,         -- seconds a toast lasts
    FADE = 1,         -- the last second fades out
    seen = {},        -- itemID -> true, one toast per item per session
    active = {},      -- visible entries { itemID, count, age, frame }
    queue = {},       -- waiting entries { itemID, count }
    free = {},        -- idle frames
}
ns.Toast = Toast

-- itemID, count, name from a chat message; nil when it is not the player's own loot.
function Toast.Parse(message, patterns)
    if type(message) ~= "string" then return nil end
    for _, p in ipairs(patterns or {}) do
        local link, n = message:match(p.pattern)
        if link then
            local id = tonumber(link:match("|Hitem:(%d+)"))
            if id then
                return id, p.multiple and tonumber(n) or 1, link:match("%[(.-)%]")
            end
        end
    end
end

local function profile()
    return ns.addon and ns.addon.db and ns.addon.db.profile or ns.defaults.profile
end

-- Where toast number index goes: the saved position for the first, then 42 pixels lower for each next.
Toast.SPACING = 46
Toast.DEFAULT_POSITION = { point = "TOP", x = 0, y = -140 }

function Toast.Position(index)
    local pos = profile().toastPosition or Toast.DEFAULT_POSITION
    return pos.point or "TOP", pos.x or 0, (pos.y or 0) - ((index or 1) - 1) * Toast.SPACING
end

function Toast.SavePosition(point, x, y)
    profile().toastPosition = { point = point or "TOP", x = math.floor((x or 0) + 0.5), y = math.floor((y or 0) + 0.5) }
    for i, e in ipairs(Toast.active) do e.frame:Place(i) end
end

function Toast.ResetPosition()
    local d = Toast.DEFAULT_POSITION
    Toast.SavePosition(d.point, d.x, d.y)
end

-- Toast look (Codex style review): 280x40, pure black (OLED-safe), 28px icon, neutral title, grey
-- subtitle with only the category word colored, and a thin accent bar in the category color. The whole
-- frame fades with the "Toast opacity" setting.
Toast.WIDTH, Toast.HEIGHT = 280, 40
Toast.FADE_IN = 0.15

local function buildFrame(create, parent, strata)
    local f = create("Frame", nil, parent)
    f:SetSize(Toast.WIDTH, Toast.HEIGHT)
    f:SetFrameStrata(strata)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 1)              -- pure black (OLED-safe); dimmed by the toast opacity
    local accent = f:CreateTexture(nil, "BORDER")
    accent:SetSize(2, 24)
    accent:SetPoint("LEFT", 1, 0)
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", 6, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)    -- trim the default icon border
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", 42, -7)
    title:SetPoint("RIGHT", -8, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetTextColor(0.867, 0.867, 0.867)
    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("BOTTOMLEFT", 42, 7)
    sub:SetPoint("RIGHT", -8, 0)
    sub:SetJustifyH("LEFT")
    sub:SetWordWrap(false)
    sub:SetTextColor(0.667, 0.667, 0.667)
    local function set(ic, titleText, subText, c)
        icon:SetTexture(ic)
        title:SetText(titleText)
        sub:SetText(subText)
        accent:SetColorTexture(c.r, c.g, c.b, 0.45)
    end
    return f, set
end

-- The toast's alpha at a given age: a short fade in, hold, then fade out over the last FADE seconds,
-- all scaled by the player's toast opacity.
function Toast.Alpha(age)
    local a = 1
    if age < Toast.FADE_IN then a = age / Toast.FADE_IN
    elseif age > Toast.SHOW - Toast.FADE then a = (Toast.SHOW - age) / Toast.FADE end
    a = math.max(0, math.min(1, a))
    local opacity = profile().toastOpacity
    if type(opacity) ~= "number" then opacity = 1 end
    return a * math.max(0, math.min(1, opacity))
end

-- A preview toast to drag into place (Home page, "Move loot toasts"), with the instruction under it.
-- Right-click to finish.
local mover
function Toast.ShowMover()
    local create = ns.Adapter.Resolve("CreateFrame")
    local parent = ns.Adapter.Resolve("UIParent")
    if type(create) ~= "function" then return false end
    if not mover then
        local set
        mover, set = buildFrame(create, parent, "DIALOG")
        local c = (profile().colors or {}).endgame or { r = 0.64, g = 0.21, b = 0.93 }
        set(134400, L["Arcanite Bar x1"], ns.Wording.ColoredLine({ endgame = { { profession = "blacksmithing" } } },
            profile().colors, { prefix = false }) or "", c)
        mover:SetMovable(true)
        mover:SetClampedToScreen(true)
        mover:EnableMouse(true)
        mover:RegisterForDrag("LeftButton")
        local help = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        help:SetPoint("TOP", mover, "BOTTOM", 0, -4)
        help:SetTextColor(0.667, 0.667, 0.667)
        help:SetText(L["Drag to move. Right-click when done."])
        mover:SetScript("OnDragStart", function(self) self:StartMoving() end)
        mover:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, _, x, y = self:GetPoint(1)
            Toast.SavePosition(point, x, y)
        end)
        mover:SetScript("OnMouseUp", function(self, button) if button == "RightButton" then self:Hide() end end)
    end
    local point, x, y = Toast.Position(1)
    mover:ClearAllPoints()
    mover:SetPoint(point, parent, point, x, y)
    mover:Show()
    return true
end

-- Real frame, replaceable in tests: Toast.factory() returns an object with
-- Set(icon, title, line, color), Place(index), SetAlpha(a), Show(), Hide().
function Toast.factory()
    local create = ns.Adapter.Resolve("CreateFrame")
    local parent = ns.Adapter.Resolve("UIParent")
    if type(create) ~= "function" then return nil end
    local f, set = buildFrame(create, parent, "HIGH")
    f:EnableMouse(false)
    f:Hide()
    return {
        Set = function(_, ic, title, lineText, c) set(ic, title, lineText, c) end,
        Place = function(_, index)
            local point, x, y = Toast.Position(index)
            f:ClearAllPoints()
            f:SetPoint(point, parent, point, x, y)
        end,
        SetAlpha = function(_, a) f:SetAlpha(a) end,
        Show = function() f:Show() end,
        Hide = function() f:Hide() end,
    }
end

local function content(entry)
    local result = ns.Context.Classify(entry.itemID)
    local _, kind = ns.Wording.Line(result)
    local colors = profile().colors or {}
    local c = colors[kind == "both" and "endgame" or kind] or { r = 1, g = 1, b = 1 }
    local A = ns.Adapter
    local name = (A.ItemName and A.ItemName(entry.itemID)) or entry.name or ("#" .. entry.itemID)
    local sub = ns.Wording.ColoredLine(result, colors, { prefix = false }) or ""
    return A.ItemIcon and A.ItemIcon(entry.itemID), L["%s x%d"]:format(name, entry.count), sub, c
end

-- /kt demo: three sample toasts (endgame, leveling, both), shown whatever the settings say, so the look
-- and position can be checked any time. They fade like real toasts.
Toast.DEMO = {
    { itemID = 12360, count = 1, result = { endgame = { { profession = "blacksmithing" } } } },
    { itemID = 14047, count = 20, result = { leveling = { { profession = "tailoring" } } } },
    { itemID = 12359, count = 5, result = { endgame = { { profession = "blacksmithing" } }, leveling = { { profession = "blacksmithing" } } } },
}

-- only: optional number, show just that many of the samples (1 = the endgame sample, for /kt test toast).
function Toast.Demo(only)
    local colors = profile().colors or {}
    local A = ns.Adapter
    -- Start from a clean stack: exactly three samples, never more than the usual maximum.
    for _, e in ipairs(Toast.active) do e.frame:Hide(); Toast.free[#Toast.free + 1] = e.frame end
    Toast.active = {}
    for i, d in ipairs(Toast.DEMO) do
        if only and i > only then break end
        local frame = table.remove(Toast.free) or Toast.factory()
        if not frame then return false end
        local catalog = ns.Data and ns.Data.Catalog or {}
        local name = (A.ItemName and A.ItemName(d.itemID)) or (catalog.itemNames or {})[d.itemID] or ("#" .. d.itemID)
        local kind = d.result.endgame and "endgame" or "leveling"
        frame:Set(A.ItemIcon and A.ItemIcon(d.itemID), L["%s x%d"]:format(name, d.count),
            ns.Wording.ColoredLine(d.result, colors, { prefix = false }) or "", colors[kind] or { r = 1, g = 1, b = 1 })
        local entry = { itemID = d.itemID, count = d.count, frame = frame, age = 0, demo = true }
        Toast.active[#Toast.active + 1] = entry
        frame:SetAlpha(Toast.Alpha(0))
        frame:Show()
    end
    for i, e in ipairs(Toast.active) do e.frame:Place(i) end
    return true
end

-- Shows queued toasts while there is room. Settings may have changed while one waited, so each is
-- checked again: toasts turned off drops the whole queue, an item no longer marked is dropped.
local function startNext()
    while #Toast.active < Toast.MAX and #Toast.queue > 0 do
        if not profile().toast then
            Toast.queue = {}
            break
        end
        local entry = table.remove(Toast.queue, 1)
        if ns.Wording.Line(ns.Context.Classify(entry.itemID)) then
            local frame = table.remove(Toast.free) or Toast.factory()
            if not frame then
                table.insert(Toast.queue, 1, entry)
                return
            end
            entry.frame, entry.age = frame, 0
            frame:Set(content(entry))
            frame:SetAlpha(Toast.Alpha(0))
            Toast.active[#Toast.active + 1] = entry
            frame:Show()
        end
    end
    for i, e in ipairs(Toast.active) do e.frame:Place(i) end
end

local function find(list, itemID)
    for _, e in ipairs(list) do if e.itemID == itemID then return e end end
end

-- A looted item. Returns true when it showed, queued or combined into a toast.
function Toast.Handle(itemID, count, name)
    if not profile().toast or not itemID then return false end
    count = count or 1
    local entry = find(Toast.active, itemID)
    if entry then
        entry.count = entry.count + count
        entry.frame:Set(content(entry))
        return true
    end
    entry = find(Toast.queue, itemID)
    if entry then entry.count = entry.count + count; return true end
    if Toast.seen[itemID] then return false end
    if not ns.Wording.Line(ns.Context.Classify(itemID)) then return false end
    Toast.seen[itemID] = true
    Toast.queue[#Toast.queue + 1] = { itemID = itemID, count = count, name = name }
    startNext()
    return true
end

-- Advance time by dt seconds: fade and retire toasts, then show queued ones.
function Toast.Tick(dt)
    for i = #Toast.active, 1, -1 do
        local e = Toast.active[i]
        e.age = e.age + dt
        if e.age >= Toast.SHOW then
            e.frame:Hide()
            Toast.free[#Toast.free + 1] = e.frame
            table.remove(Toast.active, i)
        else
            e.frame:SetAlpha(Toast.Alpha(e.age))
        end
    end
    startNext()
end

-- New session: toasts may show again.
function Toast.Reset()
    Toast.seen = {}
end

function Toast.OnLoot(message)
    local ok, err = pcall(function()
        local id, count, name = Toast.Parse(message, ns.Adapter.LootPatterns())
        if id then Toast.Handle(id, count, name) end
    end)
    if not ok and ns.Log then ns.Log.Failure("toast", err) end
end

-- Drives Tick from the game's frame updates; does nothing when frames are not available.
local function startDriver()
    local create = ns.Adapter.Resolve("CreateFrame")
    if type(create) ~= "function" then return end
    local f = create("Frame")
    f:SetScript("OnUpdate", function(_, dt)
        if #Toast.active > 0 then
            local ok, err = pcall(Toast.Tick, dt)
            if not ok and ns.Log then ns.Log.Failure("toast", err) end
        end
    end)
end

ns.Start(function(addon)
    addon:RegisterEvent("CHAT_MSG_LOOT", function(_, message) Toast.OnLoot(message) end)
    startDriver()
end)
