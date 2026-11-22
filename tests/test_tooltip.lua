-- UI/Tooltip.lua and Core/Adapter_Tooltip.lua with fake tooltips, for both hook paths (design D5).
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ARCANITE, THORIUM, LINEN, BROKEN = 12360, 12359, 2589, 999

local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

-- A fake tooltip: records lines, runs hooked scripts, and refills itself through `fill` on refresh.
local function fakeTooltip(name, scripts)
    local tip = { name = name, lines = {}, hooks = {}, shown = true, has = {} }
    for _, s in ipairs(scripts) do tip.has[s] = true end
    function tip:HasScript(s) return self.has[s] == true end
    function tip:HookScript(s, fn)
        assert(self.has[s], name .. " has no script " .. s)
        self.hooks[s] = self.hooks[s] or {}
        table.insert(self.hooks[s], fn)
    end
    function tip:Run(s) for _, fn in ipairs(self.hooks[s] or {}) do fn(self) end end
    function tip:AddLine(text, r, g, b) self.lines[#self.lines + 1] = { text = text, r = r, g = g, b = b } end
    function tip:Show() self.shown = true end
    function tip:IsShown() return self.shown end
    function tip:GetItem() return "x", self.link end
    function tip:Clear() self.lines = {}; self:Run("OnTooltipCleared") end
    return tip
end

-- Builds a fresh addon namespace on a fake client. kind = "postcall" (Forever) or "settitem" (Era).
local function setup(kind)
    local ns = {}
    H.locale(ns)
    H.load("Core/Defaults.lua", ns)
    H.load("Core/Adapter.lua", ns)
    H.load("Core/Adapter_Tooltip.lua", ns)
    H.load("Model/RecipeKnowledge.lua", ns)
    H.load("Model/Wording.lua", ns)

    local env = { shift = false }
    local postCalls = {}
    local tips = {}
    if kind == "postcall" then
        env.TooltipDataProcessor = { AddTooltipPostCall = function(t, fn) assert(t == 0); postCalls[#postCalls + 1] = fn end }
        env.Enum = { TooltipDataType = { Item = 0 } }
        env.C_Item = {
            GetItemCount = function(id) return id == LINEN and 12 or 0 end,
            GetItemInfo = function(id) return id == 12655 and "Enchanted Thorium Bar" or nil end,
        }
        env.C_Spell = { GetSpellName = function() return nil end }
        for _, n in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
            local tip = fakeTooltip(n, { "OnTooltipCleared" })
            -- RefreshData may redraw without firing OnTooltipCleared; the redraw must not rely on it.
            function tip:RefreshData() self.lines = {}; self:Fill() end
            function tip:Fill() for _, fn in ipairs(postCalls) do fn(self, { id = self.itemID }) end end
            tips[n] = tip; env[n] = tip
        end
    else
        env.GetItemCount = function(id) return id == LINEN and 12 or 0 end
        env.GetItemInfo = function() return nil end
        env.GetSpellInfo = function() return nil end
        for _, n in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
            local tip = fakeTooltip(n, { "OnTooltipCleared", "OnTooltipSetItem" })
            function tip:Fill() self:Run("OnTooltipSetItem") end
            function tip:SetHyperlink(link) self.link = link; self:Clear(); self:Fill() end
            tips[n] = tip; env[n] = tip
        end
    end
    env.IsShiftKeyDown = function() return env.shift end
    ns.Adapter.env = env

    -- Show itemID on a tooltip the way the game does (clear, then the item hook).
    local function show(tip, id)
        tip.itemID, tip.link = id, ("|cff|Hitem:%d::|h[x]|h|r"):format(id)
        tip:Clear()
        tip:Fill()
        return tip.lines
    end

    local catalog = {
        itemNames = { [12359] = "Thorium Bar", [12360] = "Arcanite Bar" },
        spellNames = { [16661] = "Storm Gauntlets" },
        recipes = { [16661] = { p = "blacksmithing", learn = 295, r = { ARCANITE, 2 } } },
        endgame = {},
    }
    local results = {
        [ARCANITE] = { endgame = { { profession = "blacksmithing", reason = "Storm Gauntlets" } } },
        [THORIUM] = { endgame = { { profession = "blacksmithing" } }, leveling = { { profession = "blacksmithing", need = { from = 250, to = 275, low = 40, high = 40 } } } },
        [LINEN] = { leveling = { { profession = "tailoring", need = { from = 1, to = 50, low = 40, high = 55, sources = { "Guide A" } } } } },
    }
    ns.Context = {
        Get = function() return { catalog = catalog, routes = {} } end,
        Classify = function(id)
            if id == BROKEN then error("classify broke") end
            return results[id]
        end,
    }
    local failures = {}
    ns.Log = { Failure = function(area, msg) failures[#failures + 1] = { area = area, msg = msg } end }
    local events = {}
    local addon = { db = { profile = copy(ns.defaults.profile) } }
    function addon:RegisterEvent(e, fn) events[e] = fn end
    ns.addon = addon
    local starters = {}
    ns.Start = function(fn) starters[#starters + 1] = fn end

    H.load("UI/Tooltip.lua", ns)
    eq(#starters, 1, kind .. ": the tooltip registers one starter")
    starters[1](addon)
    return { ns = ns, env = env, tips = tips, show = show, failures = failures, events = events,
        profile = addon.db.profile, postCalls = postCalls }
end

local function lineTexts(lines)
    local t = {}
    for _, l in ipairs(lines) do t[#t + 1] = l.text end
    return table.concat(t, " | ")
end

for _, kind in ipairs({ "postcall", "settitem" }) do
    local s = setup(kind)
    local tip = s.tips.GameTooltip
    eq(s.ns.Tooltip.path, kind, kind .. ": the hook is chosen by capability")
    if kind == "postcall" then
        eq(#s.postCalls, 1, "postcall: one post-call registered")
        eq(tip.hooks.OnTooltipSetItem, nil, "postcall: OnTooltipSetItem is not hooked")
    else
        for _, n in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
            eq(#(s.tips[n].hooks.OnTooltipSetItem or {}), 1, "settitem: " .. n .. " is hooked once")
        end
    end
    eq(type(s.events.MODIFIER_STATE_CHANGED), "function", kind .. ": Shift redraw is registered")

    -- One line on an endgame item: "KeepThat:" grey, only the category word colored, a "(Shift)" hint.
    local function plain(t) return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    local function hasColor(t, which) return t:find("|cff" .. s.ns.Wording.Hex(s.profile.colors[which]), 1, true) ~= nil end
    local lines = s.show(tip, ARCANITE)
    eq(#lines, 1, kind .. ": one line on Arcanite Bar")
    eq(plain(lines[1].text), "KeepThat: Endgame: Blacksmithing (Shift)", kind .. ": the endgame line")
    eq(hasColor(lines[1].text, "endgame"), true, kind .. ": the category word in the endgame color")
    eq(lines[1].text:find("|cffaaaaaaKeepThat:|r", 1, true) == 1, true, kind .. ": the prefix is grey")

    -- Repeat hook calls without a clear add nothing more; a clear resets the guard.
    tip:Fill(); tip:Fill()
    eq(#tip.lines, 1, kind .. ": repeat calls still give one line")
    tip:Clear()
    eq(#tip.lines, 0, kind .. ": cleared")
    tip:Fill()
    eq(#tip.lines, 1, kind .. ": after a clear the line comes back once")

    -- Both categories read in the endgame color; leveling in the leveling color; unmarked gives nothing.
    lines = s.show(tip, THORIUM)
    eq(plain(lines[1].text), "KeepThat: Endgame + Leveling: Blacksmithing (Shift)", kind .. ": both line")
    eq(hasColor(lines[1].text, "endgame") and hasColor(lines[1].text, "leveling"), true, kind .. ": each category in its color")
    lines = s.show(tip, LINEN)
    eq(plain(lines[1].text), "KeepThat: Leveling: Tailoring (Shift)", kind .. ": leveling line")
    eq(hasColor(lines[1].text, "leveling"), true, kind .. ": leveling color")
    eq(#s.show(tip, 1), 0, kind .. ": an unmarked item gains no line")

    -- The chat link tooltip gets the line too, once.
    lines = s.show(s.tips.ItemRefTooltip, ARCANITE)
    s.tips.ItemRefTooltip:Fill()
    eq(#lines, 1, kind .. ": chat link tooltip has the line once")

    -- Shift adds the details; the redraw on press and release adds and removes them.
    s.show(tip, ARCANITE)
    s.env.shift = true
    s.events.MODIFIER_STATE_CHANGED("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    eq(plain(tip.lines[1].text), "KeepThat: Endgame: Blacksmithing", kind .. ": the line stays first, no hint with Shift")
    eq(#tip.lines, 4, kind .. ": Shift adds details (" .. lineTexts(tip.lines) .. ")")
    eq(plain(tip.lines[2].text), "  Endgame - Blacksmithing", kind .. ": a block heading")
    eq(hasColor(tip.lines[2].text, "endgame"), true, kind .. ": only the category word in its color")
    eq(tip.lines[2].text:find("|cffddddddBlacksmithing|r", 1, true) ~= nil, true, kind .. ": the profession neutral")
    eq(tip.lines[3].text, "    Storm Gauntlets", kind .. ": the purpose")
    eq(math.floor(tip.lines[3].r * 1000), 867, kind .. ": the purpose is neutral")
    eq(tip.lines[4].text, "    Storm Gauntlets - 2 per craft", kind .. ": the recipe with its quantity")
    eq(tip.lines[4].r, 0.6, kind .. ": note lines are grey")
    s.env.shift = false
    s.events.MODIFIER_STATE_CHANGED("MODIFIER_STATE_CHANGED", "RSHIFT", 0)
    eq(#tip.lines, 1, kind .. ": Shift released gives the single line again")
    s.events.MODIFIER_STATE_CHANGED("MODIFIER_STATE_CHANGED", "LCTRL", 1)
    eq(#tip.lines, 1, kind .. ": other modifiers do not redraw")

    -- Recipe status and hint from this character's recipe knowledge (Core/Recipes.lua), with the live ranks.
    local realGet = s.ns.Context.Get
    s.ns.Context.Get = function() local c = realGet(); c.skills = { blacksmithing = 300 }; return c end
    s.ns.Recipes = {
        Status = function(p, spell, skills)
            eq(p .. spell .. skills.blacksmithing, "blacksmithing16661300", kind .. ": status asked with the live rank")
            return { learned = true, difficulty = "gray" }
        end,
        NeedsHint = function(p, skills) return p == "blacksmithing" and skills.blacksmithing == 300 end,
    }
    s.show(tip, ARCANITE)
    s.env.shift = true
    s.events.MODIFIER_STATE_CHANGED("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    eq(tip.lines[4].text, "    Storm Gauntlets - 2 per craft (Learned · |cff808080Gray|r)", kind .. ": the recipe status")
    eq(tip.lines[5].text, "    Open Blacksmithing to see which recipes you know", kind .. ": the hint")
    s.env.shift = false
    s.events.MODIFIER_STATE_CHANGED("MODIFIER_STATE_CHANGED", "RSHIFT", 0)
    s.ns.Recipes, s.ns.Context.Get = nil, realGet

    -- Shift on a leveling item shows the count and how many are in bags.
    s.env.shift = true
    lines = s.show(tip, LINEN)
    eq(plain(lines[2].text), "  Leveling - Tailoring, skill 1-50", kind .. ": leveling heading")
    eq(hasColor(lines[2].text, "leveling"), true, kind .. ": the category word in the leveling color")
    eq(lines[3].text, "    40-55 needed, 12 in bags", kind .. ": the count and bags")
    s.env.shift = false

    -- The Auctionator shortfall cost joins the leveling block in Shift only; an error in it never disables the tooltip.
    s.env.shift = true
    s.ns.Auctionator = { ItemCost = function() return { quantity = 28, cost = "14g" } end }
    lines = s.show(tip, LINEN)
    eq(#lines, 5, kind .. ": cost line is added with Shift (" .. lineTexts(lines) .. ")")
    eq(lines[3].text, "    40-55 needed, 12 in bags", kind .. ": the count first")
    eq(lines[4].text, "    Estimated cost for 28: 14g, from Auctionator's last scan.", kind .. ": the cost line right under the count")
    s.env.shift = false
    eq(#s.show(tip, LINEN), 1, kind .. ": no cost line without Shift")
    s.env.shift = true
    s.ns.Auctionator = { ItemCost = function() error("boom") end }
    lines = s.show(tip, LINEN)
    eq(lines[3].text, "    40-55 needed, 12 in bags", kind .. ": an error in the cost keeps the details")
    eq(#lines, 4, kind .. ": and adds no cost line")
    s.ns.Auctionator = nil
    s.env.shift = false

    -- Stock across characters: the total joins the line, the rows join the Shift details; the recorder may be absent.
    local recorderCalls = 0
    local rows = { { name = "Me", self = true, count = 20 }, { name = "Bankmule", count = 30 }, { name = "Hunter", count = 5 } }
    s.ns.StockRecorder = { Total = function(id) recorderCalls = recorderCalls + 1; return 55, true, rows end }
    lines = s.show(tip, LINEN)
    eq(plain(lines[1].text), "KeepThat: Leveling: Tailoring - 55 owned (Shift)", kind .. ": owned, then the hint")
    s.env.shift = true
    lines = s.show(tip, LINEN)
    eq(plain(lines[1].text), "KeepThat: Leveling: Tailoring - 55 owned", kind .. ": owned without the hint on Shift")
    eq(lines[3].text, "    40-55 needed, 12 in bags", kind .. ": need row unchanged")
    eq(plain(lines[#lines - 3].text), "  Stock", kind .. ": Stock heading")
    eq(lines[#lines - 2].text, "    This character: 20", kind .. ": own row")
    eq(lines[#lines].text, "    Hunter: 5", kind .. ": last holder")
    s.env.shift = false
    s.ns.StockRecorder = { Total = function() return 0, true, {} end }
    eq(plain(s.show(tip, LINEN)[1].text), "KeepThat: Leveling: Tailoring (Shift)", kind .. ": 0 owned adds nothing")
    s.env.shift = true
    eq(#s.show(tip, LINEN), 4, kind .. ": no stock block without holders")
    s.env.shift = false
    s.ns.StockRecorder = { Total = function() return nil end }
    eq(plain(s.show(tip, LINEN)[1].text), "KeepThat: Leveling: Tailoring (Shift)", kind .. ": recorder unknown adds nothing")
    s.ns.StockRecorder = nil
    eq(plain(s.show(tip, LINEN)[1].text), "KeepThat: Leveling: Tailoring (Shift)", kind .. ": no recorder adds nothing")

    -- The setting off adds nothing (checked at call time), and back on works without reload.
    s.profile.tooltip = false
    eq(#s.show(tip, ARCANITE), 0, kind .. ": setting off adds nothing")
    s.profile.tooltip = true
    eq(#s.show(tip, ARCANITE), 1, kind .. ": setting back on adds the line")

    -- An error never raises; it is logged and turns the line off for the session.
    local ok = pcall(s.show, tip, BROKEN)
    eq(ok, true, kind .. ": an erroring classify does not raise")
    eq(#s.failures, 1, kind .. ": the failure is logged once")
    eq(s.failures[1].area, "tooltip", kind .. ": logged under tooltip")
    eq(#s.show(tip, ARCANITE), 0, kind .. ": after a failure the line is off for the session")
end

-- An AddLine that errors is contained too.
do
    local s = setup("postcall")
    local tip = s.tips.GameTooltip
    function tip:AddLine() error("AddLine broke") end
    local ok = pcall(s.show, tip, ARCANITE)
    eq(ok, true, "an erroring AddLine does not raise")
    eq(s.failures[1] and s.failures[1].area, "tooltip", "an erroring AddLine is logged")
end

-- No hook on the client: logged, nothing raises, no event registered.
do
    local ns = {}
    H.locale(ns)
    H.load("Core/Defaults.lua", ns)
    H.load("Core/Adapter.lua", ns)
    H.load("Core/Adapter_Tooltip.lua", ns)
    H.load("Model/RecipeKnowledge.lua", ns)
    H.load("Model/Wording.lua", ns)
    ns.Adapter.env = {}
    local failures, events, starters = {}, {}, {}
    ns.Log = { Failure = function(area) failures[#failures + 1] = area end }
    ns.Start = function(fn) starters[#starters + 1] = fn end
    ns.addon = { db = { profile = copy(ns.defaults.profile) }, RegisterEvent = function(_, e) events[e] = true end }
    H.load("UI/Tooltip.lua", ns)
    starters[1](ns.addon)
    eq(failures[1], "tooltip", "no hook available is logged")
    eq(events.MODIFIER_STATE_CHANGED, nil, "no Shift redraw without a hook")

    -- Adapter reads: nil when missing, values when present.
    local A = ns.Adapter
    eq(A.ItemCount(1), nil, "no count function gives nil")
    eq(A.IsShiftDown(), nil, "no IsShiftKeyDown gives nil")
    eq(A.ItemName(1), nil, "no item info gives nil")
    eq(A.SpellName(1), nil, "no spell info gives nil")
    A.env = { GetItemCount = function() return 3 end, GetItemInfo = function() return "Linen Cloth" end,
        GetSpellInfo = function() return "Bolt of Linen Cloth" end, IsShiftKeyDown = function() return 1 end }
    eq(A.ItemCount(1), 3, "Era GetItemCount")
    eq(A.ItemName(1), "Linen Cloth", "Era GetItemInfo")
    eq(A.SpellName(1), "Bolt of Linen Cloth", "Era GetSpellInfo")
    eq(A.IsShiftDown(), true, "Shift down")
    A.env = { C_Item = { GetItemCount = function() return 5 end, GetItemInfo = function() error("boom") end },
        C_Spell = { GetSpellName = function() return "Smelt Thorium" end } }
    eq(A.ItemCount(1), 5, "Forever C_Item.GetItemCount")
    eq(A.ItemName(1), nil, "an erroring GetItemInfo gives nil")
    eq(A.SpellName(1), "Smelt Thorium", "Forever C_Spell.GetSpellName")
    eq(A.TooltipItemID({ GetItem = function() return "x", "|Hitem:12360:0|h" end }), 12360, "item ID from link")
end

H.done()
