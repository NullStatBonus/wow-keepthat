-- The icon mask in Baganator (spec icon-mask; design D7). Baganator's only public item-button API is
-- Baganator.API.RegisterCornerWidget, which shows the first widget in each icon corner and only where
-- the player placed it, so it cannot draw a whole-icon tint without hiding other corner widgets. This
-- hooks SetItemDetails on Baganator's item button mixins instead (the globals
-- Baganator<Retail|Classic><Live|Cached>...ItemButtonMixin). A template copies the mixin when a button is
-- built, so the hooks go in at login, before any bag view exists. The item comes from the button's
-- Baganator data (button.BGR.itemID), which also covers other characters' bags; the bag ID from the
-- button's parent decides bags or bank. If no mixin is found the integration turns itself off.
local _, ns = ...
local A = ns.Adapter

local Baganator = { KEY = "baganator" }
ns.Baganator = Baganator

Baganator.MIXINS = {
    "BaganatorRetailLiveContainerItemButtonMixin",
    "BaganatorClassicLiveContainerItemButtonMixin",
    "BaganatorRetailCachedItemButtonMixin",
    "BaganatorClassicCachedItemButtonMixin",
    "BaganatorRetailLiveWarbandItemButtonMixin",
}

function Baganator.Detect()
    return type(A.Resolve("Baganator")) == "table"
end

function Baganator.Paint(button)
    local bgr = rawget(button, "BGR")
    local itemID = type(bgr) == "table" and bgr.itemID or nil
    local parent = A.CallMethod(button, "GetParent")
    local bag = A.CallMethod(button, "GetBagID")
    if bag == nil and parent then bag = A.CallMethod(parent, "GetID") end
    ns.Overlay.Apply(button, itemID, A.BagLocation(bag) or "bags", nil, Baganator.KEY)
end

function Baganator.Start(ctx)
    local paint = ctx.guard(Baganator.Paint)
    local any = false
    for _, name in ipairs(Baganator.MIXINS) do
        local mixin = A.Resolve(name)
        if A.HookMethod(mixin, "SetItemDetails", paint) then any = true end
    end
    if not any then return false, "no Baganator item button mixin with SetItemDetails" end
end

ns.Integrations.Register(Baganator.KEY, { detect = Baganator.Detect, start = Baganator.Start })
