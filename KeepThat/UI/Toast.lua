-- Loot toast (spec loot-toast, design D6): a short pop-up when the player loots a marked material.
-- Plain-Lua core (Parse, Handle, Tick) driven by an injectable frame factory; the real frames are
-- three mouse-transparent black panels near the top center.
local _, ns = ...
local L = ns.L

local Toast = {
    MAX = 3,          -- toasts visible at once
    SHOW = 4,         -- seconds a toast lasts
    FADE = 1.5,       -- the last 1.5 seconds fade out
    GLIDE = 0.2,      -- seconds to glide one place when the stack moves
    seen = {},        -- itemID -> true, one toast per item per session
    active = {},      -- visible entries { itemID, count, age, frame }
    queue = {},       -- waiting entries { itemID, count }
    samples = {},
    sampleFree = {},
    free = {},        -- idle frames
    SOUND_COOLDOWN = 2, -- seconds after a real-loot sound during which new toasts stay silent
    lastSound = nil,  -- time of the last real-loot sound
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

function Toast.Position(index, entries)
    local pos = profile().toastPosition or Toast.DEFAULT_POSITION
    local list = entries or Toast.active
    local point = pos.point or "TOP"
    -- The gap between two neighbours depends on which edge the anchor holds: a TOP anchor needs the
    -- upper panel's height, a BOTTOM anchor the lower one's, anything else half of each.
    local function height(e)
        local h = e and e.frame and e.frame.Height and e.frame:Height()
        return type(h) == "number" and h or Toast.SPACING - 8
    end
    local offset = 0
    for i = (index or 1), #list - 1 do
        local upper, lower = height(list[i]), height(list[i + 1])
        local h = point:find("TOP") and upper or point:find("BOTTOM") and lower or (upper + lower) / 2
        offset = offset + h + 8
    end
    return point, pos.x or 0, (pos.y or 0) + offset
end

-- Places every entry of a list (oldest first). A new entry starts at its place; the others glide toward
-- theirs at one spacing per GLIDE seconds as time passes (dt), so nothing jumps. snap places all at once.
function Toast.Layout(list, dt, snap)
    local speed = Toast.SPACING / Toast.GLIDE
    for i, e in ipairs(list) do
        local point, x, y = Toast.Position(i, list)
        if snap or e.y == nil or e.age == 0 then
            e.y = y
        elseif dt and dt > 0 then
            local d, step = y - e.y, speed * dt
            if math.abs(d) <= step then e.y = y else e.y = e.y + (d > 0 and step or -step) end
        end
        e.frame:Place(point, x, e.y)
    end
end

function Toast.SavePosition(point, x, y)
    if profile().toastLocked then return false end
    profile().toastPosition = { point = point or "TOP", x = math.floor((x or 0) + 0.5), y = math.floor((y or 0) + 0.5) }
    Toast.Layout(Toast.active, nil, true)
end

function Toast.ResetPosition()
    if profile().toastLocked then return false end
    Toast.CancelMove()
    local d = Toast.DEFAULT_POSITION
    Toast.SavePosition(d.point, d.x, d.y)
end

-- Toast look (Codex style review): 280x40, pure black (OLED-safe), 28px icon, neutral title, grey
-- subtitle with only the category word colored, and a thin accent bar in the category color. The whole
-- lifetime fade multiplies independent background and ink layers.
Toast.WIDTH, Toast.HEIGHT = (ns.Presentation or {}).width or 280, (ns.Presentation or {}).height or 40
Toast.FADE_IN = 0.3

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
    icon:SetPoint("LEFT", 8, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)    -- trim the default icon border
    local title = f:CreateFontString(nil, "OVERLAY", ns.Adapter.FontName and ns.Adapter.FontName("GameFontHighlightSmall") or "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", 44, -8)
    title:SetWidth(Toast.WIDTH - 52)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(true)
    title:SetTextColor(0.867, 0.867, 0.867)
    local sub = f:CreateFontString(nil, "OVERLAY", ns.Adapter.FontName and ns.Adapter.FontName("GameFontHighlightSmall") or "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetWidth(Toast.WIDTH - 52)
    sub:SetJustifyH("LEFT")
    sub:SetWordWrap(true)
    sub:SetTextColor(0.667, 0.667, 0.667)
    local function style()
        local p = profile()
        local bgAlpha = p.toastBackgroundOpacity
        if bgAlpha == nil then bgAlpha = p.toastOpacity or 1 end
        local ink = p.toastTextOpacity
        if ink == nil then ink = p.toastOpacity or 1 end
        bg:SetAlpha(bgAlpha); accent:SetAlpha(bgAlpha)
        icon:SetAlpha(ink); title:SetAlpha(ink); sub:SetAlpha(ink)
        f:SetScale(p.toastScale or 1)
    end
    local function set(ic, titleText, subText, c)
        style()
        icon:SetTexture(ic or 134400)
        title:SetText(titleText)
        sub:SetText(subText)
        accent:SetColorTexture(c.r, c.g, c.b, 0.45)
        local th = title.GetStringHeight and title:GetStringHeight() or 12
        local sh = sub.GetStringHeight and sub:GetStringHeight() or 12
        f:SetHeight(math.max(Toast.HEIGHT, th + sh + 20))
    end
    return f, set, style
end

-- The toast's alpha at a given age: a short fade in, hold, then fade out over the last FADE seconds,
-- independent of background and text/icon opacity.
function Toast.Alpha(age)
    local a = 1
    if age < Toast.FADE_IN then a = age / Toast.FADE_IN
    elseif age > Toast.SHOW - Toast.FADE then a = (Toast.SHOW - age) / Toast.FADE end
    a = math.max(0, math.min(1, a))
    return a
end

-- Move is a transaction; dragging never writes SavedVariables.
local mover, moverStyle
local function notifyMove()
    if ns.Options and ns.Options.NotifyChange then pcall(ns.Options.NotifyChange) end
end
function Toast.BeginMove()
    if profile().toastLocked then return false end
    if Toast.move then return true end
    local point, x, y = Toast.Position(1, {})
    Toast.move = { profile = profile(), point = point, x = x, y = y }
    notifyMove()
    return true
end
function Toast.TentativePosition(point, x, y)
    if not Toast.move or profile().toastLocked then return false end
    Toast.move.point, Toast.move.x, Toast.move.y = point, x, y
    return true
end
function Toast.CancelMove()
    local wasMoving = Toast.move ~= nil
    Toast.move = nil
    if mover then mover:StopMovingOrSizing(); mover:Hide() end
    if wasMoving then notifyMove() end
end
function Toast.DoneMove()
    local m = Toast.move
    if not m then return false end
    if m.profile ~= profile() or profile().toastLocked then Toast.CancelMove(); return false end
    if mover and mover:IsShown() then
        mover:StopMovingOrSizing()
        local point, _, _, x, y = mover:GetPoint(1)
        m.point, m.x, m.y = point, x, y
    end
    Toast.SavePosition(m.point, m.x, m.y)
    Toast.CancelMove()
    return true
end
local function showMover()
    if not Toast.BeginMove() then return false end
    local create = ns.Adapter.Resolve("CreateFrame")
    local parent = ns.Adapter.Resolve("UIParent")
    if type(create) ~= "function" then Toast.CancelMove(); return false end
    if not mover then
        local set
        mover, set, moverStyle = buildFrame(create, parent, "DIALOG")
        set(134400, L["Sample — Arcanite Bar x1"], L["Drag to move. Done saves; Cancel or Escape restores."],
            (profile().colors or {}).endgame or { r = 0.64, g = 0.21, b = 0.93 })
        mover:SetMovable(true); mover:SetClampedToScreen(true); mover:EnableMouse(true)
        mover:RegisterForDrag("LeftButton")
        mover:SetScript("OnDragStart", function(self) if Toast.move and not profile().toastLocked then self:StartMoving() end end)
        mover:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, _, x, y = self:GetPoint(1)
            Toast.TentativePosition(point, x, y)
        end)
        mover:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then Toast.DoneMove() end end)
        -- Escape is guarded for clients without keyboard support.
        if not (mover.EnableKeyboard and mover.SetPropagateKeyboardInput) then error("keyboard controls unavailable") end
        if mover.EnableKeyboard then
            mover:EnableKeyboard(true)
            mover:SetScript("OnKeyDown", function(self, key)
                if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(key ~= "ESCAPE") end
                if key == "ESCAPE" then Toast.CancelMove() end
            end)
        end
        for i, label in ipairs({ L["Done"], L["Cancel"] }) do
            local b = create("Button", nil, mover, "UIPanelButtonTemplate")
            b:SetSize(100, 24); b:SetPoint("TOPLEFT", mover, "BOTTOMLEFT", (i - 1) * 108, -8)
            b:SetText(label); b:SetScript("OnClick", i == 1 and Toast.DoneMove or Toast.CancelMove)
        end
    end
    if moverStyle then moverStyle() end
    local point, x, y = Toast.Position(1, {})
    mover:ClearAllPoints(); mover:SetPoint(point, parent, point, x, y); mover:Show()
    return true
