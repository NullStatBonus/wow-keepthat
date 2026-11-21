-- Core/Adapter_Stock.lua: identity, clock, container lists, container and inbox reads.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ns = {}
H.load("Core/Adapter.lua", ns)
H.load("Core/Adapter_Stock.lua", ns)
local A = ns.Adapter

local function list(t) return table.concat(t, ",") end

-- Identity
A.env = { UnitFullName = function() return "Ann", "Realm" end, UnitFactionGroup = function() return "Horde", "Horde" end }
local n, r, f = A.PlayerIdentity()
eq(n .. r .. f, "AnnRealmHorde", "identity from UnitFullName")
A.env = { UnitFullName = function() return "Ann", nil end, GetNormalizedRealmName = function() return "Realm" end,
    UnitFactionGroup = function() return "Alliance" end }
n, r, f = A.PlayerIdentity()
eq(r, "Realm", "realm falls back to GetNormalizedRealmName")
A.env = { UnitName = function() return "Bo" end, GetNormalizedRealmName = function() return "R" end,
    UnitFactionGroup = function() return "Alliance" end }
eq(select(1, A.PlayerIdentity()), "Bo", "name falls back to UnitName")
A.env = { UnitFullName = function() return "Ann", "Realm" end }
eq(A.PlayerIdentity(), nil, "no faction: nil")
A.env = {}
eq(A.PlayerIdentity(), nil, "no API: nil")
-- WoW Forever: UnitFullName gives the surname where the realm was; the realm comes from the realm name and
-- the name is "Name Surname" (AceDB-3.0 minor 40's rule), with the surname as a fourth return.
local forever = { UnitFullName = function() return "Me", "Smith" end, RegionalUniqueNamesEnabled = function() return true end,
    UnitNameUnmodified = function() return "Me", "Smith" end, GetNormalizedRealmName = function() return "Realm" end,
    UnitFactionGroup = function() return "Alliance" end }
A.env = forever
local s
n, r, f, s = A.PlayerIdentity()
eq(n, "Me Smith", "Forever: full name")
eq(r, "Realm", "Forever: the realm, not the surname")
eq(f, "Alliance", "Forever: faction")
eq(s, "Smith", "Forever: surname returned")
forever.GetNormalizedRealmName = nil
forever.GetRealmName = function() return "Real Realm" end
eq(select(2, A.PlayerIdentity()), "RealRealm", "Forever: realm name without spaces when not normalized")
forever.GetRealmName = nil
eq(A.PlayerIdentity(), nil, "Forever: no ruleset and no realm name: nil, never the surname")
-- The player's Forever save (2026-11-20): no realm name at login, so 0.4.5 recorded nothing. The realm is the
-- ruleset, as AceDB-3.0 minor 40 and Syndicator key it.
local active = {}
forever.Enum = { GameRule = { HardcoreRuleset = 1, RPRuleset = 2, PvPRuleset = 3 } }
forever.C_GameRules = { IsGameRuleActive = function(rule) return active[rule] == true end }
forever.GetNormalizedRealmName = function() return nil end
forever.GetRealmName = function() return "" end
n, r, f, s = A.PlayerIdentity()
eq(n, "Me Smith", "Forever without a realm name: full name")
eq(r, "PvE", "Forever without a realm name: the ruleset")
eq(s, "Smith", "Forever without a realm name: surname")
active = { [3] = true }; eq(select(2, A.PlayerIdentity()), "PvP", "PvP ruleset")
active = { [2] = true }; eq(select(2, A.PlayerIdentity()), "RP", "RP ruleset")
active = { [2] = true, [3] = true }; eq(select(2, A.PlayerIdentity()), "RP-PvP", "RP-PvP ruleset")
active = { [1] = true, [3] = true }; eq(select(2, A.PlayerIdentity()), "Hardcore", "Hardcore ruleset first")
active = {}
forever.GetNormalizedRealmName = function() return "SomeRealm" end
eq(select(2, A.PlayerIdentity()), "PvE", "Forever: the ruleset even when a realm name is given")
forever.C_GameRules.IsGameRuleActive = function() error("x") end
eq(select(2, A.PlayerIdentity()), "PvE", "a raising rule check counts as off")
-- Surnames off (Classic Era): UnitNameUnmodified's second return is not a surname; identity as before.
A.env = { UnitFullName = function() return "Ann", "Realm" end, RegionalUniqueNamesEnabled = function() return false end,
    UnitNameUnmodified = function() return "Ann", "Other" end, GetNormalizedRealmName = function() return "Realm" end,
    UnitFactionGroup = function() return "Horde" end }
n, r, f, s = A.PlayerIdentity()
eq(n .. r .. f, "AnnRealmHorde", "Era: identity unchanged")
eq(s, nil, "Era: no surname")

-- Clock and After
A.env = { time = function() return 1234 end }
eq(A.Clock(), 1234, "clock")
A.env = { time = function() return "soon" end }
eq(A.Clock(), nil, "non-number clock: nil")
A.env = { time = function() error("x") end }
eq(A.Clock(), nil, "raising clock: nil")
local ran
A.env = { C_Timer = { After = function(s, fn) ran = s; fn() end } }
eq(A.After(0, function() end), true, "After scheduled")
eq(ran, 0, "After passes seconds")
A.env = {}
eq(A.After(0, function() end), false, "After missing: false")

-- Bag IDs
A.env = { BACKPACK_CONTAINER = 0, NUM_BAG_SLOTS = 4, NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5, KEYRING_CONTAINER = -2 }
eq(list(A.BagIDs()), "0,1,2,3,4,5", "bags include the reagent bag, never the keyring")
A.env = { NUM_BAG_SLOTS = 4 }
eq(list(A.BagIDs()), "0,1,2,3,4", "bags without a reagent bag")
A.env = {}
eq(list(A.BagIDs()), "0,1,2,3,4", "bag defaults")

-- Bank: classic range
local function slotsFn() return 0 end
A.env = { NUM_BAG_SLOTS = 4, NUM_BANKBAGSLOTS = 6, BANK_CONTAINER = -1, GetContainerNumSlots = slotsFn }
eq(list(A.BankIDs()), "-1,5,6,7,8,9,10", "classic bank range")
eq(A.BankUsesTabs(), false, "classic: no tabs")
eq(A.BankTabBagID(1), nil, "classic: no tab bag")
A.env.REAGENTBANK_CONTAINER = -3
eq(list(A.BankIDs()), "-1,5,6,7,8,9,10,-3", "reagent bank when defined")
A.env = { NUM_BAG_SLOTS = 4, NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5, NUM_BANKBAGSLOTS = 6, GetContainerNumSlots = slotsFn }
eq(list(A.BankIDs()), "-1,6,7,8,9,10,11", "bank bags start after the reagent bag")
A.env = {}
eq(A.BankIDs(), nil, "no bank functions: nil")
A.env = { NUM_BANKBAGSLOTS = 6 }
eq(A.BankIDs(), nil, "no way to read containers: nil")

-- Bank: tabs
local tabsEnv = function()
    return {
        Enum = { BagIndex = { CharacterBankTab_1 = 6, CharacterBankTab_2 = 7 }, BankType = { Character = 0 } },
        C_Bank = { FetchPurchasedBankTabData = function(t) if t == 0 then return { { ID = 6 }, { ID = 9 } } end end },
    }
end
A.env = tabsEnv()
eq(A.BankUsesTabs(), true, "tabs path")
eq(list(A.BankIDs()), "6,9", "tab IDs from purchased data")
eq(A.BankTabBagID(2), 9, "tab 2 from purchased data")
eq(A.BankTabBagID(1), 6, "tab 1")
eq(A.BankTabBagID(3), nil, "unknown tab")
-- Review #3: a tab without an ID takes the tab enum; with neither, the list is unknown, never shortened.
local fetch = A.env.C_Bank.FetchPurchasedBankTabData
A.env.C_Bank.FetchPurchasedBankTabData = function() return { { ID = 6 }, {} } end
eq(list(A.BankIDs()), "6,7", "tab without an ID: from the enum")
A.env.C_Bank.FetchPurchasedBankTabData = function() return { { ID = 6 }, {}, { ID = "x" } } end
eq(A.BankIDs(), nil, "tab with neither: list unknown")
A.env.C_Bank.FetchPurchasedBankTabData = fetch
A.env = tabsEnv()
A.env.C_Bank.FetchPurchasedBankTabData = function() return {} end
eq(A.BankTabBagID(2), 7, "tab falls back to the enum")
eq(#A.BankIDs(), 0, "no purchased tabs: empty list")
A.env.C_Bank.FetchPurchasedBankTabData = function() error("x") end
eq(A.BankIDs(), nil, "raising tab call: nil")
A.env = tabsEnv()
A.env.C_Bank = nil
eq(A.BankUsesTabs(), false, "tabs need the C_Bank call")

A.env = tabsEnv()
A.env.Enum.BagIndex = {}
eq(A.BankUsesTabs(), false, "tabs need the enum tab")
A.env = { Enum = { BagIndex = { CharacterBankTab_1 = 6 } } }
eq(A.BankTabBagID(1), nil, "tab bag only on the tabs path")

-- ReadContainer
local function bagEnv(slots)
    return {
        C_Container = {
            GetContainerNumSlots = function(b) return #(slots[b] or {}) end,
            GetContainerItemInfo = function(b, s) return slots[b][s] or nil end,
        },
    }
end
local tracked = { [100] = true, [200] = true }
local env = bagEnv({ [0] = { { itemID = 100, stackCount = 5 }, false, { itemID = 999, stackCount = 3 }, { itemID = 100, stackCount = 2 } } })
env.C_Container.GetContainerItemInfo = function(b, s) local v = ({ [0] = { { itemID = 100, stackCount = 5 }, nil, { itemID = 999, stackCount = 3 }, { itemID = 100, stackCount = 2 } } })[b][s]; return v end
A.env = env
local got = A.ReadContainer(0, tracked)
eq(got[100], 7, "counts summed over tracked ID")
eq(got[999], nil, "untracked ignored")
eq(next(A.ReadContainer(0, {})), nil, "no tracked: empty")

-- empty slot with GetContainerItemID nil
env.C_Container.GetContainerItemID = function() return nil end
eq(A.ReadContainer(0, tracked)[100], 7, "empty slot skipped with ID function present")
-- occupied slot missing stackCount
env.C_Container.GetContainerItemInfo = function() return { itemID = 100 } end
eq(A.ReadContainer(0, tracked), nil, "missing stackCount: nil")
-- occupied slot missing itemID
env.C_Container.GetContainerItemInfo = function() return { stackCount = 3 } end
env.C_Container.GetContainerItemID = function() return nil end
eq(A.ReadContainer(0, tracked), nil, "missing itemID: nil")
-- ID from GetContainerItemID when info lacks it
env.C_Container.GetContainerItemID = function() return 200 end
eq(A.ReadContainer(0, tracked)[200], 3 * 4, "itemID from GetContainerItemID")
-- info nil but ID present: occupied without count
env.C_Container.GetContainerItemInfo = function() return nil end
eq(A.ReadContainer(0, tracked), nil, "ID without info: nil")
-- raising
env.C_Container.GetContainerItemInfo = function() error("boom") end
eq(A.ReadContainer(0, tracked), nil, "raising info: nil")
env = bagEnv({ [0] = { { itemID = 100, stackCount = 1 } } })
env.C_Container.GetContainerNumSlots = function() error("boom") end
A.env = env
eq(A.ReadContainer(0, tracked), nil, "raising slot count: nil")
A.env = { C_Container = { GetContainerItemInfo = function() end } }
eq(A.ReadContainer(0, tracked), nil, "missing slot count function: nil")
A.env = { C_Container = { GetContainerNumSlots = function() return 1 end, GetContainerItemInfo = function() error("boom") end } }
eq(A.ReadContainer(0, tracked), nil, "raising info without an ID function: nil")
A.env = { C_Container = { GetContainerNumSlots = function() return nil end, GetContainerItemInfo = function() end } }
eq(A.ReadContainer(0, tracked), nil, "non-number slot count: nil")
A.env = { C_Container = { GetContainerNumSlots = function() return 2 end } }
eq(A.ReadContainer(0, tracked), nil, "no item info function: nil")
-- legacy globals
local legacy = { { "tex", 4 }, nil, { "tex", 1 } }
A.env = {
    GetContainerNumSlots = function() return 3 end,
    GetContainerItemInfo = function(_, s) local v = legacy[s]; if v then return v[1], v[2] end end,
    GetContainerItemID = function(_, s) return legacy[s] and 100 or nil end,
}
eq(A.ReadContainer(-1, tracked)[100], 5, "legacy globals")
legacy = { { "tex" } }
A.env.GetContainerNumSlots = function() return 1 end
eq(A.ReadContainer(-1, tracked), nil, "legacy occupied without count: nil")

-- Inbox
eq(A.MailAvailable(), false, "no inbox function")
A.env = {}
eq(A.ReadInbox(tracked), nil, "missing GetInboxNumItems: nil")
local mail = {
    { header = true, items = { { "Ore", 100, nil, 5 }, { "Bar", nil, nil, 2, link = "|cff|Hitem:200::|h[Bar]|h" } } },
    { header = true, items = {} },
    { header = true, items = { { "Junk", 999, nil, 9 } } },
}
local function inboxEnv()
    return {
        GetInboxNumItems = function() return #mail end,
        GetInboxHeaderInfo = function(i)
            local m = mail[i]
            if not m.header then return nil end
            return "icon", "stat", "sender", "subject", 0, 0, 5, #m.items > 0
        end,
        GetInboxItem = function(i, a) local it = mail[i].items[a]; if it then return it[1], it[2], nil, it[4] end end,
        GetInboxItemLink = function(i, a) return mail[i].items[a].link end,
    }
end
A.env = inboxEnv()
eq(A.MailAvailable(), true, "inbox available")
got = A.ReadInbox(tracked)
eq(got[100], 5, "attachment counted")
eq(got[200], 2, "itemID parsed from the link")
eq(got[999], nil, "untracked ignored")
mail[2].header = false
eq(A.ReadInbox(tracked), nil, "header nil: nil")
mail[2].header = true
mail[1].items[2].link = nil
eq(A.ReadInbox(tracked), nil, "name without ID or link: nil")
mail[1].items[2].link = "|Hitem:200|h"
mail[1].items[1][4] = nil
eq(A.ReadInbox(tracked), nil, "attachment without count: nil")
mail[1].items[1][4] = 5
A.env = inboxEnv()
A.env.GetInboxItem = function() error("boom") end
eq(A.ReadInbox(tracked), nil, "raising GetInboxItem: nil")
A.env = inboxEnv()
A.env.ATTACHMENTS_MAX_RECEIVE = 1
got = A.ReadInbox(tracked)
eq(got[200], nil, "attachment limit honored")
eq(got[100], 5, "first attachment within the limit")
A.env = inboxEnv()
A.env.GetInboxHeaderInfo = function(i) return "i", "s", "x", "y", 0, 0, 5, false end
eq(next(A.ReadInbox(tracked)), nil, "hasItem false skips attachments")

H.done()
