-- Game calls for the item tooltip line (design D5): the tooltip hook chosen by capability, the tooltip
-- methods the line needs, and the item, spell, bag count and modifier reads. Everything is guarded and
-- in pcall; a missing function or an error gives nil.
local _, ns = ...
local A = ns.Adapter

-- Calls tooltip:method(...) in pcall; returns ok and the first result (or the error).
local function method(tooltip, name, ...)
    if type(tooltip) ~= "table" then return false, "no tooltip" end
    local ok, f = pcall(function() return tooltip[name] end)
    if not ok or type(f) ~= "function" then return false, "no method " .. name end
    return pcall(f, tooltip, ...)
end

local function itemIDFromLink(link)
    local id = type(link) == "string" and link:match("item:(%d+)")
    return id and tonumber(id) or nil
end

-- The item a tooltip shows, from its GetItem() link; nil when unknown.
function A.TooltipItemID(tooltip)
    local ok, _, link = method(tooltip, "GetItem")
    if not ok then return nil end
    return itemIDFromLink(link)
end

local function forbidden(tooltip)
    local ok, res = method(tooltip, "IsForbidden")
    return ok and res == true
end

-- The tooltips the Classic Era path hooks (those that exist).
A.ITEM_TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" }

-- Calls fn(tooltip, itemID) whenever an item tooltip is filled. Uses TooltipDataProcessor's post-call
-- when the client has it, otherwise OnTooltipSetItem on the item tooltips. Returns the path taken
-- ("postcall" or "settitem"), or nil when neither exists.
function A.HookItemTooltips(fn)
    local addPostCall = A.Resolve("TooltipDataProcessor.AddTooltipPostCall")
    local itemType = A.Resolve("Enum.TooltipDataType.Item")
    if type(addPostCall) == "function" and itemType ~= nil then
        local ok = pcall(addPostCall, itemType, function(tooltip, data)
            if forbidden(tooltip) then return end
            local id = type(data) == "table" and tonumber(data.id) or nil
            id = id or A.TooltipItemID(tooltip)
            if id then fn(tooltip, id) end
        end)
        if ok then return "postcall" end
    end
    local hooked = false
    for _, name in ipairs(A.ITEM_TOOLTIPS) do
        local tooltip = A.Resolve(name)
        local okHas, has = method(tooltip, "HasScript", "OnTooltipSetItem")
        if okHas and has then
            local ok = method(tooltip, "HookScript", "OnTooltipSetItem", function(self)
                local id = A.TooltipItemID(self)
                if id then fn(self, id) end
            end)
            hooked = hooked or ok
        end
    end
    return hooked and "settitem" or nil
end

-- Runs fn(tooltip) when the tooltip is cleared. True when hooked.
function A.OnTooltipCleared(tooltip, fn)
    local okHas, has = method(tooltip, "HasScript", "OnTooltipCleared")
    if not okHas or not has then return nil end
    local ok = method(tooltip, "HookScript", "OnTooltipCleared", fn)
    return ok or nil
end

-- Adds one line (wrapped) and resizes the tooltip. Returns ok, err so the caller can turn itself off.
function A.TooltipAddLine(tooltip, text, r, g, b)
    local ok, err = method(tooltip, "AddLine", text, r, g, b, true)
    if not ok then return false, err end
    return true
end

function A.TooltipShow(tooltip)
    local ok, err = method(tooltip, "Show")
    if not ok then return false, err end
    return true
end

function A.TooltipIsShown(tooltip)
    local ok, shown = method(tooltip, "IsShown")
    if not ok then return nil end
    return shown and true or false
end

-- Redraws a shown tooltip so its hooks run again. Forever has RefreshData; on Classic Era the owner's
-- OnEnter is run again (which keeps bag, merchant and comparison context), else the item link is set again.
function A.RefreshTooltip(tooltip)
    if method(tooltip, "RefreshData") then return true end
    local okOwner, owner = method(tooltip, "GetOwner")
    if okOwner and type(owner) == "table" then
        local okScript, onEnter = method(owner, "GetScript", "OnEnter")
        if okScript and type(onEnter) == "function" and pcall(onEnter, owner) then return true end
    end
    local okItem, _, link = method(tooltip, "GetItem")
    if okItem and type(link) == "string" and method(tooltip, "SetHyperlink", link) then return true end
    return nil
end

-- Bag count of an item (bags only, not the bank); nil when unknown.
-- How many the player carries; includeBank adds what the client knows of the bank (Classic Era learns
-- the bank once it has been opened this session).
function A.ItemCount(itemID, includeBank)
    local n = A.Call(A.Has("C_Item.GetItemCount") and "C_Item.GetItemCount" or "GetItemCount", itemID, includeBank and true or nil)
    return type(n) == "number" and n or nil
end

function A.IsShiftDown()
    if not A.Has("IsShiftKeyDown") then return nil end
    return A.Call("IsShiftKeyDown") and true or false
end

-- The client's (localized) item name; nil when the client does not know it yet.
function A.ItemName(itemID)
    local name = A.Call(A.Has("C_Item.GetItemInfo") and "C_Item.GetItemInfo" or "GetItemInfo", itemID)
    return type(name) == "string" and name ~= "" and name or nil
end

-- The client's (localized) spell name; nil when unknown.
function A.SpellName(spellID)
    local name
    if A.Has("C_Spell.GetSpellName") then
        name = A.Call("C_Spell.GetSpellName", spellID)
    else
        name = A.Call("GetSpellInfo", spellID)
        if type(name) == "table" then name = name.name end
    end
    return type(name) == "string" and name ~= "" and name or nil
end

-- /kt demo: show an item's tooltip at the mouse, as if the player hovered it.
function A.ShowItemTooltip(itemID)
    local tip = A.Resolve("GameTooltip")
    local parent = A.Resolve("UIParent")
    if type(tip) ~= "table" then return false end
    local ok = pcall(function()
        tip:SetOwner(parent, "ANCHOR_CURSOR")
        if tip.SetItemByID then tip:SetItemByID(itemID) else tip:SetHyperlink("item:" .. itemID) end
        tip:Show()
    end)
    return ok
end


-- The item's quality color as "ffRRGGBB" for |c...|r, or nil while the client does not know the item.
function A.ItemQualityHex(itemID)
    local quality = A.Call("C_Item.GetItemQualityByID", itemID)
    if type(quality) ~= "number" then
        quality = select(3, A.Call(A.Has("C_Item.GetItemInfo") and "C_Item.GetItemInfo" or "GetItemInfo", itemID))
    end
    if type(quality) ~= "number" then return nil end
    local getColor = A.Has("C_Item.GetItemQualityColor") and "C_Item.GetItemQualityColor" or "GetItemQualityColor"
    local r, g, b, hex = A.Call(getColor, quality)
    if type(hex) == "string" and #hex == 8 then return hex end
    if type(r) ~= "number" then
        local colors = A.Resolve("ITEM_QUALITY_COLORS")
        local c = type(colors) == "table" and colors[quality]
        if type(c) ~= "table" then return nil end
        r, g, b = c.r, c.g, c.b
    end
    local function b255(v) return math.floor((v or 1) * 255 + 0.5) end
    return ("ff%02x%02x%02x"):format(b255(r), b255(g), b255(b))
end
