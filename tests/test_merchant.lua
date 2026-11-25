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
local textures = {}   -- [button] = fake texture; tinted when the item is 3371 or 12360
ns.Overlay = {
    Apply = function(button, id, location, host, owner)
        painted[#painted + 1] = { button, id, location, owner }
        textures[button] = textures[button] or { shown = false, IsShown = function(self) return self.shown end }
        textures[button].shown = id == 3371 or id == 12360
    end,
    TextureFor = function(button) return textures[button] end,
}
local logs = {}
ns.Log = { Record = function(area, msg) logs[#logs + 1] = ("[%s] %s"):format(area, msg) end }
local events = {}
ns.Start = function(fn) fn({ RegisterEvent = function(_, e, f) events[e] = f end }) end
ns.Listen = function(target, e, f) target:RegisterEvent(e, f) return true end
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

-- Debug lines: one per page shown, not per repaint.
eq(logs[#logs], "[merchant] tinted 1 of 2 on page 2", "the page line counts tinted and item buttons")
local before = #logs
for _ = 1, 50 do hooks.MerchantFrame_UpdateMerchantInfo() end
eq(#logs, before, "50 repaints of the same page write nothing more")
env.MerchantFrame.page = 1
hooks.MerchantFrame_UpdateMerchantInfo()
eq(#logs, before + 1, "another page writes a line")
eq(logs[#logs], "[merchant] tinted 0 of 0 on page 1", "an empty page counts zero")
env.MerchantFrame.page = 2
hooks.MerchantFrame_UpdateMerchantInfo()
eq(logs[#logs], "[merchant] tinted 1 of 2 on page 2", "back to page 2 writes it again")
env.MerchantFrame.selectedTab = 2
hooks.MerchantFrame_UpdateBuybackInfo()
eq(logs[#logs], "[merchant] tinted 1 of 1 on buyback", "the buyback line")
hooks.MerchantFrame_UpdateBuybackInfo()
eq(#logs, before + 3, "repainting the buyback writes nothing more")
env.MerchantFrame.selectedTab = 1
hooks.MerchantFrame_UpdateMerchantInfo()
eq(#logs, before + 4, "the merchant tab again writes its line")
events.MERCHANT_CLOSED()
hooks.MerchantFrame_UpdateMerchantInfo()
hooks.MerchantFrame_UpdateMerchantInfo()
eq(#logs, before + 5, "opening the merchant again writes the page line once")

-- No merchant API: does not start, says why.
ns.Adapter.env = { _G = {} }
local ok, why = registered.spec.start({ guard = function(fn) return fn end })
eq(ok, false, "nothing to hook")
eq(why, "no merchant update function to hook", "the reason")
eq(#ns.Adapter.MerchantSlots(), 0, "no merchant frame: no slots")

H.done()
