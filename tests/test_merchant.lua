-- Merchant tint (spec icon-mask, merchant location): which item each merchant button shows on any page,
-- the buyback tab, the hooks, and painting through the overlay with location "merchant".
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ns = H.locale({})
H.load("Core/Adapter.lua", ns)
H.load("Core/Adapter_Bags.lua", ns)
H.load("Core/Adapter_Merchant.lua", ns)

local registered
ns.Integrations = { Register = function(key, spec) registered = { key = key, spec = spec } end }
local painted = {}
ns.Overlay = { Apply = function(button, id, location, host, owner) painted[#painted + 1] = { button, id, location, owner } end }
H.load("Integrations/Merchant.lua", ns)

local hooks = {}
local env = {
    MERCHANT_ITEMS_PER_PAGE = 10, BUYBACK_ITEMS_PER_PAGE = 12,
    MerchantFrame = { selectedTab = 1, page = 2 },
    GetMerchantItemID = function(i) return i == 13 and 3371 or nil end,          -- Crystal Vial at index 13
    GetMerchantItemLink = function(i) return i == 14 and "|cff|Hitem:8925::|h[Crystal Vial]|h|r" or nil end,
    GetBuybackItemLink = function(i) return i == 1 and "|Hitem:12360:|h" or nil end,
    MerchantFrame_UpdateMerchantInfo = function() end,
    MerchantFrame_UpdateBuybackInfo = function() end,
    hooksecurefunc = function(name, fn) hooks[name] = fn end,
}
for i = 1, 12 do env["MerchantItem" .. i .. "ItemButton"] = { i = i } end
env._G = env
ns.Adapter.env = env

-- Page 2 of the merchant: button 3 shows index 13.
local slots, buyback = ns.Adapter.MerchantSlots()
eq(buyback, false, "the merchant tab")
eq(#slots, 10, "one entry per merchant button on the page")
eq(slots[3][2], 3371, "page 2, button 3 is merchant index 13")
eq(slots[4][2], 8925, "an item ID from the link when GetMerchantItemID has none")
eq(slots[1][2], nil, "an empty slot")

-- The buyback tab.
env.MerchantFrame.selectedTab = 2
slots, buyback = ns.Adapter.MerchantSlots()
eq(buyback, true, "the buyback tab")
eq(#slots, 12, "twelve buyback buttons")
eq(slots[1][2], 12360, "the item sold back")
env.MerchantFrame.selectedTab = 1

-- Registered for both clients, hooks both redraws, and paints with location "merchant".
eq(registered.key, "merchant", "registered")
eq(registered.spec.anyClient, true, "runs on Classic Era too")
eq(registered.spec.detect() and true, true, "detected when the merchant frame exists")
local result = registered.spec.start({ guard = function(fn) return fn end })
eq(result, nil, "started")
eq(type(hooks.MerchantFrame_UpdateMerchantInfo), "function", "merchant redraw hooked")
eq(type(hooks.MerchantFrame_UpdateBuybackInfo), "function", "buyback redraw hooked")
hooks.MerchantFrame_UpdateMerchantInfo()
eq(#painted, 10, "every button painted")
eq(painted[3][2] == 3371 and painted[3][3] == "merchant" and painted[3][4] == "merchant", true, "location and owner")

-- No merchant API: does not start, says why.
ns.Adapter.env = { _G = {} }
local ok, why = registered.spec.start({ guard = function(fn) return fn end })
eq(ok, false, "nothing to hook")
eq(why, "no merchant update function to hook", "the reason")
eq(#ns.Adapter.MerchantSlots(), 0, "no merchant frame: no slots")

H.done()
