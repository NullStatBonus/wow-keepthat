-- The icon mask in Baganator (spec icon-mask; design D7). Baganator's only public item-button API is
-- Baganator.API.RegisterCornerWidget, which shows the first widget in each icon corner and only where
-- the player placed it, so it cannot draw a whole-icon tint without hiding other corner widgets. This
-- hooks SetItemDetails on Baganator's item button mixins instead (the globals
-- Baganator<Retail|Classic><Live|Cached>...ItemButtonMixin). A template copies the mixin when a button is
-- built, so the hooks go in at login, before any bag view exists. The item comes from the button's
-- Baganator data (button.BGR.itemID), which also covers other characters' bags; the view the button is
-- in (or, failing that, the bag ID from its parent) decides bags or bank. Until a mixin exists Baganator counts as not detected; if
-- neither the mixins nor the buttons can be hooked the integration turns itself off.
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

-- The mixins that are defined and have SetItemDetails.
local function mixins()
    local found = {}
    for _, name in ipairs(Baganator.MIXINS) do
        local mixin = A.Resolve(name)
        if type(mixin) == "table" and type(rawget(mixin, "SetItemDetails")) == "function" then
            found[#found + 1] = mixin
        end
    end
    return found
end

-- Baganator counts as present only once its item button mixins exist: they can appear after
-- KeepThat starts, and the gate tries again when another addon finishes loading.
function Baganator.Detect()
    return type(A.Resolve("Baganator")) == "table" and #mixins() > 0
end

-- Which Baganator view a button is in, from the names of its ancestors (Baganator_SingleViewBankViewFrame1,
-- Baganator_CategoryViewBackpackViewFrame1, Baganator_SingleViewGuildViewFrame1, ...): "bank", "bags",
-- "guild" or nil. Cached views parent their buttons to the layout, which has no bag ID.
function Baganator.View(button)
    local frame = button
    for _ = 1, 12 do
        frame = A.CallMethod(frame, "GetParent")
        if not frame then return nil end
        local name = A.CallMethod(frame, "GetName")
        if type(name) == "string" and name:find("^Baganator_") then
            if name:find("GuildView", 1, true) then return "guild" end
            if name:find("BankView", 1, true) then return "bank" end
            if name:find("BackpackView", 1, true) then return "bags" end
        end
    end
    return nil
end

function Baganator.Paint(button)
    -- "guild" is not a tint location, so cached guild bank buttons stay untinted.
    local view = Baganator.View(button)
    local bgr = rawget(button, "BGR")
    local itemID = type(bgr) == "table" and bgr.itemID or nil
    local location = view
    if not location then
        local parent = A.CallMethod(button, "GetParent")
        local bag = A.CallMethod(button, "GetBagID")
        if bag == nil and parent then bag = A.CallMethod(parent, "GetID") end
        location = A.BagLocation(bag) or "bags"
    end
    ns.Overlay.Apply(button, itemID, location, nil, Baganator.KEY)
end

-- Baganator 860 freezes its mixins (table.freeze), so their methods cannot be hooked. Each button
-- gets its own copy of the methods from the template, and Baganator reports every button it builds
-- through its public skin API (Skins.GetAllFrames, Skins.RegisterListener; regionType "ItemButton").
-- A button whose SetItemDetails is still one of the bag mixins' own functions gets its own hook and
-- is painted at once. Bag-slot and live guild buttons use other methods and are skipped; cached guild
-- buttons share the bag methods and Paint leaves them untinted. Older Baganator versions without
-- frozen mixins also get the mixin hook, for buttons built after it.
local adopted = setmetatable({}, { __mode = "k" })

function Baganator.Start(ctx)
    local paint = ctx.guard(Baganator.Paint)
    local found, hooked = mixins(), 0
    local originals = {}
    for _, mixin in ipairs(found) do
        originals[rawget(mixin, "SetItemDetails")] = true
        if A.HookMethod(mixin, "SetItemDetails", paint) then hooked = hooked + 1 end
    end
    local adopt = ctx.guard(function(details)
        if type(details) ~= "table" or details.regionType ~= "ItemButton" then return end
        local button = details.region
        if type(button) ~= "table" or adopted[button] then return end
        local ok, method = pcall(function() return button.SetItemDetails end)
        if not ok or not originals[method] then return end
        if A.HookMethod(button, "SetItemDetails", paint) then
            adopted[button] = true
            paint(button)
        elseif ns.Log then
            ns.Log.Record(Baganator.KEY, "an item button could not be hooked; it shows no tint")
        end
    end)
    local listening = A.Has("Baganator.API.Skins.RegisterListener")
    if listening then
        A.Call("Baganator.API.Skins.RegisterListener", adopt)
        local frames = A.Call("Baganator.API.Skins.GetAllFrames")
        for _, details in ipairs(type(frames) == "table" and frames or {}) do adopt(details) end
    end
    if hooked == 0 and not listening then
        return false, ("no Baganator item button mixin with SetItemDetails could be hooked (%d found)"):format(#found)
    end
end

ns.Integrations.Register(Baganator.KEY, { detect = Baganator.Detect, start = Baganator.Start })
