-- Game reads for the cross-character stock: who is playing, the clock, which bag and bank containers
-- exist, container contents and the inbox. Paths are chosen by which functions exist, never by client.
local _, ns = ...
local A = ns.Adapter

local function try(path, ...)
    local f = A.Resolve(path)
    if type(f) ~= "function" then return false end
    local res = { pcall(f, ...) }
    if not res[1] then return false end
    return true, unpack(res, 2, table.maxn(res))
end

local function str(v)
    return type(v) == "string" and v ~= "" and v or nil
end

-- WoW Forever has no realm names: characters share a world per ruleset, so the realm is the ruleset, keyed
-- the way AceDB-3.0 minor 40 and Syndicator key it. nil when the client has no game rules.
local function ruleset()
    local rules = A.Resolve("Enum.GameRule")
    if type(rules) ~= "table" or not A.Has("C_GameRules.IsGameRuleActive") then return nil end
    local function active(name)
        if rules[name] == nil then return false end
        local _, on = try("C_GameRules.IsGameRuleActive", rules[name])
        return on == true
    end
    if active("HardcoreRuleset") then return "Hardcore" end
    local rp, pvp = active("RPRuleset"), active("PvPRuleset")
    if rp and pvp then return "RP-PvP" end
    if rp then return "RP" end
    if pvp then return "PvP" end
    return "PvE"
end

-- name, realm, faction (strings) or nil. On a client with surnames (WoW Forever: RegionalUniqueNamesEnabled,
-- the same rule as AceDB-3.0 minor 40) the name is "Name Surname", the realm is the ruleset and the surname
-- is a fourth return; UnitFullName's second return is the surname there, never the realm. Otherwise the
-- realm comes from the realm name.
function A.PlayerIdentity()
    local _, regional = try("RegionalUniqueNamesEnabled")
    local _, first, surname = try("UnitNameUnmodified", "player")
    if not (regional == true and str(first) and str(surname)) then surname = nil end
    local _, name, realm = try("UnitFullName", "player")
    if surname then name, realm = first .. " " .. surname, ruleset() end
    if not str(name) then
        _, name = try("UnitName", "player")
    end
    local _, normalized = try("GetNormalizedRealmName")
    if str(normalized) and not (surname and str(realm)) then realm = normalized end
    if not str(realm) then
        local _, full = try("GetRealmName")
        realm = str(full) and full:gsub("[%s%-]", "") or nil
    end
    local _, faction = try("UnitFactionGroup", "player")
    if str(name) and str(realm) and str(faction) then return name, realm, faction, surname end
    return nil
end

-- Unix time (persists across sessions, unlike GetTime), or nil.
function A.Clock()
    local _, t = try("time")
    return type(t) == "number" and t or nil
end

-- C_Timer.After; true when scheduled.
function A.After(seconds, fn)
    return (try("C_Timer.After", seconds, fn))
end

local function num(path, default)
    local v = A.Resolve(path)
    return type(v) == "number" and v or default
end

