-- Integrations/Gate.lua and the bag integrations with fake addons and a fake game (ns.Adapter.env):
-- each one paints, its toggle hides only its own marks, an integration that throws is disabled and
-- logged while the others keep working, nothing but Blizzard's bags starts on Classic Era, and the
-- EllesmereUI painter handles a placeholder slot and a changed button.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local function copy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end

local function fakeTexture(parent, layer)
    local t = { parent = parent, layer = layer, shown = true }
    function t:SetAllPoints(a) self.anchor = a end
    function t:SetColorTexture(r, g, b, a) self.r, self.g, self.b, self.a = r, g, b, a end
    function t:SetBlendMode(m) self.blend = m end
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    return t
end

local function button(fields)
    local b = fields or {}
    b.icon = b.icon or {}
    function b:CreateTexture(_, layer) return fakeTexture(self, layer) end
    return b
end

-- hooksecurefunc as the game does it: a post-hook; errors are NOT swallowed (the game shows them).
local function makeHook(env)
    return function(a, b, c)
        local tbl, name, fn = env, a, b
        if type(a) == "table" then tbl, name, fn = a, b, c end
        local orig = tbl[name]
        assert(type(orig) == "function", "hooksecurefunc on a missing function " .. tostring(name))
        tbl[name] = function(...)
            local r = { orig(...) }
            fn(...)
            return unpack(r)
        end
    end
end

-- 1 = endgame, 2 = leveling, 4 = unmarked
local marks = { [1] = { endgame = {} }, [2] = { leveling = {} } }

