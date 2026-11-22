-- In-game API probe (/kt probe, /kt probe hover). It reports which game functions and addon globals
-- exist on the running client, so the design can choose code paths by capability. Everything is read
-- through an injected environment (default _G) inside pcall, so the report always completes.
-- The report is diagnostic output for the developer and is not translated.
local _, ns = ...

local Probe = {}
ns.Probe = Probe

-- API candidates, grouped. "X.*" lists the members of table X.
Probe.Candidates = {
    { group = "Tooltips", names = { "TooltipDataProcessor.AddTooltipPostCall", "Enum.TooltipDataType.Item",
        "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "hooksecurefunc" } },
    { group = "Loot", names = { "GetLootInfo", "GetNumLootItems", "GetLootSlotLink", "C_Loot.*" } },
    { group = "Containers", names = { "C_Container.*", "GetContainerItemID", "GetContainerItemInfo",
        "ContainerFrame_Update", "ContainerFrame_UpdateItems", "ContainerFrameCombinedBags",
        "BankFrameItemButton_Update", "BankFrame" } },
    { group = "Merchant", names = { "MerchantFrame", "MerchantFrame_UpdateMerchantInfo", "MerchantFrame_UpdateBuybackInfo",
        "GetMerchantItemID", "GetMerchantItemLink", "GetBuybackItemLink", "GetNumBuybackItems", "C_MerchantFrame.*",
        "MERCHANT_ITEMS_PER_PAGE", "BUYBACK_ITEMS_PER_PAGE", "MerchantItem1ItemButton" } },
    { group = "Items", names = { "GetItemInfo", "GetItemInfoInstant", "GetItemCount", "C_Item.*" } },
    { group = "Skills", names = { "GetNumSkillLines", "GetSkillLineInfo", "C_TradeSkillUI.*", "C_SkillInfo.*" } },
    { group = "Recipes", names = { "IsPlayerSpell", "IsSpellKnown", "GetNumTradeSkills", "GetTradeSkillLine",
        "GetTradeSkillInfo", "GetTradeSkillRecipeLink", "GetTradeSkillSubClassFilter", "GetTradeSkillInvSlotFilter",
        "TradeSkillFrameAvailableFilterCheckButton", "GetNumCrafts", "GetCraftDisplaySkillLine", "GetCraftInfo",
        "GetCraftItemLink", "C_TradeSkillUI.GetBaseProfessionInfo", "C_TradeSkillUI.GetRecipeInfo", "IsTradeSkillLinked",
        "C_TradeSkillUI.IsTradeSkillLinked", "C_TradeSkillUI.IsTradeSkillGuild", "C_TradeSkillUI.IsNPCCrafting" } },
    { group = "Frames and timers", names = { "C_Timer.After", "CreateFrame", "GetMouseFocus", "GetMouseFoci",
        "Settings.RegisterCanvasLayoutCategory", "InterfaceOptions_AddCategory" } },
    { group = "Addons", names = { "C_AddOns.*", "GetNumAddOns", "GetAddOnInfo", "IsAddOnLoaded" } },
}

-- Global strings the loot toast parses.
Probe.LootStrings = { "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF",
    "LOOT_ITEM_PUSHED_SELF_MULTIPLE" }

-- Addon tables whose shape the integrations depend on.
Probe.AddonGlobals = { "Baganator", "Baganator.API", "Bagnon", "EllesmereUI", "Auctionator", "Auctionator.API.v1",
    "Skillet", "LazyProf" }

-- Patterns for global names to list when an addon's table name is unknown (EllesmereUI, DFL Profession Journal).
Probe.GlobalPatterns = { "^DFL", "[Pp]rofession[Jj]ournal", "^EUI", "[Ee]llesmere" }

local MAX_KEYS = 40

local function resolve(env, path)
    return ns.Adapter.Resolve(path, env)
end

local function sortedKeys(t)
    local keys = {}
    local ok = pcall(function()
        for k in pairs(t) do keys[#keys + 1] = tostring(k) end
    end)
    if not ok then return nil end
    table.sort(keys)
    return keys
end

-- "name (type: key1, key2, ...)" for a table, or its type for anything else.
local function shape(v)
    if type(v) ~= "table" then return type(v) end
    local keys = sortedKeys(v)
    if not keys then return "table (unreadable)" end
    local shown = {}
    for i = 1, math.min(#keys, MAX_KEYS) do shown[i] = keys[i] end
    local more = #keys > MAX_KEYS and (", ... +" .. (#keys - MAX_KEYS)) or ""
    return ("table, %d keys: %s%s"):format(#keys, table.concat(shown, ", "), more)
end

local function candidateLines(env, out)
    for _, g in ipairs(Probe.Candidates) do
        out[#out + 1] = "== " .. g.group .. " =="
        for _, name in ipairs(g.names) do
            local base = name:match("^(.-)%.%*$")
            local v = resolve(env, base or name)
            if v == nil then
                out[#out + 1] = "  missing  " .. name
            elseif base then
                out[#out + 1] = "  present  " .. base .. ": " .. shape(v)
            else
                out[#out + 1] = "  present  " .. name .. " (" .. type(v) .. ")"
            end
        end
    end
end

-- Whether a frame supports a script, e.g. OnTooltipSetItem (only exists on clients without TooltipDataProcessor).
local function hasScript(env, frameName, script)
    local f = resolve(env, frameName)
    if type(f) ~= "table" or type(f.HasScript) ~= "function" then return "n/a" end
    local ok, res = pcall(f.HasScript, f, script)
    if not ok then return "error" end
    return tostring(res)
end

local function buildLines(env, out)
    out[#out + 1] = "== Client =="
    local f = resolve(env, "GetBuildInfo")
    if type(f) == "function" then
        local ok, version, build, _, interface = pcall(f)
        out[#out + 1] = ok and ("  version %s, build %s, interface %s"):format(tostring(version), tostring(build), tostring(interface))
            or "  GetBuildInfo errored"
    else
        out[#out + 1] = "  GetBuildInfo missing"
    end
    out[#out + 1] = "  GameTooltip OnTooltipSetItem: " .. hasScript(env, "GameTooltip", "OnTooltipSetItem")
end

local function lootLines(env, out)
    out[#out + 1] = "== Loot strings =="
    for _, name in ipairs(Probe.LootStrings) do
        local v = resolve(env, name)
        out[#out + 1] = "  " .. name .. ": " .. (type(v) == "string" and ("%q"):format(v) or "missing")
    end
end

local function addonListLines(env, out)
    out[#out + 1] = "== Loaded addons =="
    local num = resolve(env, "C_AddOns.GetNumAddOns") or resolve(env, "GetNumAddOns")
    local info = resolve(env, "C_AddOns.GetAddOnInfo") or resolve(env, "GetAddOnInfo")
    local loaded = resolve(env, "C_AddOns.IsAddOnLoaded") or resolve(env, "IsAddOnLoaded")
    local meta = resolve(env, "C_AddOns.GetAddOnMetadata") or resolve(env, "GetAddOnMetadata")
    if type(num) ~= "function" or type(info) ~= "function" then
        out[#out + 1] = "  addon list unavailable"
        return
    end
    local ok, n = pcall(num)
    if not ok or type(n) ~= "number" then out[#out + 1] = "  addon count unreadable"; return end
    for i = 1, n do
        local okInfo, name = pcall(info, i)
        local isLoaded = okInfo and type(loaded) == "function" and select(2, pcall(loaded, name))
        if okInfo and name and isLoaded then
            local version = type(meta) == "function" and select(2, pcall(meta, name, "Version")) or nil
            out[#out + 1] = "  " .. tostring(name) .. (version and (" " .. tostring(version)) or "")
        end
    end
end

local function addonGlobalLines(env, out)
    out[#out + 1] = "== Addon globals =="
    for _, path in ipairs(Probe.AddonGlobals) do
        local v = resolve(env, path)
        out[#out + 1] = "  " .. path .. ": " .. (v == nil and "missing" or shape(v))
    end
    out[#out + 1] = "== Globals by name pattern =="
    local found = {}
    pcall(function()
        for k, v in pairs(env) do
            if type(k) == "string" then
                for _, p in ipairs(Probe.GlobalPatterns) do
                    if k:find(p) and not Probe.IsBareRegion(v) then found[#found + 1] = { k, v }; break end
                end
            end
        end
    end)
    table.sort(found, function(a, b) return a[1] < b[1] end)
    if #found == 0 then out[#out + 1] = "  none" end
    for _, kv in ipairs(found) do out[#out + 1] = "  " .. kv[1] .. ": " .. shape(kv[2]) end
end

-- Auctionator's price functions (spec auctionator-export): which exist, and what they return for one
-- material (Runecloth), so the estimate can be checked against the installed build (docs/contracts.md).
Probe.PriceSample = 14047
local function auctionatorPriceLines(env, out)
    out[#out + 1] = "== Auctionator prices =="
    local v1 = resolve(env, "Auctionator.API.v1")
    if type(v1) ~= "table" then out[#out + 1] = "  Auctionator.API.v1 missing"; return end
    for _, name in ipairs({ "GetAuctionPriceByItemID", "GetAuctionAgeByItemID", "IsAuctionDataExactByItemID" }) do
        local fn = v1[name]
        if type(fn) ~= "function" then
            out[#out + 1] = "  missing  " .. name
        else
            local ok, value = pcall(fn, "KeepThat", Probe.PriceSample)
            out[#out + 1] = ("  present  %s(%d) = %s"):format(name, Probe.PriceSample, ok and tostring(value) or ("error: " .. tostring(value)))
        end
    end
end

-- A frame, texture or font string with almost nothing of its own (the [0] handle and up to two
-- fields). Such globals are UI pieces, not data, and would flood the pattern scan.
function Probe.IsBareRegion(v)
    if type(v) ~= "table" or type(rawget(v, 0)) ~= "userdata" then return false end
    local n = 0
    for _ in pairs(v) do n = n + 1; if n > 3 then return false end end
    return true
end

-- Every member of the table at path, one per line with its type; nested tables show their key count.
-- Used to learn an addon's API or data layout (/kt probe path DFLProfessionJournalNS.API).
function Probe.Path(path, env)
    env = env or _G
    local v = resolve(env, path)
    local out = { "== " .. path .. " ==" }
    if v == nil then out[#out + 1] = "  missing"; return table.concat(out, "\n") end
    if type(v) ~= "table" then
        out[#out + 1] = "  " .. type(v) .. ": " .. tostring(v)
        return table.concat(out, "\n")
    end
    local members = {}
    local ok = pcall(function()
        for k, member in pairs(v) do members[#members + 1] = { tostring(k), member } end
    end)
    if not ok then out[#out + 1] = "  unreadable"; return table.concat(out, "\n") end
    table.sort(members, function(a, b) return a[1] < b[1] end)
    for _, m in ipairs(members) do
        local member, desc = m[2]
        if type(member) == "table" then desc = ("table (%d keys)"):format(#(sortedKeys(member) or {}))
        elseif type(member) == "string" then desc = ("%q"):format(member:sub(1, 80))
        elseif type(member) == "number" or type(member) == "boolean" then desc = tostring(member)
        else desc = type(member) end
        out[#out + 1] = "  " .. m[1] .. ": " .. desc
    end
    return table.concat(out, "\n")
end

-- The full report as one string.
function Probe.Run(env)
    env = env or _G
    local out = { "KeepThat probe " .. tostring(ns.version) }
    buildLines(env, out)
    candidateLines(env, out)
    lootLines(env, out)
    addonListLines(env, out)
    addonGlobalLines(env, out)
    auctionatorPriceLines(env, out)
    return table.concat(out, "\n")
end

local function frameName(frame)
    if type(frame) ~= "table" then return tostring(frame) end
    local ok, name = pcall(function() return frame.GetName and frame:GetName() end)
    local okType, kind = pcall(function() return frame.GetObjectType and frame:GetObjectType() end)
    return ("%s [%s]"):format(ok and name or "<anonymous>", okType and kind or "?")
end

-- The frame under the mouse, its parents, its fields and methods: used to find how a bag addon's
-- item buttons are named and what they carry (bag and slot, item link).
function Probe.Hover(env)
    env = env or _G
    local out = { "== Hovered frame ==" }
    local frame
    local foci = resolve(env, "GetMouseFoci")
    local focus = resolve(env, "GetMouseFocus")
    if type(foci) == "function" then
        local ok, list = pcall(foci)
        frame = ok and type(list) == "table" and list[1] or nil
    elseif type(focus) == "function" then
        local ok, f = pcall(focus)
        frame = ok and f or nil
    end
    if type(frame) ~= "table" then
        out[#out + 1] = "  nothing under the mouse (hold the mouse over an item button while you enter the command)"
        return table.concat(out, "\n")
    end
    local chain, f, depth = {}, frame, 0
    while type(f) == "table" and depth < 8 do
        chain[#chain + 1] = frameName(f)
        local ok, parent = pcall(function() return f.GetParent and f:GetParent() end)
        f = ok and parent or nil
        depth = depth + 1
    end
    out[#out + 1] = "  chain: " .. table.concat(chain, " < ")
    out[#out + 1] = "  fields: " .. shape(frame)
    local mt = getmetatable(frame)
    local idx = type(mt) == "table" and mt.__index
    if type(idx) == "table" then out[#out + 1] = "  methods: " .. shape(idx) end
    for _, m in ipairs({ "GetID", "GetBagID", "GetSlotAndBagID", "GetItemLink", "GetItemID" }) do
        local fn = frame[m]
        if type(fn) == "function" then
            local res = { pcall(fn, frame) }
            out[#out + 1] = ("  %s(): %s"):format(m, res[1] and table.concat({ tostring(res[2]), tostring(res[3]) }, ", ") or "error")
        end
    end
    return table.concat(out, "\n")
end
