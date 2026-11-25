-- Merchant window reads for the icon tint (spec icon-mask, merchant location). Both clients use the
-- MerchantItem<i>ItemButton buttons; the item comes from GetMerchantItemID or the item link, and the
-- buyback tab from GetBuybackItemLink. Everything guarded; nil when missing.
local _, ns = ...
local A = ns.Adapter

local function number(name, default)
    local v = A.Resolve(name)
    return type(v) == "number" and v or default
end

local function idFromLink(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- The merchant's item buttons on screen and the item each shows: { { button, itemID }, ... }.
-- buyback: true when the frame shows the buyback tab. A third value is the page number (nil on buyback).
function A.MerchantSlots()
    local out = {}
    local frame = A.Resolve("MerchantFrame")
    if type(frame) ~= "table" then return out, false end
    local ok, tab = pcall(function() return frame.selectedTab end)
    local buyback = ok and tab == 2
    if buyback then
        for i = 1, number("BUYBACK_ITEMS_PER_PAGE", 12) do
            local button = A.Resolve("MerchantItem" .. i .. "ItemButton")
            if type(button) == "table" then
                out[#out + 1] = { button, idFromLink(A.Call("GetBuybackItemLink", i)) }
            end
        end
        return out, true
    end
    local okPage, page = pcall(function() return frame.page end)
    page = okPage and type(page) == "number" and page or 1
    local per = number("MERCHANT_ITEMS_PER_PAGE", 10)
    for i = 1, per do
        local button = A.Resolve("MerchantItem" .. i .. "ItemButton")
        if type(button) == "table" then
            local index = (page - 1) * per + i
            local id = A.Call("GetMerchantItemID", index) or idFromLink(A.Call("GetMerchantItemLink", index))
            out[#out + 1] = { button, id }
        end
    end
    return out, false, page
end

-- True when a texture of ours is on screen; nil when it cannot say.
function A.TextureShown(tex)
    if type(tex) ~= "table" then return nil end
    local ok, shown = pcall(function() return tex:IsShown() end)
    if not ok then return nil end
    return shown and true or false
end

-- Installs fn() after each merchant and buyback redraw; returns the names hooked.
function A.HookMerchant(fn)
    local hooked = {}
    for _, name in ipairs({ "MerchantFrame_UpdateMerchantInfo", "MerchantFrame_UpdateBuybackInfo" }) do
        if A.HookGlobal(name, fn) then hooked[#hooked + 1] = name end
    end
    return hooked
end
