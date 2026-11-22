-- The settings pages (spec settings). Each page is a pure function that returns an AceConfig group, so
-- tests can build and drive them without the game. Every setter ends in ns.Context.Invalidate(), so a
-- change shows on the next tooltip, toast or bag refresh without a reload.
local _, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

local APP = "KeepThat"

local function profile()
    return ns.addon and ns.addon.db and ns.addon.db.profile or ns.defaults.profile
end

local function changed()
    if ns.Presentation then ns.Presentation.Refresh()
    elseif ns.Context then ns.Context.Invalidate() end
end

-- Shared page shape: a group with items ordered as added.
local function page(name, order)
    return { type = "group", name = name, order = order, args = {} }
end

-- Widget counters per group, kept outside the groups: AceConfig rejects any field it does not know.
local counts = setmetatable({}, { __mode = "k" })

local function add(group, key, widget)
    counts[group] = (counts[group] or 0) + 1
    widget.order = counts[group]
    group.args[key] = widget
    return widget
end

-- Body text is explicit neutral #DDDDDD (Codex style review), unless it already carries a color.
local function neutral(value)
    if type(value) == "function" then
        return function(...) local v = value(...); return neutral(v) end
    end
    if type(value) ~= "string" or value == " " or value:find("^|c") then return value end
    return "|cffdddddd" .. value .. "|r"
end
Options.Neutral = neutral

local function text(group, key, body, hidden)
    return add(group, key, { type = "description", fontSize = "medium", width = "full", name = neutral(body), hidden = hidden })
end

-- Shared style (Codex style review): grey secondary text, small spacers between sections.
local GREY = "|cffaaaaaa%s|r"
local function grey(textValue) return GREY:format(textValue) end
local function note(group, key, body, hidden)
    return add(group, key, { type = "description", fontSize = "small", width = "full", name = body, hidden = hidden })
end
local function gap(group, key)
    return add(group, key, { type = "description", fontSize = "small", width = "full", name = " " })
end

local function introduction(group, heading, purpose)
    add(group, "pageTitle", { type = "header", name = heading })
    text(group, "intro", purpose)
    gap(group, "introGap")
end

-- Toggles keep their help on hover; visible help is only for consequences that matter.
local function profileToggle(group, key, name, desc, publicKey)
    publicKey = publicKey or key
    return add(group, key, {
        type = "toggle", width = "full", name = name, desc = desc,
        get = function() return profile()[key] end,
        set = function(_, value) if ns.Presentation and ns.Presentation.keys[publicKey] then ns.Presentation.Set(publicKey, value and "on" or "off")
            else profile()[key] = value and true or false; changed() end end,
    })
end

local function colorPicker(group, key, name, desc)
    return add(group, "color_" .. key, {
        type = "color", name = name, desc = desc, hasAlpha = false,
        get = function()
            local c = profile().colors[key]
            return c.r, c.g, c.b
        end,
        set = function(_, r, g, b)
            local c = profile().colors[key]
            c.r, c.g, c.b = r, g, b
            changed()
        end,
    })
end

-- Where the icon tint can show; the keys are the saved "locations" keys.
local LOCATION_NAMES = { bags = L["Bags"], bank = L["Bank"], merchant = L["Merchant"] }

function Options.Home(order)
    local g = page(L["Home"], order)
    introduction(g, L["Choose what to keep"], L["Choose materials to keep and where to show marks. KeepThat does not sell or move items."])
    note(g, "noCategories", grey(L["No materials are marked. Turn on a category below."]),
        function() return profile().endgame or profile().leveling end)
    note(g, "noSurfaces", grey(L["All displays are off. Select a display below or review items in Materials."]),
        function() return profile().tooltip or profile().toast or profile().mask end)

    add(g, "h_cat", { type = "header", name = L["What to mark"] })
    note(g, "categoryHelp", grey(L["Endgame marks high-level crafting materials. Leveling counts use your profession skill. Count ranges show differences between guides."]))
    profileToggle(g, "endgame", L["Endgame materials"], L["Mark materials used for endgame crafting."])
    profileToggle(g, "leveling", L["Leveling materials"], L["Mark materials you need to level your professions."])
    gap(g, "g1")

    add(g, "h_show", { type = "header", name = L["Where to show it"] })
    note(g, "displayHelp", grey(L["Hold Shift on a tooltip for details. Toasts show looted materials. Icon tint marks items in the selected locations."]))
    profileToggle(g, "tooltip", L["Tooltip line"], L["Add a short line to the tooltip of a material worth keeping."])
    -- Recipe order (spec settings "Recipe order setting"; design D8): under the line it orders, disabled with it.
    add(g, "recipeOrder", { type = "select", width = 1.5, name = L["Recipe order"],
        desc = L["Choose which recipes appear first when you hold Shift over an endgame material."],
        disabled = function() return not profile().tooltip end,
        values = { learned = L["Learned first"], unlearned = L["Not learned first"], skill = L["Highest skill first"] },
        sorting = { "learned", "unlearned", "skill" },
        get = function()
            local v = profile().recipeOrder
            return (v == "unlearned" or v == "skill") and v or "learned"
        end,
        set = function(_, v) profile().recipeOrder = v; changed() end })
    profileToggle(g, "toast", L["Loot toast"], L["Show a small message when you loot a material worth keeping."])
    profileToggle(g, "stockReminder", L["Login reminder"], L["Remind you at login when a character's bank or mailbox is not counted."], "stock.reminder")
    profileToggle(g, "mask", L["Icon tint"], L["Tint the icon of a material worth keeping."])
    add(g, "locations", {
        type = "multiselect", width = "half", name = L["Show the tint in"], desc = L["Where the icon tint is shown."],
        values = LOCATION_NAMES,
        disabled = function() return not profile().mask end,
        get = function(_, key) return profile().locations[key] and true or false end,
        set = function(_, key, value) profile().locations[key] = value and true or false; changed() end,
    })
    note(g, "locationHelp", grey(L["Turn on Icon tint to change locations. Saved choices stay the same."]), function() return profile().mask end)
    gap(g, "nextGap")
    text(g, "next", L["Review items in Materials. Set colors, size and position in Appearance."])
    return g
end