-- The backpack through the last equipped bag (the reagent bag where one exists); never the keyring.
function A.BagIDs()
    local out = {}
    local last = num("NUM_TOTAL_EQUIPPED_BAG_SLOTS", num("NUM_BAG_SLOTS", 4))
    for id = num("BACKPACK_CONTAINER", 0), last do out[#out + 1] = id end
    return out
end

function A.BankUsesTabs()
    return A.Resolve("Enum.BagIndex.CharacterBankTab_1") ~= nil and A.Has("C_Bank.FetchPurchasedBankTabData")
end

local function purchasedTabs()
    local bankType = A.Resolve("Enum.BankType.Character")
    if bankType == nil then return nil end
    local ok, data = try("C_Bank.FetchPurchasedBankTabData", bankType)
    return ok and type(data) == "table" and data or nil
end

-- True when this client has a bank path at all (tabs, or the classic range). BankIDs can still fail on it.
function A.BankAvailable()
    if A.BankUsesTabs() then return true end
    return type(A.Resolve("NUM_BANKBAGSLOTS")) == "number"
        and (A.Has("C_Container.GetContainerNumSlots") or A.Has("GetContainerNumSlots"))
end

-- Bank container IDs, or nil when this client has no bank path or the tab list could not be read.
function A.BankIDs()
    local out = {}
    if A.BankUsesTabs() then
        local tabs = purchasedTabs()
        if not tabs then return nil end
        for i, tab in ipairs(tabs) do
            -- A tab without an ID takes the tab enum; if that is missing too the list is unknown (nil), never
            -- shortened: a shortened list would delete that tab's saved count.
            local id = type(tab) == "table" and tab.ID
            if type(id) ~= "number" then id = A.Resolve("Enum.BagIndex.CharacterBankTab_" .. i) end
            if type(id) ~= "number" then return nil end
            out[#out + 1] = id
        end
        return out
    end
    local slots = A.Resolve("NUM_BANKBAGSLOTS")
    if type(slots) ~= "number" then return nil end
    if not (A.Has("C_Container.GetContainerNumSlots") or A.Has("GetContainerNumSlots")) then return nil end
    -- Bank bags follow the last equipped bag, so a reagent bag (NUM_TOTAL_EQUIPPED_BAG_SLOTS) is never one of them.
    local bags = num("NUM_TOTAL_EQUIPPED_BAG_SLOTS", num("NUM_BAG_SLOTS", 4))
    out[1] = num("BANK_CONTAINER", -1)
    for id = bags + 1, bags + slots do out[#out + 1] = id end
    local reagent = A.Resolve("REAGENTBANK_CONTAINER")
    if type(reagent) == "number" then out[#out + 1] = reagent end
    return out
end

-- Bag ID of the Nth character bank tab on the tabs path; nil otherwise.
function A.BankTabBagID(tabIndex)
    if not A.BankUsesTabs() or type(tabIndex) ~= "number" then return nil end
    local tabs = purchasedTabs()
    local tab = tabs and tabs[tabIndex]
    if type(tab) == "table" and type(tab.ID) == "number" then return tab.ID end
    local id = A.Resolve("Enum.BagIndex")
    id = type(id) == "table" and id["CharacterBankTab_" .. tabIndex]
    return type(id) == "number" and id or nil
end

-- { [itemID] = count } over the tracked IDs in one container; nil when the read failed.
function A.ReadContainer(bagID, tracked)
    local okN, numSlots = try("C_Container.GetContainerNumSlots", bagID)
    if not okN then okN, numSlots = try("GetContainerNumSlots", bagID) end
    if not okN or type(numSlots) ~= "number" then return nil end
    local infoPath = A.Has("C_Container.GetContainerItemInfo") and "C_Container.GetContainerItemInfo"
        or A.Has("GetContainerItemInfo") and "GetContainerItemInfo"
    if not infoPath then return nil end
    local idPath = A.Has("C_Container.GetContainerItemID") and "C_Container.GetContainerItemID"
        or A.Has("GetContainerItemID") and "GetContainerItemID" or nil
    local out = {}
    for slot = 1, numSlots do
        local ok, first, second = try(infoPath, bagID, slot)
        if not ok then return nil end
        local itemID, count
        if type(first) == "table" then
            itemID, count = first.itemID, first.stackCount
        elseif first ~= nil then
            count = second -- legacy: texture, count, ...
        end
        if idPath and itemID == nil then
            local okID, id = try(idPath, bagID, slot)
            if not okID then return nil end
            itemID = id
        end
        if first ~= nil or itemID ~= nil then
            if type(itemID) ~= "number" or type(count) ~= "number" then return nil end
            if tracked[itemID] and count > 0 then out[itemID] = (out[itemID] or 0) + count end
        end
    end
    return out
end

function A.MailAvailable()
    return A.Has("GetInboxNumItems")
end

-- { [itemID] = count } over the tracked IDs in the inbox attachments; nil when any read failed.
function A.ReadInbox(tracked)
    local ok, n = try("GetInboxNumItems")
    if not ok or type(n) ~= "number" then return nil end
    local maxAttach = num("ATTACHMENTS_MAX_RECEIVE", num("ATTACHMENTS_MAX", 16))
    local out = {}
    for i = 1, n do
        local okH, icon, stationery, sender, subject, _, _, _, hasItem = try("GetInboxHeaderInfo", i)
        if not okH or (icon == nil and stationery == nil and sender == nil and subject == nil) then return nil end
        if hasItem then
            for a = 1, maxAttach do
                local okI, name, itemID, _, count = try("GetInboxItem", i, a)
                if not okI then return nil end
                if name ~= nil then
                    if itemID == nil then
                        local okL, link = try("GetInboxItemLink", i, a)
                        if not okL then return nil end
                        itemID = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
                        if itemID == nil then return nil end
                    end
                    if type(count) ~= "number" then return nil end
                    if tracked[itemID] and count > 0 then out[itemID] = (out[itemID] or 0) + count end
                end
            end
        end
    end
    return out
end
