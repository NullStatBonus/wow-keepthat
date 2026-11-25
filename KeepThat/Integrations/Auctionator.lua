-- Auctionator shopping list export (spec auctionator-export; design D9; contract in docs/contracts.md).
--
-- Export(profession, category) makes the Auctionator list "KeepThat: <Profession> <Category>" with one
-- exact search per enabled material of that profession and category. Leveling materials with a count
-- are included only while the count still needed is more than the player carries, with the difference
-- as the quantity. CreateShoppingList replaces a list of the same name, so a re-export replaces only
-- our own list. Every Auctionator call is in pcall; an error turns the export off for the session.
--
-- Estimate(profession) and ItemCost(itemID, profession) (spec auctionator-export, material-tooltip) price the
-- leveling quantities from Auctionator's last scan while the estimateLevelingCost setting is on. A price
-- counts only with a fresh age; an unknown price is never 0. An error stops only the estimate.
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

-- The realm-and-faction total (even when incomplete) when stock is known, else this character's bags.
local function carried(itemID)
    local R = ns.StockRecorder
    if R and R.Total then
        local ok, total = pcall(R.Total, itemID)
        if ok and type(total) == "number" then return total end
    end
    local A = ns.Adapter
    local n = A and A.ItemCount and A.ItemCount(itemID)
    return type(n) == "number" and n or 0
end

