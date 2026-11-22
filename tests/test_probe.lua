-- The probe reports present and missing APIs, loot strings, loaded addons, addon globals and
-- hovered frames from an injected environment, and survives functions that error.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ns = { version = "0.0.0" }
H.load("Core/Adapter.lua", ns)
H.load("Debug/Probe.lua", ns)

local function has(text, needle, msg) eq(text:find(needle, 1, true) ~= nil, true, msg .. " (" .. needle .. ")") end

local frame = { HasScript = function(_, s) return s == "OnTooltipSetItem" end }
local env = {
    GetBuildInfo = function() return "1.15.9", "12345", "Nov 1 2026", 11509 end,
    GameTooltip = frame,
    C_Container = { GetContainerItemID = function() end, GetContainerNumSlots = function() end },
    GetItemInfo = function() error("boom") end,
    LOOT_ITEM_SELF = "You receive loot: %s.",
    C_AddOns = {
        GetNumAddOns = function() return 3 end,
        GetAddOnInfo = function(i) return ({ "Baganator", "DFL_ProfessionJournal", "Disabled" })[i] end,
        IsAddOnLoaded = function(name) return name ~= "Disabled" end,
        GetAddOnMetadata = function(name, field) return field == "Version" and name == "Baganator" and "1.2" or nil end,
    },
    Baganator = { API = { RegisterCornerWidget = function() end } },
    DFL_PJ_DB = { routes = {}, version = 3 },
}
env._G = env

local text = ns.Probe.Run(env)
has(text, "version 1.15.9, build 12345, interface 11509", "client build")
has(text, "GameTooltip OnTooltipSetItem: true", "old tooltip script detected")
has(text, "missing  TooltipDataProcessor.AddTooltipPostCall", "missing API reported")
has(text, "== Recipes ==", "recipe candidates listed (recipe-knowledge, task 1.1)")
has(text, "missing  GetCraftItemLink", "a missing recipe API is reported")
has(text, "present  C_Container: table, 2 keys: GetContainerItemID, GetContainerNumSlots", "table members listed")
has(text, "present  GetItemInfo (function)", "a function that errors is still reported, never called")
has(text, 'LOOT_ITEM_SELF: "You receive loot: %s."', "loot string shown")
has(text, "LOOT_ITEM_SELF_MULTIPLE: missing", "missing loot string")
has(text, "  Baganator 1.2", "loaded addon with version")
has(text, "  DFL_ProfessionJournal", "loaded addon without version")
eq(text:find("Disabled", 1, true), nil, "addons that are not loaded are left out")
has(text, "Baganator.API: table, 1 keys: RegisterCornerWidget", "addon API shape")
has(text, "Bagnon: missing", "missing addon global")
has(text, "DFL_PJ_DB: table, 2 keys: routes, version", "unknown global found by name pattern")

-- An empty environment still gives a whole report.
local empty = ns.Probe.Run({})
has(empty, "GetBuildInfo missing", "no build info")
has(empty, "addon list unavailable", "no addon list")
has(empty, "== Globals by name pattern ==\n  none", "no matching globals")

-- Pattern scan skips bare UI pieces but keeps frames that carry an API.
local handle = newproxy()
local scanEnv = { DFLDJItemScan1Texture = { [0] = handle }, EUI_Bags = { [0] = handle, A = 1, B = 2, RegisterItemOverlayIcon = function() end } }
local scan = ns.Probe.Run(scanEnv)
eq(scan:find("DFLDJItemScan1Texture", 1, true), nil, "a bare texture is skipped")
has(scan, "EUI_Bags: table, 4 keys", "a frame with an API is kept")
eq(ns.Probe.IsBareRegion({ x = 1 }), false, "a plain data table is never bare")

-- Path: every member of a table with its type.
local pathEnv = { NS = { API = { GetRoute = function() end, version = 2, name = "pj", ok = false, list = { 1, 2, 3 }, [5] = "five" } } }
local path = ns.Probe.Path("NS.API", pathEnv)
has(path, "== NS.API ==", "path header")
has(path, "  GetRoute: function", "a function member")
has(path, "  version: 2", "a number member")
has(path, '  name: "pj"', "a string member")
has(path, "  ok: false", "a false member is shown, not dropped")
has(path, "  list: table (3 keys)", "a nested table shows its size")
has(path, '  5: "five"', "a numeric key")
has(ns.Probe.Path("NS.Missing", pathEnv), "  missing", "missing path")
has(ns.Probe.Path("NS.API.version", pathEnv), "  number: 2", "a value that is not a table")

-- Hover: the frame under the mouse, its parents, fields and bag/slot.
local parent = { GetName = function() return "EllesmereBagsFrame" end, GetObjectType = function() return "Frame" end }
-- Auctionator price functions: missing API, present functions with a sample value, and one that errors.
has(text, "Auctionator.API.v1 missing", "no Auctionator: reported, no error")
do
    local calls = {}
    local priced = ns.Probe.Run({ Auctionator = { API = { v1 = {
        GetAuctionPriceByItemID = function(caller, id) calls[#calls + 1] = caller .. id; return 12345 end,
        GetAuctionAgeByItemID = function() error("boom") end,
    } } } })
    has(priced, "== Auctionator prices ==", "price section")
    has(priced, "present  GetAuctionPriceByItemID(14047) = 12345", "price sample read")
    has(priced, "present  GetAuctionAgeByItemID(14047) = error: ", "an erroring function is reported")
    has(priced, "missing  IsAuctionDataExactByItemID", "a missing function is reported")
    eq(calls[1], "KeepThat14047", "the sample uses the KeepThat callerID")
end

local button = setmetatable({ bagID = 0,
    GetName = function() return nil end, GetObjectType = function() return "ItemButton" end,
    GetParent = function() return parent end, GetBagID = function() return 0 end,
    GetID = function() error("no id") end,
}, { __index = { SetItem = function() end } })
local hover = ns.Probe.Hover({ GetMouseFoci = function() return { button } end })
has(hover, "chain: <anonymous> [ItemButton] < EllesmereBagsFrame [Frame]", "parent chain")
has(hover, "fields: table", "fields listed")
has(hover, "methods: table, 1 keys: SetItem", "methods from the metatable")
has(hover, "GetBagID(): 0, nil", "bag ID read")
has(hover, "GetID(): error", "an erroring method is reported")
has(ns.Probe.Hover({}), "nothing under the mouse", "no focus API")
has(ns.Probe.Hover({ GetMouseFocus = function() return nil end }), "nothing under the mouse", "nothing hovered")

H.done()
