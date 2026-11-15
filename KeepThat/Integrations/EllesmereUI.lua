-- The icon mask in EllesmereUI Bags (spec icon-mask; design D7; contract in docs/contracts.md). Uses its
-- public painter API: EUI_Bags.RegisterItemOverlayIcon("KeepThat", fn(btn, data)), called for every
-- painted slot of the bags, reagent bag and bank, grid and list. The item comes from data.info.itemID
-- (the button's own GetItemID returns nil), our texture goes on btn._textOverlay and is tracked in
-- UI/Overlay.lua's table, never on the secure button. A button without _textOverlay means a changed
-- EllesmereUI: the integration turns itself off, unregisters, and logs why. EllesmereUI reports a
-- painter error through the error handler, so the painter is guarded here as well.
local _, ns = ...
local A = ns.Adapter

local EUI = { KEY = "ellesmereui", NAME = "KeepThat" }
ns.EllesmereUI = EUI

local function bags()
    local t = A.Resolve("EUI_Bags")
    return type(t) == "table" and type(t.RegisterItemOverlayIcon) == "function" and t or nil
end

function EUI.Detect()
    return bags() ~= nil
end

function EUI.Paint(btn, data)
    if type(data) ~= "table" or (data.bag == 0 and data.slot == 0) then   -- placeholder slot
        ns.Overlay.Hide(btn)
        return
    end
    local host = type(btn) == "table" and rawget(btn, "_textOverlay")
    if type(host) ~= "table" then error("EllesmereUI item button has no _textOverlay", 0) end
    local info = data.info
    local itemID = type(info) == "table" and info.itemID or nil
    ns.Overlay.Apply(btn, itemID, A.BagLocation(data.bag) or "bags", host, EUI.KEY)
end

-- Ask EllesmereUI to repaint its bags and bank (both are methods).
function EUI.Repaint()
    local b = bags()
    if b then A.CallMethod(b, "RefreshInventory") end
    local bank = A.Resolve("EUI_BankFrame")
    if type(bank) == "table" then A.CallMethod(bank, "RefreshBank") end
end

function EUI.Stop()
    local b = bags()
    if b and type(b.UnregisterItemOverlayIcon) == "function" then pcall(b.UnregisterItemOverlayIcon, EUI.NAME) end
end

local lastSig
local function signature()
    local p = ns.addon and ns.addon.db and ns.addon.db.profile or ns.defaults.profile
    return tostring(p.mask) .. tostring(p.integrations and p.integrations[EUI.KEY])
end

function EUI.Start(ctx)
    local b = bags()
    b.RegisterItemOverlayIcon(EUI.NAME, ctx.guard(EUI.Paint))
    lastSig = signature()
    -- Known buttons are re-colored by Overlay.Refresh; the mask or this toggle changing also repaints,
    -- so slots drawn while it was off get their marks.
    ns.Context.OnChange(function()
        local sig = signature()
        if sig ~= lastSig and ns.Integrations.Active(EUI.KEY) then lastSig = sig; EUI.Repaint() end
        lastSig = sig
    end)
end

ns.Integrations.Register(EUI.KEY, { detect = EUI.Detect, start = EUI.Start, stop = EUI.Stop })
