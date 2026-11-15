-- The icon mask (spec icon-mask; design D7): one ADD-blend texture per item button, in the endgame or
-- leveling color, shown only while the mask is on, the location is enabled in "Show marks in", the
-- owning integration is working and turned on, and the item is marked.
--
-- Overlay.Apply(button, itemID, location, host, owner)
--   button    the item button being drawn (never written to; it may be a secure button)
--   itemID    the item now in that slot, or nil for an empty slot
--   location  a profile.locations key: "bags", "bank", "merchant", ...
--   host      optional frame to draw on instead of the button (EllesmereUI's btn._textOverlay)
--   owner     optional ns.Integrations key; its toggle and failure state hide the texture
-- Every button that has shown an item is remembered (weakly), so Overlay.Refresh() can re-color,
-- re-classify and hide on any setting change without a rescan of the bags.
local _, ns = ...

local Overlay = {
    ALPHA = 0.4,    -- moderate, so the icon, its count and its quality border stay readable
    SUBLEVEL = 1,
}
ns.Overlay = Overlay

local records = setmetatable({}, { __mode = "k" })   -- [button] = { itemID, location, host, owner, tex }

local function profile()
    return ns.addon and ns.addon.db and ns.addon.db.profile or ns.defaults and ns.defaults.profile or {}
end

local function ownerActive(owner)
    if not owner then return true end
    local I = ns.Integrations
    if not (I and I.Active) then return true end
    return I.Active(owner)
end

-- The color for an item, or nil when it shows nothing. An item in both categories uses endgame.
local function colorFor(rec)
    local p = profile()
    if not rec.itemID or not p.mask then return nil end
    if not (p.locations and rec.location and p.locations[rec.location]) then return nil end
    if not ownerActive(rec.owner) then return nil end
    local ok, result = pcall(ns.Context.Classify, rec.itemID)
    if not ok or not result then return nil end
    local colors = p.colors or {}
    if result.endgame then return colors.endgame end
    if result.leveling then return colors.leveling end
    return nil
end

-- Our texture, made the first time it has to show. Over the icon, below the count and the border:
-- on a host frame (which already sits above the icon) in its BACKGROUND layer, under the host's text;
-- on the button itself in ARTWORK, above the icon (BORDER) and under the count and IconBorder.
local function create(button, host)
    local parent = host or button
    local tex = parent:CreateTexture(nil, host and "BACKGROUND" or "ARTWORK", nil, Overlay.SUBLEVEL)
    local anchor = host or button.icon or button.Icon or button
    tex:SetAllPoints(anchor)
    tex:Hide()
    return tex
end

local function paint(button, rec)
    local c = colorFor(rec)
    if c then
        rec.tex = rec.tex or create(button, rec.host)
        local opacity = profile().maskOpacity
        local alpha = type(opacity) == "number" and math.max(0, math.min(1, opacity)) or Overlay.ALPHA
        rec.tex:SetColorTexture(c.r or 1, c.g or 1, c.b or 1, alpha)
        rec.tex:SetBlendMode("ADD")
        rec.tex:Show()
    elseif rec.tex then
        rec.tex:Hide()
    end
end

function Overlay.Apply(button, itemID, location, host, owner)
    if type(button) ~= "table" then return end
    local rec = records[button]
    if not rec then
        if type(itemID) ~= "number" then return end    -- an empty slot we never drew on needs nothing
        rec = {}
        records[button] = rec
    end
    rec.itemID = type(itemID) == "number" and itemID or nil
    rec.location = location or rec.location
    rec.host = rec.host or host
    rec.owner = owner
    paint(button, rec)
end

-- Hide whatever this button shows (a placeholder or emptied slot).
function Overlay.Hide(button)
    Overlay.Apply(button, nil)
end

-- Re-color, re-classify and hide every known texture (a setting, color or skill changed).
function Overlay.Refresh()
    for button, rec in pairs(records) do
        local ok, err = pcall(paint, button, rec)
        if not ok then
            if ns.Log then ns.Log.Failure("overlay", err) end
            return
        end
    end
end

-- The texture KeepThat drew on a button, or nil (tests and the debug report).
function Overlay.TextureFor(button)
    local rec = records[button]
    return rec and rec.tex or nil
end

if ns.Context and ns.Context.OnChange then ns.Context.OnChange(Overlay.Refresh) end
