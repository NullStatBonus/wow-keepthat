-- The icon tint in the merchant window and its buyback tab, on both clients (spec icon-mask, "Locations
-- chosen by the player"). Like Blizzard's bags, it is not an optional integration (no toggle, not gated
-- to Forever) but is contained the same way: the paint callback is guarded, so an error turns it off
-- for the session and is logged.
local _, ns = ...
local A = ns.Adapter

local Merchant = { KEY = "merchant" }
ns.Merchant = Merchant

function Merchant.Paint()
    for _, slot in ipairs((A.MerchantSlots())) do
        ns.Overlay.Apply(slot[1], slot[2], "merchant", nil, Merchant.KEY)
    end
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