end

function Toast.ShowMover()
    local ok, result = pcall(showMover)
    if not ok or not result then
        Toast.CancelMove()
        if ns.addon and ns.addon.Print then ns.addon:Print(L["Move is unavailable. Unlock the position and check that frame controls are available."]) end
        return false
    end
    return true
end

-- Real frame, replaceable in tests: Toast.factory() returns an object with
-- Set(icon, title, line, color), Place(point, x, y), SetAlpha(a), Show(), Hide().
function Toast.factory()
    local create = ns.Adapter.Resolve("CreateFrame")
    local parent = ns.Adapter.Resolve("UIParent")
    if type(create) ~= "function" then return nil end
    local f, set, style = buildFrame(create, parent, "HIGH")
    f:EnableMouse(false)
    f:Hide()
    return {
        Set = function(_, ic, title, lineText, c) set(ic, title, lineText, c) end,
        Place = function(self, point, x, y)
            if self.placed == point .. ":" .. x .. ":" .. y then return end
            self.placed = point .. ":" .. x .. ":" .. y
            f:ClearAllPoints()
            f:SetPoint(point, parent, point, x, y)
        end,
        SetAlpha = function(_, a)
            style()
            f:SetAlpha(a)
        end,
        Height = function() return f:GetHeight() end,
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

-- The chosen toast sound, once (spec loot-toast, "Toast sound"; design D4). Model/Sounds.lua falls back
-- to the default and contains any error.
local function playSound()
    if not (ns.Sounds and ns.Sounds.Play) then return false end
    local p = profile()
    return ns.Sounds.Play(p.toastSound, p.toastSoundChannel, ns.Adapter)
end

-- Real loot: one sound per burst. A toast accepted within SOUND_COOLDOWN seconds of the last sound is
-- silent, including toasts that wait in the queue and show later. Unknown time: play, record nothing.
function Toast.Chime()
    local now = ns.Adapter.Now and ns.Adapter.Now()
    if type(now) == "number" then
        if Toast.lastSound and now - Toast.lastSound < Toast.SOUND_COOLDOWN then return false end
        Toast.lastSound = now
    end
    return playSound()
end

-- only: optional number, show just that many of the samples (1 = the endgame sample, for /kt test toast).
function Toast.Demo(only)
    local colors = profile().colors or {}
    local A = ns.Adapter
    -- Start from a clean stack: exactly three samples, never more than the usual maximum.
    for _, e in ipairs(Toast.samples) do e.frame:Hide(); Toast.sampleFree[#Toast.sampleFree + 1] = e.frame end
    Toast.samples = {}
    for i, d in ipairs(Toast.DEMO) do
        if only and i > only then break end
        local frame = table.remove(Toast.sampleFree) or Toast.factory()
        if not frame then return false end
        local catalog = ns.Data and ns.Data.Catalog or {}
        local name = (A.ItemName and A.ItemName(d.itemID)) or (catalog.itemNames or {})[d.itemID] or ("#" .. d.itemID)
        local kind = d.result.endgame and "endgame" or "leveling"
        frame:Set(A.ItemIcon and A.ItemIcon(d.itemID), L["Sample — %s x%d"]:format(name, d.count),
            ns.Wording.ColoredLine(d.result, colors, { prefix = false }) or "", colors[kind] or { r = 1, g = 1, b = 1 })
        local entry = { itemID = d.itemID, count = d.count, frame = frame, age = 0, demo = true }
        Toast.samples[#Toast.samples + 1] = entry
        frame:SetAlpha(Toast.Alpha(0))
        frame:Show()
    end
    for _, e in ipairs(Toast.active) do e.frame:Hide() end
    Toast.Layout(Toast.samples, nil, true)
    playSound() -- samples: once per request, whatever the toast setting and cooldown, without recording
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
            if #Toast.samples == 0 then frame:Show() else frame:Hide() end
        end
    end
    Toast.Layout(Toast.active)
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
    Toast.Chime()
    startNext()
    return true
end

-- Advance time by dt seconds: fade and retire toasts, then show queued ones.
function Toast.Tick(dt)
    local hidden = #Toast.samples > 0 -- real toasts hidden behind samples at the start of this tick
    for i = #Toast.samples, 1, -1 do
        local e = Toast.samples[i]; e.age = e.age + dt
        if e.age >= Toast.SHOW then e.frame:Hide(); Toast.sampleFree[#Toast.sampleFree + 1] = e.frame; table.remove(Toast.samples, i)
        else e.frame:SetAlpha(Toast.Alpha(e.age)) end
    end
    for i = #Toast.active, 1, -1 do
        local e = Toast.active[i]
        -- Hidden behind samples: its life (and fade-in) waits until they clear.
        if not hidden then e.age = e.age + dt end
        if e.age >= Toast.SHOW then
            e.frame:Hide()
            Toast.free[#Toast.free + 1] = e.frame
            table.remove(Toast.active, i)
        else
            e.frame:SetAlpha(Toast.Alpha(e.age))
        end
    end
    startNext()
    Toast.Layout(Toast.active, dt)
    Toast.Layout(Toast.samples, dt)
    for _, e in ipairs(Toast.active) do
        if #Toast.samples > 0 then e.frame:Hide() else e.frame:Show() end
    end
end

function Toast.Refresh()
    if moverStyle then moverStyle() end
    for _, list in ipairs({ Toast.active, Toast.samples }) do
        for i, e in ipairs(list) do
            if not e.demo then e.frame:Set(content(e))
            else
                local d = Toast.DEMO[i]
                local name = (ns.Adapter.ItemName and ns.Adapter.ItemName(d.itemID)) or
                    (ns.Data and ns.Data.Catalog and ns.Data.Catalog.itemNames or {})[d.itemID] or ("#" .. d.itemID)
                local colors = profile().colors or {}
                e.frame:Set(ns.Adapter.ItemIcon and ns.Adapter.ItemIcon(d.itemID), L["Sample — %s x%d"]:format(name, d.count),
                    ns.Wording.ColoredLine(d.result, colors, { prefix = false }) or "",
                    colors[d.result.endgame and "endgame" or "leveling"] or { r = 1, g = 1, b = 1 })
            end
            e.frame:SetAlpha(Toast.Alpha(e.age))
        end
        Toast.Layout(list)
    end
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
        if #Toast.active > 0 or #Toast.samples > 0 then
            local ok, err = pcall(Toast.Tick, dt)
            if not ok and ns.Log then ns.Log.Failure("toast", err) end
        end
    end)
end

ns.Start(function(addon)
    addon:RegisterEvent("CHAT_MSG_LOOT", function(_, message) Toast.OnLoot(message) end)
    startDriver()
end)