function Options.Appearance(order)
    local g = page(L["Appearance"], order)
    introduction(g, L["Make recommendations easy to read"], L["Set colors, size and position here. Turn features on or off in Home."])
    add(g, "h_colors", { type = "header", name = L["Category colors"] })
    note(g, "colorHelp", grey(L["Category colors apply to tooltips, toasts and icon tints. Tooltips and toasts also show category names."]))
    colorPicker(g, "endgame", L["Endgame color"], L["The color used for endgame materials."])
    colorPicker(g, "leveling", L["Leveling color"], L["The color used for leveling materials."])
    gap(g, "tintGap")
    add(g, "h_tint", { type = "header", name = L["Icon tint"] })
    note(g, "tintContext", grey(L["Lower values show more of the item icon. Set 0 to hide the tint."]))
    add(g, "maskOpacity", { type = "range", width = 1.5, name = L["Icon tint strength"],
        min = 0, max = 1, step = 0.05, isPercent = true,
        disabled = function() return not profile().mask end,
        get = function() return profile().maskOpacity or 0.4 end,
        set = function(_, v) profile().maskOpacity = v; changed() end })
    note(g, "maskHelp", grey(L["Icon tint is off. Turn it on in Home to change strength."]), function() return profile().mask end)
    gap(g, "toastGap")
    add(g, "h_toast", { type = "header", name = L["Loot toast"] })
    note(g, "toastContext", grey(L["Background opacity controls the panel and accent. Text and icon opacity controls the content. Set Scale to 100 for normal size."]))
    note(g, "toastHelp", grey(L["Loot toast is off. Turn it on in Home to change opacity, scale and sound. You can still preview the toast."]), function() return profile().toast end)
    local function control(id, key, label)
        local e = ns.Presentation.keys[key]
        add(g, id, { type = e.type == "boolean" and "toggle" or "range", width = e.type == "boolean" and "full" or 1.5, name = label,
            min = e.min, max = e.max, step = e.type == "integer" and 1 or nil,
            disabled = function() return e.type ~= "boolean" and not profile().toast end,
            get = e.get, set = function(_, v) ns.Presentation.Set(key, e.type == "boolean" and (v and "on" or "off") or v) end })
    end
    control("backgroundOpacity", "appearance.toast.background-opacity", L["Background opacity"])
    control("textOpacity", "appearance.toast.text-opacity", L["Text and icon opacity"])
    control("scale", "appearance.toast.scale", L["Scale"])
    -- Toast sound (spec settings, "Toast sound picker"; design D5). The list is built when the page is built or
    -- refreshed, since sound packs register with LibSharedMedia after login; a pack registered while the page
    -- is open appears on the next refresh. A saved pack that is gone shows the default.
    local S = ns.Sounds
    local function packs() return ns.Adapter and ns.Adapter.SoundPacks and ns.Adapter.SoundPacks() or nil end
    local function channel() return profile().toastSoundChannel end
    add(g, "toastSound", { type = "select", width = 1.5, name = L["Sound"],
        desc = L["Plays when a new loot toast appears. Choosing a different sound previews it once."],
        disabled = function() return not profile().toast end,
        values = function()
            local v = {}
            for _, e in ipairs(S.Entries(packs())) do v[e.key] = e.label end
            return v
        end,
        sorting = function()
            local keys = {}
            for _, e in ipairs(S.Entries(packs())) do keys[#keys + 1] = e.key end
            return keys
        end,
        get = function() return S.Effective(profile().toastSound or S.default, packs()) end,
        set = function(_, key)
            profile().toastSound = key
            S.Play(key, channel(), ns.Adapter)
            changed()
        end })
    add(g, "toastSoundChannel", { type = "select", name = L["Sound channel"],
        desc = L["Master plays even when game sound effects are off."],
        disabled = function() return not profile().toast end,
        values = { Master = L["Master"], SFX = L["Sound effects"] },
        sorting = { "Master", "SFX" },
        get = function() return channel() == "SFX" and "SFX" or "Master" end,
        set = function(_, v) profile().toastSoundChannel = v; changed() end })
    gap(g, "positionGap")
    add(g, "h_position", { type = "header", name = L["Toast position"] })
    note(g, "positionHelp", function()
        if profile().toastLocked then return grey(L["Position is locked. Clear Lock position to move or reset it."]) end
        if ns.Toast and ns.Toast.move then return grey(L["Move is active. Drag the sample. Select Done to save. Select Cancel or press Escape to discard changes."]) end
        return grey(L["Select Move to place the newest toast. Older toasts appear above it. Reset position changes only the position."])
    end)
    control("locked", "appearance.toast.locked", L["Lock position"])
    add(g, "toastMove", { type = "execute", name = L["Move"],
        desc = L["Unlock Lock position before moving. Drag, then choose Done or Cancel."],
        disabled = function() return profile().toastLocked end,
        func = function() ns.Toast.ShowMover() end })
    add(g, "done", { type = "execute", name = L["Done"], disabled = function() return not ns.Toast.move end,
        func = function() ns.Toast.DoneMove() end })
    add(g, "cancel", { type = "execute", name = L["Cancel"], disabled = function() return not ns.Toast.move end,
        func = function() ns.Toast.CancelMove() end })
    add(g, "toastReset", { type = "execute", name = L["Reset position"],
        desc = L["Unlock Lock position before resetting the anchor."],
        disabled = function() return profile().toastLocked end, func = function() ns.Toast.ResetPosition() end })
    gap(g, "previewGap")
    add(g, "h_preview", { type = "header", name = L["Preview without changing your settings"] })
    note(g, "previewHelp", grey(L["Samples do not change settings. The tooltip uses a random material with sample skills and counts. Hold Shift for details."]))
    add(g, "preview", { type = "execute", name = L["Preview loot toast"], func = function() ns.Toast.Demo(1) end })
    add(g, "previewTooltip", { type = "execute", name = L["Preview item tooltip"], func = function() ns.Tooltip.Preview() end })
    add(g, "previewTint", { type = "execute", name = L["Preview icon tint"], func = function() ns.Adapter.ShowTintSample(profile()) end })
    return g
end

---- Materials ------------------------------------------------------------------------------------

-- The client's own (localized) name when it has the item cached, else the English name from the data.
local function itemName(catalog, id)
    local name = ns.Adapter and ns.Adapter.ItemName and ns.Adapter.ItemName(id)
    name = name or (catalog and catalog.itemNames and catalog.itemNames[id])
    return name or L["Item %d"]:format(id)
end

-- Session-only filters; keep metadata outside AceConfig option tables.
local searches = {}

-- The "Clear search" button next to Close in the standalone settings window, shown while searching.
function Options.UpdateFooter()
    local dialog = LibStub("AceConfigDialog-3.0")
    local widget = dialog.OpenFrames and dialog.OpenFrames[APP]
    local active = searches.all ~= nil and searches.all ~= ""
    if ns.Adapter.FooterButton then
        ns.Adapter.FooterButton(widget, L["Clear search"], function() Options.ClearSearch() end, active)
    end
end

function Options.NotifyChange()
    LibStub("AceConfigRegistry-3.0"):NotifyChange(APP)
    if Options.UpdateFooter then pcall(Options.UpdateFooter) end
end

local function clearSearch() searches.all = ""; Options.NotifyChange() end
local function searching() return searches.all ~= nil and searches.all ~= "" end
Options.ClearSearch = clearSearch


local function matches(catalog, id, query)
    query = (query or ""):lower()
    if query == "" then return true end
    local english = catalog and catalog.itemNames and catalog.itemNames[id]
    return itemName(catalog, id):lower():find(query, 1, true) ~= nil
        or (english ~= nil and english:lower():find(query, 1, true) ~= nil)
end

function Options.WowheadLink(id)
    return ("https://www.wowhead.com/classic/item=%d"):format(id)
end

function Options.WowheadSpellLink(id)
    return ("https://www.wowhead.com/classic/spell=%d"):format(id)
end

-- The recipes of a profession that use a material, highest skill first (at most three).
-- The recipes of a profession that use a material, highest skill first: spell IDs, the total, the
-- quantity per craft and the skill each is learned at. limit: at most that many (nil: all).
function Options.RecipesUsing(catalog, profession, id, limit)
    local found = {}
    for spell, rec in pairs(catalog and catalog.recipes or {}) do
        if rec.p == profession then
            for i = 1, #rec.r, 2 do
                if rec.r[i] == id then found[#found + 1] = { spell = spell, learn = rec.learn, qty = rec.r[i + 1] } end
            end
        end
    end
    table.sort(found, function(a, b)
        if a.learn ~= b.learn then return a.learn > b.learn end
        return a.spell < b.spell
    end)
    local out, qty, learn = {}, {}, {}
    for i = 1, math.min(#found, limit or #found) do
        out[i], qty[i], learn[i] = found[i].spell, found[i].qty, found[i].learn
    end
    return out, #found, qty, learn
end

local function skillFor(profession)
    local ctx = ns.Context and ns.Context.Get()
    return ctx and ctx.skills and ctx.skills[profession] or nil
end

-- The description of one material: the same wording as the Shift tooltip, one line per row.
function Options.MaterialText(category, profession, id)
    local ctx = ns.Context.Get()
    local catalog, routes = ctx.catalog, ctx.routes
    local result
    if category == "endgame" then
        local e = catalog and catalog.endgame and catalog.endgame[id] and catalog.endgame[id][profession]
        if not e then return " " end
        result = { endgame = { { profession = profession, reason = e[1], source = e[2], via = e[3] ~= 0 and e[3] or nil } } }
    else
        local skill = skillFor(profession)
        local extra = ctx.extra and ctx.extra(profession, id) or nil
        local need = ns.Leveling.Need(routes, profession, id, skill, extra)
        if not need then return L["Your skill is already past every step that uses this material."] end
        result = { leveling = { { profession = profession, need = need } } }
    end
    local lines = {}
    for _, row in ipairs(ns.Wording.Details(result, { catalog = catalog, routes = routes, itemID = id })) do
        lines[#lines + 1] = row.text
    end
    return table.concat(lines, "\n")
end

-- Material page layout (Codex proposal 1): headed sections that each answer one question, grey
-- secondary text, a blank line between sections, and one full-width button per link.
local MUTED = "|cffaaaaaa%s|r"

local function muted(textValue) return MUTED:format(textValue) end
-- Recipes, guides and intermediate notes: #999999, one step quieter than help text.
local function noted(textValue) return ("|cff999999%s|r"):format(textValue) end

local function spacer(group, key)
    add(group, key, { type = "description", width = "full", fontSize = "small", name = " " })
end

local function line(group, key, name, size, hidden)
    add(group, key, { type = "description", width = "full", fontSize = size or "medium", name = neutral(name), hidden = hidden })
end

local function hiddenSpacer(group, key, hidden)
    add(group, key, { type = "description", width = "full", fontSize = "small", name = " ", hidden = hidden })
end

local function copyButton(group, key, name, url)
    add(group, key, { type = "execute", width = 1.5, name = name,
        desc = L["Opens a box with the link selected. Press Ctrl+C to copy it."],
        func = function() ns.Adapter.ShowCopyBox(L["KeepThat - Wowhead link"], url) end })
end

-- What the material is for, in one line ("Alchemy: Flasks for raids", "Blacksmithing: used to make ...").
local function purposeOnly(profession, id)
    local catalog = ns.Context.Get().catalog
    local e = catalog and catalog.endgame and catalog.endgame[id] and catalog.endgame[id][profession]
    if not e then return "" end
    local entry = { profession = profession, reason = e[1], via = e[3] ~= 0 and e[3] or nil }
    return ns.Wording.Purpose(entry, catalog, function(i) return itemName(catalog, i) end)
end

local function purposeLine(profession, id)
    local catalog = ns.Context.Get().catalog
    local e = catalog and catalog.endgame and catalog.endgame[id] and catalog.endgame[id][profession]
    if not e then return " " end
    local entry = { profession = profession, reason = e[1], via = e[3] ~= 0 and e[3] or nil }
    local purpose = ns.Wording.Purpose(entry, catalog, function(i) return itemName(catalog, i) end)
    return L["%s: %s"]:format(ns.Wording.Display(profession), purpose)
end

-- The leveling need for this profession, or nil when every step is behind the player.
local function needFor(profession, id)
    local ctx = ns.Context.Get()
    local extra = ctx.extra and ctx.extra(profession, id) or nil
    return ns.Leveling.Need(ctx.routes, profession, id, skillFor(profession), extra)
end

-- Every character's stock of the item (realm and faction), from the recorder. nil when unknown.
local function stockTotals(id)
    local R = ns.StockRecorder
    if not (R and R.Total) then return nil end
    local total, complete, rows = R.Total(id)
    if total == nil then return nil end
    return total, complete, rows or {}
end

local function ageText(seconds)
    if not (seconds and ns.Stock and ns.Stock.Age) then return nil end
    local unit, n = ns.Stock.Age(seconds)
    if unit == "minute" then return n == 1 and L["(1 minute ago)"] or L["(%d minutes ago)"]:format(n) end
    if unit == "hour" then return n == 1 and L["(1 hour ago)"] or L["(%d hours ago)"]:format(n) end
    if unit == "day" then return n == 1 and L["(1 day ago)"] or L["(%d days ago)"]:format(n) end
    return nil
end

local function holderParts(row)
    local parts = {}
    if (row.bags or 0) > 0 then parts[#parts + 1] = L["%d in bags"]:format(row.bags) end
    if (row.bank or 0) > 0 then parts[#parts + 1] = L["%d in the bank"]:format(row.bank) end
    if (row.mail or 0) > 0 then parts[#parts + 1] = L["%d in the mailbox"]:format(row.mail) end
    return table.concat(parts, L[", "])
end

local function stockLine(id)
    local total, complete, rows = stockTotals(id)
    if not total then
        local count = ns.Adapter.ItemCount and ns.Adapter.ItemCount(id)
        if count then return L["%d in bags"]:format(count) end
        return L["Your stock is not known yet."]
    end
    if total == 0 then return complete and L["None on any of your characters."] or L["None counted yet."] end
    local here = 0
    for _, row in ipairs(rows) do if row.self then here = here + (row.count or 0) end end
    if here == total then return L["%d owned, all on this character"]:format(total) end
    if here == 0 then return L["%d owned, all on your other characters"]:format(total) end
    return L["%d owned - %d on this character, %d on your other characters"]:format(total, here, total - here)
end

-- One line per holding character; the whole block is a function so the row count is never frozen.
local function stockRows(id)
    local _, _, rows = stockTotals(id)
    local out = {}
    for _, row in ipairs(rows or {}) do
        local label = row.self and L["This character"] or row.name
        local text = "  " .. L["%s: %s"]:format(label, holderParts(row))
        local age = not row.self and ageText(row.age) or nil
        if age then text = text .. " " .. noted(age) end
        out[#out + 1] = text
    end
    return table.concat(out, "\n")
end

-- "Still to get" from the count range and the realm-and-faction total; nil until the total is complete.
local function toGetLine(need, id)
    if not need or not need.low then return nil end
    local total, complete = stockTotals(id)
    if not total or not complete then return nil end
    local low, high = math.max(0, need.low - total), math.max(0, need.high - total)
    if high == 0 then return L["You have enough."] end
    if low == high then return L["Still to get: %d"]:format(high) end
    return L["Still to get: %d-%d"]:format(low, high)
end

local function levelingLines(profession, id)
    local need = needFor(profession, id)
    if not need then return L["Your skill is already past every step that uses this material."], nil, nil, nil end
    local usedFor = L["%s, skill %d-%d"]:format(ns.Wording.Display(profession), need.from, need.to)
    local count = ns.Wording.Count(need)
    local howMany = count and L["Needed for remaining %s steps: %s"]:format(ns.Wording.Display(profession), count)
        or L["No count in the guides for these steps."]
    -- The share that goes into an intermediate the route also needs (Runecloth into Bolt of Runecloth).
    local catalog, routes = ns.Context.Get().catalog, ns.Context.Get().routes
    local mats = routes and routes.materials and routes.materials[profession] or {}
    local best
    for via, n in pairs(need.via or {}) do
        if mats[via] and n > 0 and (not best or n > best.n) then best = { via = via, n = n } end
    end
    local also = best and L["Includes %d for %s"]:format(best.n, itemName(catalog, best.via)) or nil
    local guides = need.sources and #need.sources > 0 and L["Guides: %s"]:format(table.concat(need.sources, L[", "])) or nil
    return usedFor, howMany, also, guides
end

-- For an endgame page: what each leveling route still needs of this item, one line per profession.
local function levelingAlso(id, except)
    local ctx = ns.Context.Get()
    local out = {}
    for _, p in ipairs(ns.Leveling.Professions(ctx.routes, id)) do
      if p ~= except then
        local extra = ctx.extra and ctx.extra(p, id) or nil
        local need = ns.Leveling.Need(ctx.routes, p, id, skillFor(p), extra)
        local count = need and ns.Wording.Count(need)
        if count then out[#out + 1] = L["%s: %s still needed"]:format(ns.Wording.Display(p), count) end
      end
    end
    return out
end

-- A small square in a category's color (the same as the icon tint), drawn as an inline texture.
local function swatch(category)
    local c = (profile().colors or {})[category] or { r = 1, g = 1, b = 1 }
    local function b255(v) return math.floor((v or 1) * 255 + 0.5) end
    return ("|TInterface\\Buttons\\WHITE8X8:8:8:0:0:8:8:0:8:0:8:%d:%d:%d|t"):format(b255(c.r), b255(c.g), b255(c.b))
end
Options.Swatch = swatch

-- "Endgame" / "Leveling" with only the word in its category color.
local function categoryWord(category)
    local c = (profile().colors or {})[category]
    local word = category == "endgame" and L["Endgame"] or L["Leveling"]
    return ns.Wording.Paint(ns.Wording.Hex(c), word)
end

-- The item's name in its quality color, as the game shows item names; neutral when not known yet.
local function qualityName(id, name)
    local hex = ns.Adapter.ItemQualityHex and ns.Adapter.ItemQualityHex(id)
    if hex then return ("|c%s%s|r"):format(hex, name) end
    return neutral(name)
end

-- One page per material and profession, whether it is endgame, leveling or both (flags).
local function materialNode(profession, id, flags, name, order)
    local g = { type = "group", name = name, order = order, args = {} }
    local catalog = ns.Context.Get().catalog

    add(g, "title", { type = "description", fontSize = "large", width = "full",
        name = function() return qualityName(id, itemName(catalog, id)) end,
        image = function() return ns.Adapter.ItemIcon and ns.Adapter.ItemIcon(id) or 134400 end,
        imageWidth = 32, imageHeight = 32 })
    line(g, "context", muted(L["Materials / %s — uses, required amounts and your stock."]:format(ns.Wording.Display(profession))), "small")
    spacer(g, "s1")
    line(g, "keepHelp", muted(L["These choices apply to every profession. Turn on the category in Home to show marks."]), "small")
    for _, category in ipairs({ "endgame", "leveling" }) do
        if flags[category] then
            add(g, "keep_" .. category, {
                type = "toggle", width = "full",
                name = category == "endgame" and L["Keep for endgame"] or L["Keep for leveling"],
                get = function() return not profile().disabled[category][id] end,
                set = function(_, value) profile().disabled[category][id] = (not value) or nil; changed() end,
            })
            line(g, "keepOff_" .. category, muted(category == "endgame"
                and L["Endgame marks are turned off on the Home page."]
                or L["Leveling marks are turned off on the Home page."]), "small",
                function() return profile()[category] end)
        end
    end

    spacer(g, "s2")

    local recipes, _, qty, learn = Options.RecipesUsing(catalog, profession, id)
    local function recipeName(spell) return catalog.spellNames and catalog.spellNames[spell] or tostring(spell) end

    -- Used for: one line per category, only the category word in its color.
    add(g, "h_used", { type = "header", name = L["Used for"] })
    if flags.endgame then
        line(g, "usedEndgame", function()
            return categoryWord("endgame") .. neutral(L[": %s — %s"]:format(ns.Wording.Display(profession), purposeOnly(profession, id)))
        end)
    end
    if flags.leveling then
        line(g, "usedLeveling", function()
            if not needFor(profession, id) then
                return categoryWord("leveling") .. neutral(L[": %s — your skill is past every step that uses this material."]:format(ns.Wording.Display(profession)))
            end
            return categoryWord("leveling") .. neutral(L[": %s"]:format((levelingLines(profession, id))))
        end)
        local function passed() return needFor(profession, id) == nil end
        hiddenSpacer(g, "s3", passed)
        -- Nothing left to count once the player is past every step: the Used for line says so.
        add(g, "h_many", { type = "header", name = L["How many"], hidden = passed })
        line(g, "many", function() return select(2, levelingLines(profession, id)) or " " end, "medium", passed)
        line(g, "toGet", function() return toGetLine(needFor(profession, id), id) or " " end, "medium",
            function() return passed() or toGetLine(needFor(profession, id), id) == nil end)
        line(g, "also", function() return noted(select(3, levelingLines(profession, id)) or "") end, "small",
            function() return select(3, levelingLines(profession, id)) == nil end)
        line(g, "guides", function() return noted(select(4, levelingLines(profession, id)) or "") end, "small",
            function() return select(4, levelingLines(profession, id)) == nil end)
    end

    -- Every recipe of this profession that uses the item: the name neutral, the details grey.
    spacer(g, "s3r")
    add(g, "h_recipes", { type = "header", name = L["Recipes that use it"] })
    if #recipes == 0 then
        line(g, "norecipe", muted(L["No recipes for this profession are listed in KeepThat's data."]))
    else
        local rows = {}
        for i, spell in ipairs(recipes) do
            rows[i] = L["%s %s"]:format(Options.Neutral(recipeName(spell)),
                noted(L["— %d per craft, skill %d"]:format(qty[i], learn[i])))
        end
        add(g, "recipes", { type = "description", width = "full", fontSize = "medium", name = table.concat(rows, "\n") })
    end

    -- Leveling in other professions (this profession's need is under How many).
    local function others()
        local out = {}
        for _, row in ipairs(levelingAlso(id, profession)) do out[#out + 1] = row end
        return out
    end
    local function none() return #others() == 0 end
    hiddenSpacer(g, "s5", none)
    add(g, "h_alsoLeveling", { type = "header", name = L["For leveling in other professions"], hidden = none })
    line(g, "alsoLeveling", function() return table.concat(others(), "\n") end, "medium", none)

    spacer(g, "s6")
    add(g, "h_stock", { type = "header", name = L["Your stock"] })
    line(g, "stock", function() return stockLine(id) end)
    line(g, "stockRows", function() return stockRows(id) end, "medium", function() return stockRows(id) == "" end)
    spacer(g, "s4")

    add(g, "h_links", { type = "header", name = L["Wowhead link"] })
    line(g, "linkHelp", muted(L["Opens a box with the item link selected. Press Ctrl+C to copy it."]), "small")
    copyButton(g, "link", L["Copy Wowhead link"], Options.WowheadLink(id))
    return g
end

local function sortedMaterials(entries, catalog)
    table.sort(entries, function(a, b)
        local na, nb = itemName(catalog, a):lower(), itemName(catalog, b):lower()
        if na ~= nb then return na < nb end
        return a < b
    end)
    return entries
end

-- Which categories the list shows: the ones checked on Home, or both when neither is (so materials
-- can still be looked up). Second value: true when nothing is being marked.
local function shownCategories()
    local p = profile()
    if not p.endgame and not p.leveling then return { endgame = true, leveling = true }, true end
    return { endgame = p.endgame and true or false, leveling = p.leveling and true or false }, false
end

local function visible(flags)
    local shown = shownCategories()
    return (flags.endgame and shown.endgame) or (flags.leveling and shown.leveling) or false
end

local function professionNode(profession, items, catalog, order)
    local g = { type = "group", name = ns.Wording.Display(profession), order = order, childGroups = "tree", args = {} }
    local ids, count = {}, { endgame = 0, leveling = 0 }
    for id, flags in pairs(items) do
        ids[#ids + 1] = id
        if flags.endgame then count.endgame = count.endgame + 1 end
        if flags.leveling then count.leveling = count.leveling + 1 end
    end
    local function shown(id) return visible(items[id]) and matches(catalog, id, searches.all) end
    g.hidden = function()
        for _, id in ipairs(ids) do if shown(id) then return false end end
        return true
    end
    g.args.title = { type = "description", fontSize = "large", width = "full", order = 0.1,
        name = neutral(ns.Wording.Display(profession)) }
    g.args.context = { type = "description", fontSize = "medium", width = "full", order = 0.12,
        name = neutral(L["Review %s materials. Select an item for uses, counts and stock. Export a shopping list below."]:format(ns.Wording.Display(profession))) }
    g.args.count = { type = "description", fontSize = "small", width = "full", order = 0.2,
        name = function()
            local total, hits = 0, 0
            for _, id in ipairs(ids) do
                if visible(items[id]) then
                    total = total + 1
                    if matches(catalog, id, searches.all) then hits = hits + 1 end
                end
            end
            if searching() then return grey(L["%d of %d materials match your search."]:format(hits, total)) end
            return grey(L["%d materials"]:format(total))
        end }
    -- The search follows you into the profession pages: say so, and let it be cleared from here.
    g.args.searchBanner = { type = "description", fontSize = "small", width = "full", order = 0.25,
        name = function() return neutral(L['Showing materials matching "%s".']:format(searches.all or "")) end,
        hidden = function() return not searching() end }
    g.args.clearSearch = { type = "execute", width = 1.5, order = 0.26, name = L["Clear search"],
        hidden = function() return not searching() end, func = clearSearch }
    g.args.gap = { type = "description", fontSize = "small", width = "full", order = 0.4, name = " " }
    -- The leveling cost estimate (spec auctionator-export), above the Shopping list section, only with its
    -- setting on and something to price. A blank line after it keeps it apart from the section header.
    local function estimateLines()
        local A = ns.AuctionatorExport
        return A and A.EstimateLines and A.EstimateLines(profession) or nil
    end
    local function noEstimate() return count.leveling == 0 or estimateLines() == nil end
    g.args.exportEstimate = { type = "description", fontSize = "small", width = "full", order = 0.42,
        hidden = noEstimate,
        name = function() return neutral(table.concat(estimateLines() or {}, " ")) end }
    g.args.exportEstimateGap = { type = "description", fontSize = "small", width = "full", order = 0.45,
        name = " ", hidden = noEstimate }
    -- Auctionator shopping lists for this profession, one per category (spec auctionator-export).
    local function exportState()
        local A = ns.AuctionatorExport
        if not A then return false, L["Auctionator is needed."] end
        return A.Available()
    end
    g.args.h_shop = { type = "header", order = 0.5, name = L["Shopping list"] }
    local function exportButton(category, order2)
        return { type = "execute", order = order2, width = 1.5,
            name = category == "endgame" and L["Export endgame list"] or L["Export leveling list"],
            hidden = function() return count[category] == 0 end,
            disabled = function() return not (ns.AuctionatorExport and ns.AuctionatorExport.Available()) end,
            func = function()
                local ok, detail = ns.AuctionatorExport.Export(profession, category)
                if ns.addon and ns.addon.Print then
                    if ok then ns.addon:Print(L["Shopping list created with %d searches."]:format(tonumber(detail) or 0))
                    else ns.addon:Print(tostring(detail)) end
                end
            end }
    end
    g.args.exportEndgame = exportButton("endgame", 0.6)
    g.args.exportLeveling = exportButton("leveling", 0.61)
    g.args.exportHelp = { type = "description", fontSize = "small", width = "full", order = 0.7,
        name = function()
            local ok, why = exportState()
            return grey(ok and L["Creates or replaces the category's KeepThat shopping list in Auctionator."] or tostring(why))
        end }
    for i, id in ipairs(sortedMaterials(ids, catalog)) do
        local flags = items[id]
        local base = itemName(catalog, id)
        local node = materialNode(profession, id, flags, base, i)
        -- In the tree: a swatch per category (the tint colors), then the neutral name.
        node.name = function()
            local marks = (flags.endgame and swatch("endgame") or "") .. (flags.leveling and swatch("leveling") or "")
            return L["%s %s"]:format(marks, neutral(itemName(catalog, id)))
        end
        node.hidden = function() return not shown(id) end
        g.args["i" .. id] = node
    end
    return g
end

-- profession -> { endgame = { itemID... }, leveling = { itemID... } } (lists per category)
local function materialsByProfession(catalog, routes)
    local out = {}
    local function bucket(p, cat)
        out[p] = out[p] or { endgame = {}, leveling = {} }
        return out[p][cat]
    end
    for id, byProfession in pairs(catalog and catalog.endgame or {}) do
        for p in pairs(byProfession) do local b = bucket(p, "endgame"); b[#b + 1] = id end
    end
    local seen = {}
    local function addLeveling(p, id)
        local key = p .. ":" .. id
        if seen[key] then return end
        seen[key] = true
        local b = bucket(p, "leveling"); b[#b + 1] = id
    end
    for p, mats in pairs(routes and routes.materials or {}) do
        for id in pairs(mats) do addLeveling(p, id) end
    end
    -- Materials only an extra source (DFL Profession Journal) uses, so they can be reviewed and turned off.
    local PJ = ns.ProfessionJournal
    if ns.Context.extra and PJ and PJ.Items and PJ.PROFESSIONS then
        for _, p in ipairs(PJ.PROFESSIONS) do
            local ok, items = pcall(PJ.Items, p)
            for _, id in ipairs(ok and items or {}) do addLeveling(p, id) end
        end
    end
    return out
end

-- profession -> { [itemID] = { endgame = bool, leveling = bool } }: one entry per material.
function Options.MaterialsByProfession(catalog, routes)
    local out = {}
    for p, cats in pairs(materialsByProfession(catalog, routes)) do
        out[p] = {}
        for _, category in ipairs({ "endgame", "leveling" }) do
            for _, id in ipairs(cats[category]) do
                out[p][id] = out[p][id] or { endgame = false, leveling = false }
                out[p][id][category] = true
            end
        end
    end
    return out
end

-- One result per tree path (profession and material).
function Options.Find(query)
    local ctx = ns.Context.Get()
    local found = {}
    for profession, items in pairs(Options.MaterialsByProfession(ctx.catalog, ctx.routes)) do
        for id in pairs(items) do
            if matches(ctx.catalog, id, query) then
                found[#found + 1] = { name = itemName(ctx.catalog, id), itemID = id, profession = profession,
                    categoryName = L["Materials"], professionName = ns.Wording.Display(profession),
                    visible = visible(items[id]), flags = items[id] }
            end
        end
    end
    table.sort(found, function(a, b)
        if a.name:lower() ~= b.name:lower() then return a.name:lower() < b.name:lower() end
        if a.profession ~= b.profession then return a.profession < b.profession end
        return a.itemID < b.itemID
    end)
    return found
end

-- /kt find with several matches: Materials filtered to the query, with only the professions that
-- have a visible match expanded (in the tree's open-node table, see CollapseMaterials).
function Options.OpenSearch(query, found)
    searches.all = query or ""
    Options.NotifyChange()
    local dialog = LibStub("AceConfigDialog-3.0")
    Options.CollapseMaterials(dialog)
    local app = dialog.Status and dialog.Status[APP]
    local tree = type(app) == "table" and type(app.status) == "table" and app.status.groups
    if type(tree) == "table" then
        tree.groups = type(tree.groups) == "table" and tree.groups or {}
        for _, r in ipairs(found or {}) do
            if r.visible ~= false and r.profession then tree.groups["materials\001" .. r.profession] = true end
        end
    end
    dialog:Open(APP)
    dialog:SelectGroup(APP, "materials")
    pcall(Options.UpdateFooter)
end

function Options.OpenMaterial(result)
    searches.all = ""
    Options.NotifyChange()
    local dialog = LibStub("AceConfigDialog-3.0")
    Options.CollapseMaterials(dialog)
    dialog:Open(APP)
    dialog:SelectGroup(APP, "materials", result.profession, "i" .. result.itemID)
    pcall(Options.UpdateFooter)
end

-- One page per category (Endgame, Leveling), then profession, then material: three levels deep.
-- One Materials page: profession, then material, following the Home checkboxes.
function Options.Materials(order)
    local g = page(L["Materials"], order)
    g.childGroups = "tree"
    add(g, "title", { type = "header", name = L["Materials"] })
    text(g, "about", L["Select a profession, then an item. Review its uses, recipes, required amounts and your stock."])
    note(g, "help", grey(L["Choose a profession, then a material. The list follows your selections on Home."]))
    note(g, "legend", function() return grey(L["%s Endgame   %s Leveling"]:format(swatch("endgame"), swatch("leveling"))) end)
    note(g, "none", grey(L["Both categories are turned off on Home. All materials are shown, but none are marked."]),
        function() return not select(2, shownCategories()) end)
    gap(g, "gSearch")
    add(g, "search", { type = "input", width = "full", name = L["Search materials"],
        get = function() return searches.all or "" end,
        set = function(_, value) searches.all = value; Options.NotifyChange() end })
    note(g, "searchHelp", grey(L["Enter part of an item name and press Enter."]))
    add(g, "clearSearch", { type = "execute", width = 1.5, name = L["Clear search"],
        hidden = function() return not searching() end, func = clearSearch })
    text(g, "noMatches", function() return L['No materials match "%s".']:format(searches.all or "") end,
        function()
            if not searches.all or searches.all == "" then return true end
            local ctx = ns.Context.Get()
            for _, items in pairs(Options.MaterialsByProfession(ctx.catalog, ctx.routes)) do
                for id, flags in pairs(items) do
                    if visible(flags) and matches(ctx.catalog, id, searches.all) then return true end
                end
            end
            return false
        end)
    local ctx = ns.Context.Get()
    local byProfession = Options.MaterialsByProfession(ctx.catalog, ctx.routes)
    local names = {}
    for p in pairs(byProfession) do names[#names + 1] = p end
    table.sort(names, function(a, b) return ns.Wording.Display(a) < ns.Wording.Display(b) end)
    for i, p in ipairs(names) do
        g.args[p] = professionNode(p, byProfession[p], ctx.catalog, i + 10)
    end
    return g
end

---- Integrations ---------------------------------------------------------------------------------

Options.INTEGRATIONS = {
    { key = "baganator", name = "Baganator" },
    { key = "bagnon", name = "Bagnon" },
    { key = "ellesmereui", name = "EllesmereUI Bags" },
    { key = "auctionator", name = "Auctionator" },
    { key = "professionjournal", name = "DFL Profession Journal" },
}

-- ns.Integrations.Status(key) is written by the integrations; it may be missing, and its answer is
-- read defensively: { detected = bool, working = bool, reason = string }.
function Options.StatusText(key)
    if ns.client == "era" then return L["Not available on Classic Era."] end
    local fn = ns.Integrations and ns.Integrations.Status
    local ok, s = false, nil
    if type(fn) == "function" then ok, s = pcall(fn, key) end
    if not ok or type(s) ~= "table" then return L["Status not known yet."] end
    if not s.detected then return L["Not detected."] end
    if s.working then return L["Detected and working."] end
    local reason = s.reason or ""
    if reason == "off" then return L["Detected, turned off here."] end
    if reason == "not started" then return L["Detected, starts when its setting is on."] end
    if reason == "not on Classic Era" then return L["Not available on Classic Era."] end
    local why = reason:match("^failed: (.+)$")
    if why then return L["Stopped after an error: %s"]:format(why) end
    return L["Detected but not working."]
end

-- Status line under each addon: grey, short, amber only for a failure (the reason is in /kt log).
function Options.StatusLine(key)
    local status = Options.StatusText(key)
    local fn = ns.Integrations and ns.Integrations.Status
    local ok, st = false, nil
    if type(fn) == "function" then ok, st = pcall(fn, key) end
    if ok and type(st) == "table" and type(st.reason) == "string" and st.reason:find("^failed: ") then
        return ("|cffd9a066%s|r"):format(L["Stopped after an error. See /kt log."])
    end
    return grey(status)
end

function Options.Integrations(order)
    local g = page(L["Integrations"], order)
    introduction(g, L["Connect your other addons"], L["Select optional addon support. Each row shows its function and status."])
    if ns.client == "era" then
        text(g, "era", L["Integrations are not yet available on Classic Era."])
    else
        note(g, "optionalHelp", grey(L["A selected checkbox permits support. Read the status to see if the addon is available."]))
    end
    gap(g, "g0")
    for i, row in ipairs(Options.INTEGRATIONS) do
        local key = row.key
        add(g, "use_" .. key, {
            type = "toggle", width = "full", name = row.name,
            disabled = function() return ns.client == "era" end,
            get = function() return profile().integrations[key] end,
            set = function(_, value) profile().integrations[key] = value and true or false; changed() end,
        })
        local descriptions = {
            baganator = L["Tints bag and bank icons. Turn on Icon tint and select locations in Home."],
            bagnon = L["Tints bag and bank icons. Turn on Icon tint and select locations in Home."],
            ellesmereui = L["Tints item icons. Turn on Icon tint and select locations in Home."],
            auctionator = L["Exports shopping lists from Materials. Export replaces the category's KeepThat list."],
            professionjournal = L["Adds profession routes to leveling counts. Counts use your current skill."],
        }
        note(g, "help_" .. key, grey(descriptions[key]))
        if ns.client ~= "era" then
            add(g, "status_" .. key, { type = "description", fontSize = "small", width = "full",
                name = function() return Options.StatusLine(key) end })
        end
        if key == "auctionator" then
            -- Spec settings, "Estimate leveling cost setting": off by default; one setting for the page and the tooltip.
            -- It sits in an inline box under the Auctionator row so it reads as part of that integration.
            local function reason()
                local A = ns.AuctionatorExport
                if not (A and A.EstimateReason) then return L["Auctionator is needed."] end
                return A.EstimateReason()
            end
            local box = { type = "group", inline = true, name = L["Auctionator options"], args = {} }
            add(g, "options_auctionator", box)
            add(box, "estimateLevelingCost", {
                type = "toggle", width = "full", name = L["Estimate leveling cost"],
                disabled = function() return reason() ~= nil end,
                get = function() return profile().estimateLevelingCost == true end,
                set = function(_, value) profile().estimateLevelingCost = value and true or false; changed() end,
            })
            add(box, "help_estimate", { type = "description", fontSize = "small", width = "full",
                hidden = function() return reason() ~= nil end,
                name = function()
                    return grey(L["The profession page shows the estimated cost of the leveling list."] .. " "
                        .. L["Hold Shift over a material to see the estimated cost of the amount you still need."])
                end })
            add(box, "why_estimate", { type = "description", fontSize = "small", width = "full",
                hidden = function() return reason() == nil end,
                name = function() return grey(reason() or "") end })
        end
        if i < #Options.INTEGRATIONS then gap(g, "g" .. i) end
    end
    return g
end

---- Advanced -------------------------------------------------------------------------------------

local function db() return ns.addon and ns.addon.db end

function Options.CharacterProfileOn()
    local d = db()
    return d ~= nil and d:GetCurrentProfile() ~= "Default"
end

function Options.SetCharacterProfile(on)
    local d = db()
    if not d then return end
    if ns.Toast then ns.Toast.CancelMove() end
    d:SetProfile(on and d.keys.char or "Default")
    changed()
end

function Options.Advanced(order)
    local g = page(L["Advanced"], order)
    introduction(g, L["Settings scope and troubleshooting"], L["Set the settings scope or collect a problem report. Set features in Home."])
    add(g, "h_profile", { type = "header", name = L["Profile"] })
    note(g, "profileContext", grey(L["Select separate settings to use this character’s profile. Clear the checkbox to use shared settings. Both profiles keep their saved values."]))
    add(g, "charProfile", {
        type = "toggle", width = "full", name = L["Use separate settings for this character"],
        confirm = L["Switch settings scope? Existing settings in both scopes are retained; no settings are copied."],
        get = Options.CharacterProfileOn,
        set = function(_, value) Options.SetCharacterProfile(value) end,
    })
    gap(g, "g1")
    add(g, "h_debug", { type = "header", name = L["Debug"] })
    add(g, "debug", {
        type = "toggle", width = "full", name = L["Record debug information"],
        get = function() return profile().debug end,
        set = function(_, value) profile().debug = value and true or false; changed() end,
    })
    note(g, "debugHelp", grey(L["Turn recording on. Repeat the problem. Open the report. Press Ctrl+A, then Ctrl+C to copy it. Turn recording off."]))
    note(g, "clearHelp", grey(L["Use /kt log clear to clear diagnostics after confirmation. Settings and material choices stay the same."]))
    add(g, "report", {
        type = "execute", width = 1.5, name = L["Show debug report"],
        func = function() ns.Export.Show(L["KeepThat debug report"], ns.Log.Report()) end,
    })
    return g
end

---- About ----------------------------------------------------------------------------------------

-- About: the name large, the version small and grey, one sentence, then the commands (neutral) with grey
-- explanations, each on its own line.
function Options.About(order)
    local g = page(L["About"], order)
    add(g, "title", { type = "description", fontSize = "large", width = "full", name = L["KeepThat"] })
    note(g, "version", grey(L["Version %s"]:format(tostring(ns.version))))
    gap(g, "g0")
    text(g, "what", L["Marks the materials worth keeping, so you do not sell what you will need later."])
    gap(g, "g1")
    add(g, "h_cmds", { type = "header", name = L["Commands"] })
    local commands = {
        { "kt", "/kt", L["Open these settings."] },
        { "find", "/kt find <name>", L["Find a material and open its settings when there is one match."] },
        { "demo", "/kt demo", L["Show sample toasts, a random item tooltip and an isolated tint."] },
        { "debug", "/kt debug on", L["Record diagnostics while you repeat a problem."] },
        { "log", "/kt log", L["Copy the debug report to share it."] },
    }
    for _, c in ipairs(commands) do
        text(g, "cmd_" .. c[1], L["|cffdddddd%s|r  %s"]:format(c[2], grey(c[3])))
    end
    gap(g, "helpGap")
    add(g, "h_help", { type = "header", name = L["Find the right command"] })
    text(g, "helpAppearance", L["/kt help appearance — visual settings, valid values and focused previews."])
    text(g, "helpDomain", L["/kt help domain — finding materials and opening feature pages."])
    text(g, "helpDiagnostics", L["/kt help diagnostics — recording, copying and clearing diagnostic reports."])
    note(g, "commandHelp", grey(L["Use /kt status to check settings. Use /kt get <key> to read a value. Use /kt set <key> <value> to change it."]))
    return g
end

---- Registration ---------------------------------------------------------------------------------

function Options.Build()
    return {
        type = "group", name = APP, childGroups = "tree",
        args = {
            home = Options.Home(1), materials = Options.Materials(2),
            integrations = Options.Integrations(3), appearance = Options.Appearance(4), advanced = Options.Advanced(5), about = Options.About(6),
        },
    }
end

-- AceConfigDialog keeps which tree nodes are open for the whole session, so a profession opened
-- once stays open. The tree's status table is Status[app].status.groups, and its expanded nodes are
-- that table's .groups (AceConfigDialog:SelectGroup). Close every profession under Materials so the
-- list starts collapsed; Materials itself and other pages keep their state.
function Options.CollapseMaterials(dialog)
    local app = dialog and dialog.Status and dialog.Status[APP]
    local tree = type(app) == "table" and type(app.status) == "table" and app.status.groups
    local open = type(tree) == "table" and tree.groups
    if type(open) ~= "table" then return end
    for key in pairs(open) do
        if type(key) == "string" and key:find("^materials\001") then open[key] = nil end
    end
end

-- The Materials entry in the game's Settings window: a launcher, not the tree. Leaving the full
-- tree there froze the game for over a minute on WoW Forever; the KeepThat window does not.
Options.LAUNCHER = APP .. " Materials"

function Options.MaterialsLauncher()
    local g = page(L["Materials"], 1)
    introduction(g, L["Materials"], L["Review materials in the KeepThat window. It has room for the full list, search and shopping lists."])
    add(g, "open", { type = "execute", width = 1.5, name = L["Open KeepThat"],
        func = function()
            if ns.Adapter and ns.Adapter.CloseGameSettings then ns.Adapter.CloseGameSettings() end
            Options.Open("materials")
        end })
    return g
end

function Options.Open(pageName)
    local dialog = LibStub("AceConfigDialog-3.0")
    Options.CollapseMaterials(dialog)
    dialog:Open(APP)
    dialog:SelectGroup(APP, pageName or "home")
    pcall(Options.UpdateFooter)
end

-- The options table: built once, and again when an extra source starts or is turned on or off on the
-- Integrations page (its materials join or leave the tree, without a reload).
local built, builtWith
function Options.Tree()
    local PJ = ns.ProfessionJournal
    local with = ns.Context.extra and PJ and PJ.On and PJ.On() and ns.Context.extra or false
    if not built or with ~= builtWith then
        built, builtWith = Options.Build(), with
    end
    return built
end

ns.Start(function(addon)
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(APP, Options.Tree)
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(Options.LAUNCHER, Options.MaterialsLauncher())
    local dialog = LibStub("AceConfigDialog-3.0")
    dialog:SetDefaultSize(APP, 600, 460)
    dialog:AddToBlizOptions(APP, APP, nil, "home")
    for _, sub in ipairs({ { "materials", L["Materials"] },
        { "integrations", L["Integrations"] },
        { "appearance", L["Appearance"] }, { "advanced", L["Advanced"] }, { "about", L["About"] } }) do
        if sub[1] == "materials" then
            dialog:AddToBlizOptions(Options.LAUNCHER, sub[2], APP)
        else
            dialog:AddToBlizOptions(APP, sub[2], APP, sub[1])
        end
    end
    -- A profile switch (or reset) changes every setting at once.
    local function refresh()
        if ns.Toast then ns.Toast.CancelMove() end
        ns.Presentation.Migrate(addon.db.profile)
        ns.Presentation.Refresh()
    end
    for _, event in ipairs({ "OnProfileChanged", "OnProfileCopied", "OnProfileReset" }) do
        addon.db.RegisterCallback(Options, event, refresh)
    end
end)
