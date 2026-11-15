-- UI/Overlay.lua with fake buttons: the tint, the both-categories color, a moved item, a location turned
-- off, a color change, the mask turned off, a host frame, and an owner turned off or failed.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local function copy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end

local function fakeTexture(parent, layer, sublevel)
    local t = { parent = parent, layer = layer, sublevel = sublevel, shown = true }
    function t:SetAllPoints(a) self.anchor = a end
    function t:SetColorTexture(r, g, b, a) self.r, self.g, self.b, self.a = r, g, b, a end
    function t:SetBlendMode(m) self.blend = m end
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    return t
end

local function fakeButton()
    local b = { created = 0 }
    b.icon = { name = "icon" }
    function b:CreateTexture(_, layer, _, sub) self.created = self.created + 1; return fakeTexture(self, layer, sub) end
    return b
end

local ns = { Start = function() end }
H.locale(ns)
H.load("Core/Defaults.lua", ns)
local profile = copy(ns.defaults.profile)
profile.mask = true
ns.addon = { db = { profile = profile } }

-- 1 Arcanite Bar = endgame, 2 = leveling, 3 = both, 4 = unmarked
local marks = { [1] = { endgame = {} }, [2] = { leveling = {} }, [3] = { endgame = {}, leveling = {} } }
local listeners = {}
ns.Context = {
    Classify = function(id) return marks[id] end,
    OnChange = function(fn) listeners[#listeners + 1] = fn end,
}
H.load("UI/Overlay.lua", ns)
local O = ns.Overlay
eq(listeners[1], O.Refresh, "Overlay.Refresh is registered with Context.OnChange")

local purple, green = profile.colors.endgame, profile.colors.leveling

-- Tint
local b = fakeButton()
O.Apply(b, 1, "bags")
local t = O.TextureFor(b)
eq(t ~= nil and t.shown, true, "an endgame item in bags is tinted")
eq(t.r, purple.r, "in the endgame color")
eq(t.blend, "ADD", "with ADD blend")
eq(t.a >= 0.35 and t.a <= 0.45, true, "at a moderate alpha")
eq(t.anchor, b.icon, "over the icon")
eq(t.layer, "ARTWORK", "on the button below the count and border")
eq(b.created, 1, "one texture")
O.Apply(b, 1, "bags")
eq(b.created, 1, "a repaint reuses the texture")

-- Leveling and both
local b2, b3 = fakeButton(), fakeButton()
O.Apply(b2, 2, "bags"); O.Apply(b3, 3, "bags")
eq(O.TextureFor(b2).g, green.g, "a leveling item uses the leveling color")
eq(O.TextureFor(b3).r, purple.r, "an item in both categories uses the endgame color")
eq(O.TextureFor(b3).g, purple.g, "an item in both categories uses the endgame color (green part)")

-- Unmarked and empty slots create nothing
local b4 = fakeButton()
O.Apply(b4, 4, "bags"); O.Apply(fakeButton(), nil, "bags")
eq(O.TextureFor(b4), nil, "an unmarked item gets no texture")

-- Moved item: an unmarked item (or nothing) takes the slot
O.Apply(b, 4, "bags")
eq(O.TextureFor(b).shown, false, "the slot hides when an unmarked item takes its place")
O.Apply(b, 1, "bags"); eq(t.shown, true, "and shows again when the marked item comes back")
O.Apply(b, nil, "bags")
eq(t.shown, false, "an emptied slot hides")
O.Apply(b, 1, "bags")

-- Location off
profile.locations.merchant = false
local m = fakeButton()
O.Apply(m, 1, "merchant")
eq(O.TextureFor(m), nil, "merchant icons show nothing while Merchant is off")
profile.locations.merchant = true
O.Refresh()
eq(O.TextureFor(m).shown, true, "a known merchant icon shows once Merchant is on")
profile.locations.merchant = false
O.Refresh()
eq(O.TextureFor(m).shown, false, "and hides again when it is turned off")
profile.locations.bags = false; O.Refresh()
eq(t.shown, false, "bags off hides bag icons")
profile.locations.bags = true; O.Refresh()
eq(t.shown, true, "bags on shows them again")

-- Color change recolors without a repaint by the bag
profile.colors.endgame = { r = 1, g = 0.5, b = 0 }
for _, fn in ipairs(listeners) do fn() end
eq(t.r, 1, "the endgame color change reaches a showing icon")
eq(t.g, 0.5, "orange")

-- Leveling turned on: a known item that becomes marked shows without a repaint by the bag
O.Apply(b4, 4, "bags")
marks[4] = { leveling = {} }
O.Refresh()
eq(O.TextureFor(b4) ~= nil and O.TextureFor(b4).shown, true, "a known slot whose item becomes marked shows")
marks[4] = nil; O.Refresh()

-- Mask off hides everything
profile.mask = false; O.Refresh()
eq(t.shown or O.TextureFor(b2).shown or O.TextureFor(b3).shown, false, "mask off hides every texture")
local b5 = fakeButton(); O.Apply(b5, 1, "bags")
eq(O.TextureFor(b5), nil, "mask off draws nothing new")
profile.mask = true; O.Refresh()
eq(t.shown, true, "mask on shows them again")

-- Host frame (EllesmereUI's btn._textOverlay)
local host = fakeButton()
local e = fakeButton()
O.Apply(e, 1, "bags", host)
eq(O.TextureFor(e).parent, host, "with a host, the texture is made on the host")
eq(O.TextureFor(e).anchor, host, "and covers it")
eq(O.TextureFor(e).layer, "BACKGROUND", "below the host's own text")
eq(e.created, 0, "nothing is made on the button itself")

-- Owner: hidden while its integration is not active
local active = { bagnon = true }
ns.Integrations = { Active = function(k) return active[k] or false end }
local o = fakeButton()
O.Apply(o, 1, "bags", nil, "bagnon")
eq(O.TextureFor(o).shown, true, "an active owner's button shows")
active.bagnon = false; O.Refresh()
eq(O.TextureFor(o).shown, false, "an owner turned off hides its buttons")
eq(t.shown, true, "and others are unaffected")

-- Tint strength follows the "Icon tint strength" setting (OLED: dimmable); 0.4 by default.
profile.maskOpacity = 0.2
O.Refresh()
local probe = fakeButton()
O.Apply(probe, 1, "bags")
local tex = O.TextureFor(probe)
eq(tex and tex.a, 0.2, "tint alpha follows the setting")
profile.maskOpacity = nil

-- A classify error is contained
ns.Context.Classify = function() error("boom") end
local x = fakeButton(); O.Apply(x, 1, "bags")
eq(O.TextureFor(x), nil, "a classify error draws nothing and raises nothing")

H.done()
