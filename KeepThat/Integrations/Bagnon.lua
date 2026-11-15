-- The icon mask in Bagnon (spec icon-mask; design D7). Bagnon's item buttons are BagBrother classes,
-- reachable as Bagnon.ContainerItem (container slots) and Bagnon.Item (the base). Each button gets a copy
-- of the class methods when it is built (Item:Bind, from a list cached on the class as __bindList), so
-- the hook on Update is installed at login, before any bag is opened; if the list is already cached,
-- it is hooked too. The item comes from the button's own info (Bagnon also shows other characters'
-- bags), never from the live container.
local _, ns = ...
local A = ns.Adapter

local Bagnon = { KEY = "bagnon" }
ns.Bagnon = Bagnon

local function class()
    for _, path in ipairs({ "Bagnon.ContainerItem", "Bagnon.Item" }) do
        local c = A.Resolve(path)
        if type(c) == "table" then return c end
    end
    return nil
end

function Bagnon.Detect()
    return class() ~= nil
end

function Bagnon.Paint(button)
    local info = rawget(button, "info")
    local itemID = type(info) == "table" and info.itemID or nil
    local bag = rawget(button, "bag")
    if bag == nil then bag = A.CallMethod(button, "GetBag") end
    ns.Overlay.Apply(button, itemID, A.BagLocation(bag) or "bags", nil, Bagnon.KEY)
end

function Bagnon.Start(ctx)
    local c = class()
    local paint = ctx.guard(Bagnon.Paint)
    if not A.HookMethod(c, "Update", paint) then return false, "Bagnon's item button has no Update method" end
    local list = rawget(c, "__bindList")
    if type(list) == "table" and A.HookMethod(list, "Update", paint) and ns.Log then
        ns.Log.Record(Bagnon.KEY, "item buttons built before KeepThat started show no marks until a reload")
    end
end

ns.Integrations.Register(Bagnon.KEY, { detect = Bagnon.Detect, start = Bagnon.Start })
