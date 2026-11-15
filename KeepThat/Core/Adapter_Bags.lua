-- Container reads and the hooks the bag overlay needs (spec icon-mask; design D7). Game calls only,
-- each guarded and in pcall; missing functions give nil (or an empty list of hooks). Paths are chosen
-- by checking what exists, never by the client's name. Tests replace ns.Adapter.env with a fake.
local _, ns = ...
local A = ns.Adapter

-- The item ID in a bag slot, or nil.
function A.ContainerItemID(bag, slot)
    if type(bag) ~= "number" or type(slot) ~= "number" then return nil end
    local id = A.Call("C_Container.GetContainerItemID", bag, slot)
    if id == nil then id = A.Call("GetContainerItemID", bag, slot) end
    if id == nil then
        local info = A.Call("C_Container.GetContainerItemInfo", bag, slot)
        id = type(info) == "table" and info.itemID or nil
    end
    return type(id) == "number" and id or nil
end

local function number(name)
    local v = A.Resolve(name)
    return type(v) == "number" and v or nil
end

-- "bags" or "bank" for a bag ID. The player's own bags are the backpack up to the last equipped bag
-- (the reagent bag counts, where the client has one) and the keyring; everything else (the bank's main
-- slots, its bags and tabs, the reagent bank) is the bank. Unknown bag gives nil.
function A.BagLocation(bag)
    if type(bag) ~= "number" then return nil end
    local last = number("NUM_TOTAL_EQUIPPED_BAG_SLOTS") or number("NUM_BAG_SLOTS") or 4
    local first = number("BACKPACK_CONTAINER") or 0
    if bag >= first and bag <= last then return "bags" end
    if bag == (number("KEYRING_CONTAINER") or -2) then return "bags" end
    return "bank"
end

-- hooksecurefunc on a global function name; true when installed.
function A.HookGlobal(name, fn)
    local hook = A.Resolve("hooksecurefunc")
    if type(hook) ~= "function" or not A.Has(name) then return false end
    return (pcall(hook, name, fn))
end

-- hooksecurefunc on a table's (or frame's) method; true when installed.
function A.HookMethod(target, method, fn)
    local hook = A.Resolve("hooksecurefunc")
    if type(hook) ~= "function" or type(target) ~= "table" then return false end
    local ok, f = pcall(function() return target[method] end)
    if not ok or type(f) ~= "function" then return false end
    return (pcall(hook, target, method, fn))
end

local function call(obj, method, ...)
    local ok, f = pcall(function() return obj[method] end)
    if not ok or type(f) ~= "function" then return nil end
    local res = { pcall(f, obj, ...) }
    if not res[1] then return nil end
    return unpack(res, 2, table.maxn(res))
end
A.CallMethod = call

-- Every item button of a modern container frame (ContainerFrameMixin): EnumerateValidItems when it
-- exists, else the frame's Items list.
local function frameButtons(frame)
    local out = {}
    local ok, iter, state, start = pcall(function() return frame:EnumerateValidItems() end)
    if ok and type(iter) == "function" then
        pcall(function()
            for _, button in iter, state, start do out[#out + 1] = button end
        end)
        if #out > 0 then return out end
    end
    local items = type(frame) == "table" and rawget(frame, "Items")
    if type(items) == "table" then
        for _, button in ipairs(items) do out[#out + 1] = button end
    end
    return out
end

-- Containers frames that exist: the combined bag frame and ContainerFrame1..N.
local function containerFrames()
    local list = {}
    local combined = A.Resolve("ContainerFrameCombinedBags")
    if type(combined) == "table" then list[#list + 1] = combined end
    local n = number("NUM_CONTAINER_FRAMES") or 13
    for i = 1, n do
        local f = A.Resolve("ContainerFrame" .. i)
        if type(f) == "table" then list[#list + 1] = f end
    end
    return list
end

-- True when the client has any of the default bag frames or update functions the hooks use.
function A.HasBlizzardBags()
    return A.Has("ContainerFrame_Update") or A.Has("ContainerFrame_UpdateItems") or #containerFrames() > 0
end

-- Hooks the default bags and bank so paint(button, bag, slot) runs whenever a slot is drawn. Each path
-- is installed on its own, so a missing bank path never stops the bag hook. Returns the names of the
-- paths installed.
function A.HookBlizzardBags(paint)
    local installed = {}
    local function add(name, ok) if ok then installed[#installed + 1] = name end end

    -- Classic-style: one global update for each container frame; buttons are <frame>Item1..size.
    local function classicFrame(frame)
        local bag = call(frame, "GetID")
        local name = call(frame, "GetName")
        local size = type(frame) == "table" and rawget(frame, "size")
        if type(name) ~= "string" or type(size) ~= "number" then return end
        for i = 1, size do
            local button = A.Resolve(name .. "Item" .. i)
            if type(button) == "table" then paint(button, bag, call(button, "GetID")) end
        end
    end
    if A.Has("ContainerFrame_Update") then
        add("ContainerFrame_Update", A.HookGlobal("ContainerFrame_Update", classicFrame))
    elseif A.Has("ContainerFrame_UpdateItems") then
        add("ContainerFrame_UpdateItems", A.HookGlobal("ContainerFrame_UpdateItems", classicFrame))
    else
        -- Modern: ContainerFrameMixin:UpdateItems on each frame; buttons know their bag.
        local function modernFrame(frame)
            for _, button in ipairs(frameButtons(frame)) do
                local bag = call(button, "GetBagID")
                if bag == nil then bag = call(frame, "GetID") end
                paint(button, bag, call(button, "GetID"))
            end
        end
        local any = false
        for _, frame in ipairs(containerFrames()) do
            if A.HookMethod(frame, "UpdateItems", modernFrame) then any = true end
        end
        add("ContainerFrame:UpdateItems", any)
    end

    -- Bank main slots, classic-style: the button's parent carries the bank container ID.
    if A.Has("BankFrameItemButton_Update") then
        add("BankFrameItemButton_Update", A.HookGlobal("BankFrameItemButton_Update", function(button)
            if type(button) ~= "table" or rawget(button, "isBag") then return end
            local parent = call(button, "GetParent")
            local bag = parent and call(parent, "GetID")
            -- Only a negative ID is a bank container (-1 bank, -3 reagent bank); a parent with ID 0
            -- would otherwise read the backpack.
            if type(bag) ~= "number" or bag >= 0 then bag = number("BANK_CONTAINER") or -1 end
            paint(button, bag, call(button, "GetID"))
        end))
    end
    -- Bank panel (modern clients): a mixin whose Refresh draws one slot. Hooking the mixin table reaches
    -- the buttons the bank creates after login, which is when it creates them (unverified on Forever).
    local panel = A.Resolve("BankPanelItemButtonMixin")
    if type(panel) == "table" then
        add("BankPanelItemButtonMixin:Refresh", A.HookMethod(panel, "Refresh", function(button)
            if type(button) ~= "table" then return end
            local bag = call(button, "GetBankTabID") or rawget(button, "bankTabID")
            local slot = call(button, "GetContainerSlotID") or rawget(button, "containerSlotID")
            paint(button, bag, slot)
        end))
    end
    return installed
end
