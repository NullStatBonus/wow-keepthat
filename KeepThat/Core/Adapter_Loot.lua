-- Game reads for the loot toast (UI/Toast.lua). Every read is guarded; nil when missing.
local _, ns = ...
local A = ns.Adapter

-- Lua patterns for the player's own loot messages, from the client's localized format strings.
-- Returns { { pattern = ..., multiple = bool }, ... }, the "x%d" form first so it wins.
-- Captures: item link, then (for the multiple form) the count.
function A.LootPatterns()
    local out = {}
    local function build(path, multiple)
        local fmt = A.Resolve(path)
        if type(fmt) ~= "string" or fmt == "" then return end
        local p = fmt:gsub("[%^%$%(%)%.%[%]%*%+%-%?%%]", "%%%0")
        p = p:gsub("%%%%%d%%%$s", "(.+)"):gsub("%%%%%d%%%$d", "(%%d+)")
        p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
        out[#out + 1] = { pattern = "^" .. p .. "$", multiple = multiple }
    end
    build("LOOT_ITEM_SELF_MULTIPLE", true)
    build("LOOT_ITEM_SELF", false)
    return out
end

function A.ItemIcon(itemID)
    if not itemID then return nil end
    return A.Call("C_Item.GetItemIconByID", itemID) or A.Call("GetItemIcon", itemID)
end

A.ItemName = A.ItemName or function(itemID)
    if not itemID then return nil end
    return (A.Call("C_Item.GetItemNameByID", itemID)) or (A.Call("GetItemInfo", itemID))
end

function A.Now()
    return A.Call("GetTime")
end