local function build(client, env)
    local ns = { client = client }
    local starters = {}
    ns.Start = function(fn) starters[#starters + 1] = fn end
    H.locale(ns)
    H.load("Core/Defaults.lua", ns)
    local profile = copy(ns.defaults.profile)
    profile.mask = true
    ns.addon = { db = { profile = profile } }
    local listeners = {}
    ns.Context = {
        Classify = function(id) return marks[id] end,
        OnChange = function(fn) listeners[#listeners + 1] = fn end,
        Invalidate = function() for _, fn in ipairs(listeners) do fn() end end,
    }
    ns.Log = { failures = {}, records = {} }
    function ns.Log.Failure(area, msg) ns.Log.failures[#ns.Log.failures + 1] = { area = area, message = tostring(msg) } end
    function ns.Log.Record(area, msg) ns.Log.records[#ns.Log.records + 1] = area .. ": " .. msg end
    H.load("Core/Adapter.lua", ns)
    ns.Adapter.env = env
    env.hooksecurefunc = env.hooksecurefunc or makeHook(env)
    H.load("Core/Adapter_Bags.lua", ns)
    H.load("UI/Overlay.lua", ns)
    H.load("Integrations/Gate.lua", ns)
    H.load("Integrations/Blizzard.lua", ns)
    H.load("Integrations/Baganator.lua", ns)
    H.load("Integrations/Bagnon.lua", ns)
    H.load("Integrations/EllesmereUI.lua", ns)
    ns.run = function() for _, fn in ipairs(starters) do fn(ns.addon) end end
    return ns
end

local function shown(ns, b)
    local t = ns.Overlay.TextureFor(b)
    return t ~= nil and t.shown
end

---- Fake addons ----------------------------------------------------------------------------------

local function fakeEnv()
    local env = { NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5 }
    local slots = { [0] = { [1] = 1, [2] = 4 } }
    env.C_Container = { GetContainerItemID = function(bag, slot) return slots[bag] and slots[bag][slot] end }
    -- Blizzard, modern: a combined bag frame with UpdateItems and EnumerateValidItems.
    local blizz1 = button({ GetBagID = function() return 0 end, GetID = function() return 1 end })
    local blizz2 = button({ GetBagID = function() return 0 end, GetID = function() return 2 end })
    env.ContainerFrameCombinedBags = {
        Items = { blizz1, blizz2 },
        UpdateItems = function() end,
        EnumerateValidItems = function(self) return ipairs(self.Items) end,
    }
    -- Bagnon: a class with Update; buttons copy it when built.
    env.Bagnon = { ContainerItem = { Update = function(self, info) self.info = info or self.info end } }
    -- Baganator: a live container mixin.
    env.BaganatorRetailLiveContainerItemButtonMixin = { SetItemDetails = function(self, d) self.BGR = { itemID = d.itemID } end }
    env.Baganator = { API = {} }
    -- EllesmereUI Bags: the painter registry, run through a securecallfunction that does not swallow errors.
    local painters = {}
    env.EUI_Bags = {
        itemOverlayIcons = painters,
        RegisterItemOverlayIcon = function(name, fn) painters[name] = fn end,
        UnregisterItemOverlayIcon = function(name) painters[name] = nil end,
        RunItemOverlays = function(btn, data) for _, fn in pairs(painters) do fn(btn, data) end end,
        RefreshInventory = function(self) assert(self == env.EUI_Bags, "RefreshInventory is a method"); env.euiRefreshes = (env.euiRefreshes or 0) + 1 end,
    }
    env.EUI_BankFrame = { RefreshBank = function(self) assert(self == env.EUI_BankFrame, "RefreshBank is a method"); env.bankRefreshes = (env.bankRefreshes or 0) + 1 end }
    return env, blizz1, blizz2
end

---- WoW Forever ----------------------------------------------------------------------------------

local env, blizz1, blizz2 = fakeEnv()
local ns = build("forever", env)
local I = ns.Integrations

-- An integration that throws at start (another file would register it at load).
local otherStarted = false
I.Register("broken", { detect = function() return true end, start = function() error("it moved") end })
I.Register("fine", { detect = function() return true end, start = function() otherStarted = true end })
I.Register("absent", { detect = function() error("detect fails") end, start = function() error("never") end })

eq(I.Status("baganator").reason, "not started", "nothing starts before settings are ready")
ns.run()

eq(I.Status("broken").working, false, "an integration that throws at start is not working")
eq(I.Status("broken").reason, "failed: " .. ns.Log.failures[1].message, "its status names the failure")
eq(ns.Log.failures[1].area, "broken", "and the failure is logged under its key")
eq(ns.Log.failures[1].message:find("it moved", 1, true) ~= nil, true, "with the reason")
eq(otherStarted, true, "the next integration still starts")
eq(I.Status("absent").detected, false, "a detect that errors counts as not detected")
eq(I.Status("absent").reason, "not detected", "not detected")
eq(I.Status("nosuch").detected, false, "an unknown key is not detected")
for _, key in ipairs({ "blizzard", "baganator", "bagnon", "ellesmereui" }) do
    local s = I.Status(key)
    eq(s.detected and s.working, true, key .. " is detected and working")
    eq(s.reason, nil, key .. " has no reason")
end
eq(I.Status("baganator").detected ~= nil and type(I.Status("baganator")), "table", "Status returns a table")

-- Blizzard bags
env.ContainerFrameCombinedBags:UpdateItems()
eq(shown(ns, blizz1), true, "Blizzard: the marked item in bag 0 slot 1 is tinted")
eq(ns.Overlay.TextureFor(blizz2), nil, "Blizzard: the unmarked item is not")

-- Bagnon: a button built after the hook, from the class
local bagnonBtn = button(setmetatable({ bag = 0 }, { __index = env.Bagnon.ContainerItem }))
for k, v in pairs(env.Bagnon.ContainerItem) do rawset(bagnonBtn, k, v) end   -- Item:Bind copies methods
bagnonBtn:Update({ itemID = 1 })
eq(shown(ns, bagnonBtn), true, "Bagnon: a marked item is tinted (item from the button's info)")
bagnonBtn:Update({ itemID = 4 })
eq(shown(ns, bagnonBtn), false, "Bagnon: an unmarked item replaces it and the tint hides")
bagnonBtn:Update({ itemID = 1 })

-- Baganator: a bank button (bag 6 is past the equipped bags)
local bagaBtn = button({ GetParent = function() return { GetID = function() return 6 end } end })
bagaBtn.SetItemDetails = env.BaganatorRetailLiveContainerItemButtonMixin.SetItemDetails
bagaBtn:SetItemDetails({ itemID = 2 })
eq(shown(ns, bagaBtn), true, "Baganator: a leveling item in the bank is tinted")
eq(ns.Overlay.TextureFor(bagaBtn).g, ns.addon.db.profile.colors.leveling.g, "in the leveling color")
ns.addon.db.profile.locations.bank = false
ns.Context.Invalidate()
eq(shown(ns, bagaBtn), false, "Baganator: bank off hides bank items")
ns.addon.db.profile.locations.bank = true
ns.Context.Invalidate()

-- EllesmereUI: normal slot, placeholder slot
local host = button({})
local euiBtn = button({ _textOverlay = host })
env.EUI_Bags.RunItemOverlays(euiBtn, { bag = 0, slot = 1, info = { itemID = 1 } })
eq(shown(ns, euiBtn), true, "EllesmereUI: the item from data.info.itemID is tinted")
eq(ns.Overlay.TextureFor(euiBtn).parent, host, "EllesmereUI: drawn on btn._textOverlay")
env.EUI_Bags.RunItemOverlays(euiBtn, { bag = 0, slot = 0 })
eq(shown(ns, euiBtn), false, "EllesmereUI: a placeholder slot hides the tint")
env.EUI_Bags.RunItemOverlays(euiBtn, { bag = 0, slot = 1, info = { itemID = 1 } })
env.EUI_Bags.RunItemOverlays(button({}), { bag = 0, slot = 0 })
eq(I.Status("ellesmereui").working, true, "EllesmereUI: a placeholder without _textOverlay is not a failure")

-- Toggle one off: only its marks hide, the others are unaffected
ns.addon.db.profile.integrations.bagnon = false
ns.Context.Invalidate()
eq(shown(ns, bagnonBtn), false, "Bagnon turned off: its marks hide")
eq(I.Status("bagnon").reason, "off", "Bagnon turned off: status says off")
eq(shown(ns, bagaBtn) and shown(ns, euiBtn) and shown(ns, blizz1), true, "the other integrations still show")
ns.addon.db.profile.integrations.bagnon = true
ns.Context.Invalidate()
eq(shown(ns, bagnonBtn), true, "Bagnon turned back on: its marks return")

-- EllesmereUI repaints when the mask is toggled, as methods
local before = env.euiRefreshes or 0
ns.addon.db.profile.mask = false; ns.Context.Invalidate()
ns.addon.db.profile.mask = true; ns.Context.Invalidate()
eq((env.euiRefreshes or 0) > before, true, "EllesmereUI: a mask change asks it to repaint its bags")
eq((env.bankRefreshes or 0) > 0, true, "EllesmereUI: and its bank")
local plain = env.euiRefreshes
ns.Context.Invalidate()
eq(env.euiRefreshes, plain, "EllesmereUI: an unrelated change (a skill-up) does not re-render it")

-- EllesmereUI painter error: a changed button without _textOverlay. No error escapes, the integration
-- turns off, unregisters, hides its marks and logs; the others keep working.
local nFail = #ns.Log.failures
local ok = pcall(env.EUI_Bags.RunItemOverlays, button({}), { bag = 0, slot = 1, info = { itemID = 1 } })
eq(ok, true, "a painter error never reaches EllesmereUI or the error handler")
eq(I.Status("ellesmereui").working, false, "EllesmereUI is disabled after the painter error")
eq(I.Status("ellesmereui").reason:find("_textOverlay", 1, true) ~= nil, true, "the reason names what was missing")
eq(#ns.Log.failures, nFail + 1, "the failure is logged once")
eq(ns.Log.failures[#ns.Log.failures].area, "ellesmereui", "under its key")
eq(env.EUI_Bags.itemOverlayIcons.KeepThat, nil, "the painter is unregistered")
eq(shown(ns, euiBtn), false, "its marks hide")
eq(shown(ns, bagaBtn) and shown(ns, bagnonBtn) and shown(ns, blizz1), true, "the other integrations are unaffected")

-- A runtime error in a hook callback (Bagnon) is contained the same way.
local okB = pcall(function() bagnonBtn:Update(setmetatable({}, { __index = function() error("changed info") end })) end)
eq(okB, true, "a Bagnon callback error does not escape the hook")
eq(I.Status("bagnon").reason:find("changed info", 1, true) ~= nil, true, "Bagnon is disabled with the reason")
eq(shown(ns, bagaBtn), true, "Baganator is unaffected")

-- An integration turned on mid-session starts then (and only once).
local env2 = fakeEnv()
local ns2 = build("forever", env2)
ns2.addon.db.profile.integrations.ellesmereui = false
ns2.run()
eq(ns2.Integrations.Status("ellesmereui").reason, "off", "a toggle that is off at login does not start")
eq(env2.EUI_Bags.itemOverlayIcons.KeepThat, nil, "and registers nothing")
ns2.addon.db.profile.integrations.ellesmereui = true
ns2.Context.Invalidate()
eq(ns2.Integrations.Status("ellesmereui").working, true, "turned on later, it starts")
local registered = env2.EUI_Bags.itemOverlayIcons.KeepThat
ns2.Context.Invalidate()
eq(env2.EUI_Bags.itemOverlayIcons.KeepThat, registered, "and does not start twice")

-- Baganator's mixins appear after KeepThat starts: not detected, then started on the next addon load.
local env3 = fakeEnv()
local lateMixin = env3.BaganatorRetailLiveContainerItemButtonMixin
env3.BaganatorRetailLiveContainerItemButtonMixin = nil
local ns3 = build("forever", env3)
local handlers = {}
ns3.Listen = function(_, event, fn) handlers[event] = fn; return true end
ns3.run()
eq(ns3.Integrations.Status("baganator").reason, "not detected", "Baganator without its mixins is not detected yet")
eq(ns3.Log.failures[1], nil, "and nothing is logged as a failure")
eq(type(handlers.ADDON_LOADED), "function", "integrations retry when an addon loads")
eq(type(handlers.PLAYER_LOGIN), "function", "and at login")
env3.BaganatorRetailLiveContainerItemButtonMixin = lateMixin
handlers.ADDON_LOADED()
eq(ns3.Integrations.Status("baganator").working, true, "once the mixin exists, the next addon load starts it")
local lateBtn = button({ GetParent = function() return { GetID = function() return 0 end } end })
lateBtn.SetItemDetails = lateMixin.SetItemDetails
lateBtn:SetItemDetails({ itemID = 2 })
eq(shown(ns3, lateBtn), true, "and its buttons are tinted")

-- A mixin that exists but cannot be hooked turns the integration off and says why.
local env4 = fakeEnv()
local ns4 = build("forever", env4)
env4.hooksecurefunc = function() error("blocked") end
ns4.run()
eq(ns4.Integrations.Status("baganator").reason:find("could be hooked (1 found)", 1, true) ~= nil, true,
    "Baganator that cannot be hooked is disabled and says how many mixins it found")
local logged = false
for _, f in ipairs(ns4.Log.failures) do if f.area == "baganator" then logged = true end end
eq(logged, true, "and it is logged")

-- Baganator 860 freezes its mixins: each button's own SetItemDetails is hooked instead. Buttons
-- come from Baganator's public skin API: the ones built so far, then each new one.
local env5 = fakeEnv()
local mixin5 = env5.BaganatorRetailLiveContainerItemButtonMixin
local originalDetails = mixin5.SetItemDetails
local realHook = makeHook(env5)
env5.hooksecurefunc = function(a, b, c)
    if a == mixin5 then error("attempted to perform indexed assignment on a frozen table") end
    return realHook(a, b, c)
end
local function bagButton(bag)
    local b = button({ GetParent = function() return { GetID = function() return bag end } end })
    b.SetItemDetails = mixin5.SetItemDetails
    return b
end
local early = bagButton(0)
early:SetItemDetails({ itemID = 2 })          -- filled before KeepThat starts
local skinFrames, listeners5 = { { regionType = "ItemButton", region = early } }, {}
env5.Baganator.API.Skins = {
    GetAllFrames = function() return skinFrames end,
    RegisterListener = function(fn) listeners5[#listeners5 + 1] = fn end,
}
local ns5 = build("forever", env5)
ns5.run()
eq(ns5.Integrations.Status("baganator").working, true, "frozen mixins: Baganator still starts")
eq(mixin5.SetItemDetails, originalDetails, "and the frozen mixin is left alone")
eq(shown(ns5, early), true, "a button built before KeepThat started is tinted at once")
early:SetItemDetails({ itemID = 4 })
eq(shown(ns5, early), false, "and repaints through its own hook")
local later = bagButton(0)
for _, fn in ipairs(listeners5) do fn({ regionType = "ItemButton", region = later }) end
later:SetItemDetails({ itemID = 2 })
eq(shown(ns5, later), true, "a button Baganator builds later is hooked too")
local guild = button({ SetItemDetails = function() end })
local guildDetails = guild.SetItemDetails
for _, fn in ipairs(listeners5) do fn({ regionType = "ItemButton", region = guild }) end
eq(guild.SetItemDetails, guildDetails, "buttons with other methods (guild, bag slots) are not hooked")
for _, fn in ipairs(listeners5) do fn({ regionType = "ItemButton", region = later }) end
eq(#listeners5, 1, "one listener")

-- Cached views: the view's frame name decides bank or bags; cached guild buttons are not tinted.
local function inView(name)
    local view = { GetName = function() return name end }
    local layout = { GetID = function() return 0 end, GetParent = function() return view end }
    local b = button({ GetParent = function() return layout end })
    b.SetItemDetails = mixin5.SetItemDetails
    return b
end
local cachedBank = inView("Baganator_SingleViewBankViewFrame1")
for _, fn in ipairs(listeners5) do fn({ regionType = "ItemButton", region = cachedBank }) end
cachedBank:SetItemDetails({ itemID = 2 })
eq(shown(ns5, cachedBank), true, "cached bank item is tinted")
ns5.addon.db.profile.locations.bank = false
ns5.Context.Invalidate()
eq(shown(ns5, cachedBank), false, "and follows the Bank setting, not Bags")
ns5.addon.db.profile.locations.bank = true
local cachedGuild = inView("Baganator_SingleViewGuildViewFrame1")
for _, fn in ipairs(listeners5) do fn({ regionType = "ItemButton", region = cachedGuild }) end
cachedGuild:SetItemDetails({ itemID = 2 })
eq(shown(ns5, cachedGuild), false, "cached guild bank items are not tinted")

-- A button whose hook fails is not marked done, so a later report can hook it.
local flaky = bagButton(0)
local refuse = true
local hookNow = env5.hooksecurefunc
env5.hooksecurefunc = function(a, b, c)
    if a == flaky and refuse then error("busy") end
    return hookNow(a, b, c)
end
for _, fn in ipairs(listeners5) do fn({ regionType = "ItemButton", region = flaky }) end
refuse = false
for _, fn in ipairs(listeners5) do fn({ regionType = "ItemButton", region = flaky }) end
flaky:SetItemDetails({ itemID = 2 })
eq(shown(ns5, flaky), true, "a button whose first hook failed is hooked on the next report")

-- Unfrozen Baganator: the mixin hook is used, and buttons built before it are still adopted.
local env6 = fakeEnv()
local mixin6 = env6.BaganatorRetailLiveContainerItemButtonMixin
local before6 = button({ GetParent = function() return { GetID = function() return 0 end } end })
before6.SetItemDetails = mixin6.SetItemDetails  -- copied before KeepThat hooks the mixin
env6.Baganator.API.Skins = {
    GetAllFrames = function() return { { regionType = "ItemButton", region = before6 } } end,
    RegisterListener = function() end,
}
local ns6 = build("forever", env6)
ns6.run()
before6:SetItemDetails({ itemID = 2 })
eq(shown(ns6, before6), true, "unfrozen: a button built before the mixin hook is tinted")

---- Classic Era ----------------------------------------------------------------------------------

local eraEnv = fakeEnv()
eraEnv.ContainerFrameCombinedBags = nil
eraEnv.NUM_TOTAL_EQUIPPED_BAG_SLOTS = nil
eraEnv.NUM_BAG_SLOTS = 4
eraEnv.C_Container = nil
eraEnv.GetContainerItemID = function(bag, slot) return bag == 5 and slot == 1 and 1 or nil end
eraEnv.ContainerFrame_Update = function() end
eraEnv.GetContainerItemID = function(bag, slot)
    if bag == 5 and slot == 1 then return 1 end
    if bag == -1 and slot == 3 then return 2 end
    if bag == 0 and slot == 3 then return 4 end
end
eraEnv.BankFrameItemButton_Update = function() end
local bankBtn = button({ GetID = function() return 3 end, GetParent = function() return { GetID = function() return 0 end } end })
local eraBtn = button({ GetID = function() return 1 end })
eraEnv.ContainerFrame1 = { size = 1, GetID = function() return 5 end, GetName = function() return "ContainerFrame1" end }
eraEnv.ContainerFrame1Item1 = eraBtn
local originalMixin = eraEnv.BaganatorRetailLiveContainerItemButtonMixin.SetItemDetails
local originalUpdate = eraEnv.Bagnon.ContainerItem.Update
local era = build("era", eraEnv)
local eraStarted = false
era.Integrations.Register("auctionator", { detect = function() return true end, start = function() eraStarted = true end })
era.run()
for _, key in ipairs({ "baganator", "bagnon", "ellesmereui", "auctionator" }) do
    local s = era.Integrations.Status(key)
    eq(s.working, false, key .. " does not start on Classic Era")
    eq(s.detected, true, key .. " is still detected on Classic Era")
    eq(s.reason, "not on Classic Era", key .. " says not on Classic Era")
end
eq(eraStarted, false, "no integration's start runs on Classic Era")
eq(eraEnv.BaganatorRetailLiveContainerItemButtonMixin.SetItemDetails, originalMixin, "Baganator is not hooked on Classic Era")
eq(eraEnv.Bagnon.ContainerItem.Update, originalUpdate, "Bagnon is not hooked on Classic Era")
eq(eraEnv.EUI_Bags.itemOverlayIcons.KeepThat, nil, "no EllesmereUI painter on Classic Era")
eq(era.Integrations.Status("blizzard").working, true, "Blizzard's bags still work on Classic Era")
eraEnv.ContainerFrame_Update(eraEnv.ContainerFrame1)
eq(shown(era, eraBtn), true, "Classic Era: a marked item in a bank bag (bag 5) is tinted")
eraEnv.BankFrameItemButton_Update(bankBtn)
eq(shown(era, bankBtn), true, "Classic Era: a bank main slot reads bag -1 (not the parent's ID 0, the backpack)")
eq(era.Overlay.TextureFor(bankBtn).g, era.addon.db.profile.colors.leveling.g, "and shows the bank item's mark")
era.addon.db.profile.locations.bank = false; era.Context.Invalidate()
eq(shown(era, bankBtn), false, "Classic Era: bank off hides the bank main slot")
eq(shown(era, eraBtn), false, "Classic Era: bag 5 is the bank, so bank off hides it")

-- Bag locations
local A = ns.Adapter
eq(A.BagLocation(0), "bags", "the backpack is bags")
eq(A.BagLocation(5), "bags", "with a reagent bag (5 equipped bag slots), bag 5 is bags")
eq(A.BagLocation(-1), "bank", "the bank's main slots are bank")
eq(A.BagLocation(nil), nil, "unknown bag is nil")
eq(era.Adapter.BagLocation(-2), "bags", "the keyring is bags")

H.done()
