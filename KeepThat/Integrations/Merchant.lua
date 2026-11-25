-- The icon tint in the merchant window and its buyback tab, on both clients (spec icon-mask, "Locations
-- chosen by the player"). Like Blizzard's bags, it is not an optional integration (no toggle, not gated
-- to Forever) but is contained the same way: the paint callback is guarded, so an error turns it off
-- for the session and is logged.
local _, ns = ...
local A = ns.Adapter

local Merchant = { KEY = "merchant" }
ns.Merchant = Merchant

local lastShown   -- the key of the last "tinted" line; cleared when the merchant closes

-- One debug line each time a page is shown: not again while the page and its counts stay the same.
local function logTinted(slots, buyback, page)
    if not (ns.Log and ns.Log.Record) then return end
    local n, m = 0, 0
    for _, slot in ipairs(slots) do
        if type(slot[2]) == "number" then
            m = m + 1
            if A.TextureShown(ns.Overlay.TextureFor(slot[1])) then n = n + 1 end
        end
    end
    local where = buyback and "buyback" or ("page " .. (page or 1))
    local key = ("%s:%d:%d"):format(where, n, m)
    if key == lastShown then return end
    lastShown = key
    ns.Log.Record(Merchant.KEY, ("tinted %d of %d on %s"):format(n, m, where))
end

function Merchant.Paint()
    local slots, buyback, page = A.MerchantSlots()
    for _, slot in ipairs(slots) do
        ns.Overlay.Apply(slot[1], slot[2], "merchant", nil, Merchant.KEY)
    end
    logTinted(slots, buyback, page)
end

-- Opening the merchant again shows its page again, so the next paint writes its line again.
if ns.Start then
    ns.Start(function(addon)
        if ns.Listen then ns.Listen(addon, "MERCHANT_CLOSED", function() lastShown = nil end) end
    end)
end

function Merchant.Detect()
    return A.Has("MerchantFrame_UpdateMerchantInfo")
end

function Merchant.Start(ctx)
    local paths = A.HookMerchant(ctx.guard(Merchant.Paint))
    if #paths == 0 then return false, "no merchant update function to hook" end
    if ns.Log then ns.Log.Record(Merchant.KEY, "hooked " .. table.concat(paths, ", ")) end
end

ns.Integrations.Register(Merchant.KEY, { detect = Merchant.Detect, start = Merchant.Start, anyClient = true })