-- { itemID, quantity or nil } while the leveling count is still more than what is carried (no quantity when
-- the route gives no count), else nil.
local function levelingRow(ctx, routes, skill, profession, itemID)
    local extra = ctx.extra and ctx.extra(profession, itemID) or nil
    local need = ns.Leveling.Need(routes, profession, itemID, skill, extra)
    if not need then return nil end
    if not need.high then return { itemID = itemID } end
    local have = carried(itemID)
    if need.high > have then return { itemID = itemID, quantity = need.high - have } end
    return nil
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
                local row = levelingRow(ctx, routes, skill, profession, itemID)
                if row then out[#out + 1] = row end
            end
        end
    end
    return out
end

-- Cost estimate ---------------------------------------------------------------------------------------

local function estimateFailure(err)
    Auctionator.estimateFailed = true
    if ns.Log then ns.Log.Failure("auctionator-estimate", err) end
end

-- Why the estimate cannot be used, or nil when it can (the setting is not part of this): the client, the
-- integration, Auctionator itself, the price functions, an earlier error.
function Auctionator.EstimateReason()
    if ns.client ~= "forever" then return L["Integrations are not yet available on Classic Era."] end
    local ok, reason = Auctionator.Available()
    if not ok then return reason end
    local v1 = api()
    if type(v1.GetAuctionPriceByItemID) ~= "function" or type(v1.GetAuctionAgeByItemID) ~= "function" then
        return L["This version of Auctionator gives no prices."]
    end
    if Auctionator.estimateFailed then return L["The cost estimate stopped after an error. See /kt log."] end
    return nil
end

-- Whether the estimate can be used now: no reason against it and the setting is on.
function Auctionator.EstimateAvailable()
    return profile().estimateLevelingCost == true and Auctionator.EstimateReason() == nil
end

-- The last scanned price in copper, or nil when unknown or too old (Auctionator gives no age past 21 days).
-- A second result is an error message when a call raised.
local function unitPrice(v1, itemID)
    local okPrice, price = pcall(v1.GetAuctionPriceByItemID, Auctionator.CALLER, itemID)
    if not okPrice then return nil, tostring(price) end
    local okAge, age = pcall(v1.GetAuctionAgeByItemID, Auctionator.CALLER, itemID)
    if not okAge then return nil, tostring(age) end
    if type(price) ~= "number" or type(age) ~= "number" then return nil end
    return price
end

-- Copper as "14g 40s". An exact estimate rounds up to the next silver, a lower bound rounds down.
local function money(copper, down)
    local silver = (down and math.floor or math.ceil)(copper / 100)
    local gold, rest = math.floor(silver / 100), silver % 100
    if gold > 0 and rest > 0 then return L["%dg %ds"]:format(gold, rest) end
    if gold > 0 then return L["%dg"]:format(gold) end
    return L["%ds"]:format(rest)
end

-- { copper, priced, unknown } for the leveling materials still needed, or nil when the estimate is not available.
function Auctionator.Estimate(profession)
    if not Auctionator.EstimateAvailable() then return nil end
    local v1 = api()
    local est = { copper = 0, priced = 0, unknown = 0 }
    for _, row in ipairs(Auctionator.Materials(profession, "leveling")) do
        local price, err
        if row.quantity then price, err = unitPrice(v1, row.itemID) end
        if err then estimateFailure(err); return nil end
        if price then
            est.copper = est.copper + price * row.quantity
            est.priced = est.priced + 1
        else
            est.unknown = est.unknown + 1
        end
    end
    return est
end

-- The sentences under the leveling export button, or nil for nothing to show.
function Auctionator.EstimateLines(profession)
    local est = Auctionator.Estimate(profession)
    if not est or est.priced + est.unknown == 0 then return nil end
    -- One debug line per changed result (the page redraws often), the evidence a reviewer reads in /kt log.
    local summary = ("estimate %s: %d copper, %d priced, %d unknown"):format(profession, est.copper, est.priced, est.unknown)
    if summary ~= Auctionator.lastSummary then
        Auctionator.lastSummary = summary
        if ns.Log then ns.Log.Record("auctionator", summary) end
        if ns.CheckThat then ns.CheckThat.Report("estimate.copper", est.copper) end
    end
    if est.priced == 0 then return { L["No cost estimate is available for these materials."] } end
    if est.unknown == 0 then return { L["Estimated cost: %s, from Auctionator's last scan."]:format(money(est.copper)) } end
    return {
        L["At least %s from Auctionator's last scan."]:format(money(est.copper, true)),
        est.unknown == 1 and L["One material could not be priced."] or L["%d materials could not be priced."]:format(est.unknown),
    }
end

-- For the Shift tooltip: { quantity, cost } (cost is the amount text, nil when no recent price), or nil when
-- there is nothing to price (setting off, nothing still needed, count unknown, or an error).
function Auctionator.ItemCost(itemID, profession)
    if not Auctionator.EstimateAvailable() then return nil end
    local ctx = ns.Context and ns.Context.Get() or {}
    local routes = ctx.routes or (ns.Data and ns.Data.Routes)
    local off = (profile().disabled or {}).leveling
    if off and off[itemID] then return nil end
    local row = levelingRow(ctx, routes, (ctx.skills or {})[profession], profession, itemID)
    if not row or not row.quantity then return nil end
    local price, err = unitPrice(api(), itemID)
    if err then estimateFailure(err); return nil end
    return { quantity = row.quantity, cost = price and money(price * row.quantity) or nil }
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
    if ns.Log then ns.Log.Record("auctionator", ("export %s %s: %d items"):format(profession, category, #searches)) end
    if ns.CheckThat then ns.CheckThat.Report("export.items", #searches) end
    return true, #searches
end

-- Turning the estimate setting on or off logs the next page draw's estimate line again.
function Auctionator.ResetEstimate() Auctionator.lastSummary = nil end

-- For the options page (Settings).
ns.AuctionatorExport = { Export = Auctionator.Export, Available = Auctionator.Available,
    Materials = Auctionator.Materials, ListName = Auctionator.ListName,
    EstimateLines = Auctionator.EstimateLines, EstimateAvailable = Auctionator.EstimateAvailable,
    EstimateReason = Auctionator.EstimateReason, ResetEstimate = Auctionator.ResetEstimate }

if ns.Integrations and ns.Integrations.Register then
    ns.Integrations.Register("auctionator", { detect = Auctionator.Detect, start = Auctionator.Start })
end
