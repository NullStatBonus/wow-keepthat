-- Auctionator shopping list export (spec auctionator-export; design D9; contract in docs/contracts.md).
--
-- Export(profession, category) makes the Auctionator list "KeepThat: <Profession> <Category>" with one
-- exact search per enabled material of that profession and category. Leveling materials with a count
-- are included only while the count still needed is more than the player carries, with the difference
-- as the quantity. CreateShoppingList replaces a list of the same name, so a re-export replaces only
-- our own list. Every Auctionator call is in pcall; an error turns the export off for the session.
local _, ns = ...
local L = ns.L

local Auctionator = { CALLER = "KeepThat" }
ns.Auctionator = Auctionator

local function api()
    local v1 = ns.Adapter and ns.Adapter.Resolve("Auctionator.API.v1")
    if type(v1) ~= "table" then return nil end
    if type(v1.CreateShoppingList) ~= "function" or type(v1.ConvertToSearchString) ~= "function" then return nil end
    return v1
end

local function profile()
    return ns.addon and ns.addon.db and ns.addon.db.profile or ns.defaults and ns.defaults.profile or {}
end

function Auctionator.Detect()
    return api() ~= nil
end

function Auctionator.Start()
    Auctionator.active = true
end

-- Whether the export can be used now, and if not, a short reason for the disabled control.
function Auctionator.Available()
    if not api() then return false, L["Auctionator is needed."] end
    if ns.client ~= "forever" then return false, L["Integrations are not yet available on Classic Era."] end
    local p = profile()
    if p.integrations and p.integrations.auctionator == false then
        return false, L["The Auctionator integration is turned off."]
    end
    if Auctionator.failed then return false, L["The Auctionator export stopped after an error. See /kt log."] end
    return true
end

local function itemName(itemID)
    local A = ns.Adapter
    local name = A and A.ItemName and A.ItemName(itemID)
    if type(name) ~= "string" or name == "" then
        local catalog = ns.Data and ns.Data.Catalog
        name = catalog and catalog.itemNames and catalog.itemNames[itemID]
    end
    return name
end

local function carried(itemID)
    local A = ns.Adapter
    local n = A and A.ItemCount and A.ItemCount(itemID)
    return type(n) == "number" and n or 0
end

-- { { itemID, quantity or nil }, ... } for one profession and category, the materials still enabled
-- (and for leveling, still needed).
function Auctionator.Materials(profession, category)
    local disabled = (profile().disabled or {})[category] or {}
    local out = {}
    if category == "endgame" then
        local catalog = ns.Data and ns.Data.Catalog
        for itemID, entry in pairs(catalog and catalog.endgame or {}) do
            if entry[profession] and not disabled[itemID] then out[#out + 1] = { itemID = itemID } end
        end
    elseif category == "leveling" then
        local ctx = ns.Context and ns.Context.Get() or {}
        local routes = ctx.routes or (ns.Data and ns.Data.Routes)
        local skill = (ctx.skills or {})[profession]
        local ids, seen = {}, {}
        for itemID in pairs(routes and routes.materials and routes.materials[profession] or {}) do
            seen[itemID] = true; ids[#ids + 1] = itemID
        end
        if ctx.extra and ns.ProfessionJournal and ns.ProfessionJournal.Items then
            for _, itemID in ipairs(ns.ProfessionJournal.Items(profession)) do
                if not seen[itemID] then seen[itemID] = true; ids[#ids + 1] = itemID end
            end
        end
        for _, itemID in ipairs(ids) do
            if not disabled[itemID] then
                local extra = ctx.extra and ctx.extra(profession, itemID) or nil
                local need = ns.Leveling.Need(routes, profession, itemID, skill, extra)
                if need then
                    if not need.high then
                        out[#out + 1] = { itemID = itemID }
                    else
                        local have = carried(itemID)
                        if need.high > have then out[#out + 1] = { itemID = itemID, quantity = need.high - have } end
                    end
                end
            end
        end
    end
    return out
end

local CATEGORY = { endgame = L["Endgame"], leveling = L["Leveling"] }

function Auctionator.ListName(profession, category)
    local name = ns.Wording and ns.Wording.Display and ns.Wording.Display(profession) or profession
    return L["KeepThat: %s %s"]:format(name, CATEGORY[category] or category)
end

local function failure(err)
    Auctionator.failed = true
    if ns.Log then ns.Log.Failure("auctionator", err) end
    return false, L["The Auctionator export stopped after an error. See /kt log."]
end

-- Makes (or replaces) the list. Returns true, number of searches; or false, reason.
function Auctionator.Export(profession, category)
    local ok, reason = Auctionator.Available()
    if not ok then return false, reason end
    if not CATEGORY[category] then return false, L["Choose endgame or leveling materials."] end
    local v1 = api()

    local rows = {}
    for _, m in ipairs(Auctionator.Materials(profession, category)) do
        local name = itemName(m.itemID)
        if name then rows[#rows + 1] = { name = name, quantity = m.quantity } end
    end
    table.sort(rows, function(a, b) return a.name < b.name end)

    local searches = {}
    for _, row in ipairs(rows) do
        local okConvert, search = pcall(v1.ConvertToSearchString, Auctionator.CALLER,
            { searchString = row.name, isExact = true, quantity = row.quantity })
        if not okConvert or type(search) ~= "string" then
            return failure("ConvertToSearchString: " .. tostring(search))
        end
        searches[#searches + 1] = search
    end
    local okCreate, err = pcall(v1.CreateShoppingList, Auctionator.CALLER, Auctionator.ListName(profession, category), searches)
    if not okCreate then return failure("CreateShoppingList: " .. tostring(err)) end
    return true, #searches
end

-- For the options page (Settings).
ns.AuctionatorExport = { Export = Auctionator.Export, Available = Auctionator.Available }

if ns.Integrations and ns.Integrations.Register then
    ns.Integrations.Register("auctionator", { detect = Auctionator.Detect, start = Auctionator.Start })
end
