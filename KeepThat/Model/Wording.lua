-- The text KeepThat shows for a classified item (spec material-tooltip). Plain Lua, no game calls.
-- Line(result) gives the one tooltip line; Details(result, ctx) gives the lines shown while Shift is held.
local _, ns = ...
local L = ns.L

local Wording = {}
ns.Wording = Wording

-- Display names, translated through L like every other sentence.
Wording.PROFESSIONS = {
    alchemy = L["Alchemy"], blacksmithing = L["Blacksmithing"], enchanting = L["Enchanting"],
    engineering = L["Engineering"], leatherworking = L["Leatherworking"], tailoring = L["Tailoring"],
    cooking = L["Cooking"], firstaid = L["First Aid"], mining = L["Mining"],
}
Wording.MAX_NAMED = 2
Wording.MAX_RECIPES = 3
Wording.MAX_STOCK = 5

-- The client's own profession names (Wording.UseClientNames), else the translated English ones.
Wording.clientNames = {}

function Wording.UseClientNames(names)
    Wording.clientNames = type(names) == "table" and names or {}
end

function Wording.Display(profession)
    return Wording.clientNames[profession] or Wording.PROFESSIONS[profession] or profession
end
local display = Wording.Display

-- "Alchemy, Blacksmithing" or "Alchemy, Blacksmithing +2".
local function professionList(names)
    table.sort(names)
    if #names <= Wording.MAX_NAMED then return table.concat(names, ", ") end
    local shown = {}
    for i = 1, Wording.MAX_NAMED do shown[i] = names[i] end
    return L["%s +%d"]:format(table.concat(shown, ", "), #names - Wording.MAX_NAMED)
end

-- "40" or "40-55"; nil when no source has a count.
function Wording.Count(need)
    if not need or not need.low then return nil end
    if need.low == need.high then return tostring(need.high) end
    return ("%d-%d"):format(need.low, need.high)
end

-- The one line and its kind ("endgame", "leveling" or "both"), or nil for an unmarked item.
function Wording.Line(result)
    if not result then return nil end
    local names, seen = {}, {}
    local function add(list)
        for _, e in ipairs(list or {}) do
            local name = display(e.profession)
            if not seen[name] then seen[name] = true; names[#names + 1] = name end
        end
    end
    add(result.endgame)
    add(result.leveling)
    if #names == 0 then return nil end
    local list = professionList(names)
    if result.endgame and result.leveling then return L["Endgame + Leveling: %s"]:format(list), "both" end
    if result.endgame then return L["Endgame: %s"]:format(list), "endgame" end
    return L["Leveling: %s"]:format(list), "leveling"
end

-- Text colors shared by the tooltip, the toast and the settings (Codex style review).
Wording.MUTED = "aaaaaa"      -- "KeepThat:" and secondary text
Wording.NEUTRAL = "dddddd"    -- profession names, purposes and counts
Wording.NOTE = "999999"       -- recipes, guides, hints

local function hex(c)
    if type(c) ~= "table" then return "ffffff" end
    local function b(v) return math.max(0, math.min(255, math.floor((v or 1) * 255 + 0.5))) end
    return ("%02x%02x%02x"):format(b(c.r), b(c.g), b(c.b))
end
Wording.Hex = hex

local function paint(color, textValue) return ("|cff%s%s|r"):format(color, textValue) end
Wording.Paint = paint

-- The one line with color codes: "KeepThat:" grey, only the category word in its color, profession
-- names neutral, and an optional grey "(Shift)" hint. colors = { endgame = {r,g,b}, leveling = {r,g,b} }.
-- opts = { prefix = true/false (default true), hint = true/false, owned = total across characters }
function Wording.ColoredLine(result, colors, opts)
    if not result or not Wording.Line(result) then return nil end
    opts = opts or {}
    colors = colors or {}
    local names, seen = {}, {}
    for _, list in ipairs({ result.endgame or {}, result.leveling or {} }) do
        for _, e in ipairs(list) do
            local name = display(e.profession)
            if not seen[name] then seen[name] = true; names[#names + 1] = name end
        end
    end
    local endgame = paint(hex(colors.endgame), L["Endgame"])
    local leveling = paint(hex(colors.leveling), L["Leveling"])
    local label
    if result.endgame and result.leveling then label = L["%s + %s"]:format(endgame, leveling)
    elseif result.endgame then label = endgame
    else label = leveling end
    local textValue = L["%s: %s"]:format(label, paint(Wording.NEUTRAL, professionList(names)))
    if opts.prefix ~= false then textValue = L["%s %s"]:format(paint(Wording.MUTED, L["KeepThat:"]), textValue) end
    if type(opts.owned) == "number" and opts.owned > 0 then
        textValue = L["%s %s"]:format(textValue, L["%s %s"]:format(paint(Wording.MUTED, "-"), paint(Wording.NEUTRAL, L["%d owned"]:format(opts.owned))))
    end
    if opts.hint then textValue = L["%s %s"]:format(textValue, paint(Wording.NOTE, L["(Shift)"])) end
    return textValue
end

-- What an endgame material is for: its listed reason, or what it is used to make.
function Wording.Purpose(entry, catalog, itemName)
    if entry.via then
        local parent = catalog.endgame and catalog.endgame[entry.via] and catalog.endgame[entry.via][entry.profession]
        local top = parent and parent[3] ~= 0 and parent[3] or nil
        if top then return L["Used to make %s for %s"]:format(itemName(entry.via), itemName(top)) end
        return L["Used to make %s"]:format(itemName(entry.via))
    end
    return entry.reason or ""
end

-- Difficulty words and their colors: Blizzard's TradeSkillTypeColor (design D6).
Wording.DIFFICULTY = {
    orange = { word = L["Orange"], color = "ff8040" },
    yellow = { word = L["Yellow"], color = "ffff00" },
    green = { word = L["Green"], color = "40bf40" },
    gray = { word = L["Gray"], color = "808080" },
}

-- The status after a recipe line: "Learned · Yellow", "Not learned", "Yellow", or nil when nothing is
-- known (spec "Recipe status on endgame recipe lines"). status = { learned = true|false|nil, difficulty }.
function Wording.RecipeStatus(status)
    if type(status) ~= "table" then return nil end
    local d = Wording.DIFFICULTY[status.difficulty]
    local word = d and paint(d.color, d.word)
    if status.learned == true then return word and L["Learned · %s"]:format(word) or L["Learned"] end
    if status.learned == false then return word and L["Not learned · %s"]:format(word) or L["Not learned"] end
    return word
end

-- Recipes of a profession that use itemID, in the "Recipe order" (design D8):
-- { { name, qty, status }, ... } and the total. ctx.recipeStatus(profession, spell) gives each status.
local function recipesUsing(catalog, profession, itemID, spellName, ctx)
    local found = {}
    for spell, rec in pairs(catalog and catalog.recipes or {}) do
        if rec.p == profession then
            for i = 1, #rec.r, 2 do
                if rec.r[i] == itemID then
                    local status = ctx.recipeStatus and ctx.recipeStatus(profession, spell) or nil
                    found[#found + 1] = { spell = spell, y = rec.y, qty = rec.r[i + 1], status = status,
                        state = status and status.learned }
                end
            end
        end
    end
    ns.RecipeKnowledge.Sort(found, ctx.recipeOrder)
    local out = {}
    for i = 1, math.min(#found, Wording.MAX_RECIPES) do
        out[i] = { name = spellName(found[i].spell), qty = found[i].qty, status = found[i].status }
    end
    return out, #found
end

-- Lines shown while Shift is held, a block per category and profession (Codex style review):
--     Endgame - Blacksmithing                       kind "endgame"  (category color)
--       Best-in-slot crafted gear                   kind "body"     (neutral)
--       Arcanite Reaper - 12 per craft              kind "note"     (grey)
--     Leveling - Tailoring, skill 250-300           kind "leveling"
--       40-55 needed, 18 in bags                    kind "body"
--       Includes 956 for Bolt of Runecloth          kind "note"
--       Guides: wow-professions.com, Wowhead        kind "note"
-- Returns a list of { text = ..., kind = ... }.
-- ctx = { catalog, routes, itemID, itemName = function(id), spellName = function(id),
--         carried = function(id) -> number or nil,
--         stock = { { name, self, count }, ... } (holders, already ordered; nil or empty adds no block),
--         recipeStatus = function(profession, spellID) -> { learned, difficulty } or nil,
--         needsHint = function(profession) -> true to ask the player to open it, recipeOrder = "learned"|...,
--         cost = function(itemID, profession) -> { quantity, cost = amount text or nil } or nil (the leveling shortfall's price) }
-- After the category blocks, a grey "Stock" heading and up to Wording.MAX_STOCK holder rows.
function Wording.Details(result, ctx)
    local out = {}
    if not result then return out end
    local catalog = ctx.catalog or {}
    local itemName = ctx.itemName or function(id) return (catalog.itemNames or {})[id] or ("#" .. id) end
    local spellName = ctx.spellName or function(id) return (catalog.spellNames or {})[id] or ("#" .. id) end
    local function row(textValue, kind) out[#out + 1] = { text = textValue, kind = kind } end

    -- With ctx.colors, a heading colors only its category word and keeps the rest neutral (kind "line",
    -- already colored); without it, the plain heading in the category color.
    local function heading(category, rest)
        if ctx.colors then
            local label = paint(hex(ctx.colors[category]), category == "endgame" and L["Endgame"] or L["Leveling"])
            row(L["  %s - %s"]:format(label, paint(Wording.NEUTRAL, rest)), "line")
        elseif category == "endgame" then
            row(L["  Endgame - %s"]:format(rest), "endgame")
        else
            row(L["  Leveling - %s"]:format(rest), "leveling")
        end
    end

    for _, e in ipairs(result.endgame or {}) do
        heading("endgame", display(e.profession))
        local purpose = Wording.Purpose(e, catalog, itemName)
        if purpose ~= "" then row(L["    %s"]:format(purpose), "body") end
        local recipes, total = recipesUsing(catalog, e.profession, ctx.itemID, spellName, ctx)
        for _, r in ipairs(recipes) do
            local textValue = L["    %s - %d per craft"]:format(r.name, r.qty)
            local status = Wording.RecipeStatus(r.status)
            if status then textValue = L["%s (%s)"]:format(textValue, status) end
            row(textValue, "note")
        end
        if total > #recipes then row(L["    and %d more recipes"]:format(total - #recipes), "note") end
        if total > 0 and ctx.needsHint and ctx.needsHint(e.profession) then
            row(L["    Open %s to see which recipes you know"]:format(display(e.profession)), "note")
        end
    end

    local carried = ctx.carried and ctx.carried(ctx.itemID)
    for _, e in ipairs(result.leveling or {}) do
        local need = e.need
        heading("leveling", L["%s, skill %d-%d"]:format(display(e.profession), need.from, need.to))
        local count = Wording.Count(need)
        if count and carried then row(L["    %s needed, %d in bags"]:format(count, carried), "body")
        elseif count then row(L["    %s needed"]:format(count), "body") end
        -- Directly below the count: the cost of the quantity still to buy (ctx.cost, only while the Auctionator estimate is on).
        local cost = ctx.cost and ctx.cost(ctx.itemID, e.profession)
        if cost and cost.quantity and cost.quantity > 0 then
            if cost.cost then row(L["    Estimated cost for %d: %s, from Auctionator's last scan."]:format(cost.quantity, cost.cost), "body")
            else row(L["    No recent Auctionator price for this item."], "body") end
        end
        -- The share that goes into an intermediate the route also needs (Runecloth into Bolt of Runecloth).
        local mats = ctx.routes and ctx.routes.materials and ctx.routes.materials[e.profession] or {}
        local vias = {}
        for via, n in pairs(need.via or {}) do
            if mats[via] and n > 0 then vias[#vias + 1] = { via = via, n = n } end
        end
        table.sort(vias, function(a, b) return a.n > b.n end)
        for i = 1, math.min(#vias, 2) do
            row(L["    Includes %d for %s"]:format(vias[i].n, itemName(vias[i].via)), "note")
        end
        if need.sources and #need.sources > 0 then
            row(L["    Guides: %s"]:format(table.concat(need.sources, L[", "])), "note")
        end
    end
    local stock = ctx.stock
    if stock and #stock > 0 then
        row(paint(Wording.MUTED, L["  Stock"]), "line")
        for i = 1, math.min(#stock, Wording.MAX_STOCK) do
            local h = stock[i]
            if h.self then row(L["    This character: %d"]:format(h.count), "body")
            else row(L["    %s: %d"]:format(h.name, h.count), "body") end
        end
        if #stock > Wording.MAX_STOCK then row(L["    +%d more"]:format(#stock - Wording.MAX_STOCK), "note") end
    end
    return out
end
