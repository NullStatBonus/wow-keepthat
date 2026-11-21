-- Recipe knowledge from the open profession window (spec recipe-knowledge; design D3, D4b). Classic Era
-- lists learned recipes in the trade skill window (GetTradeSkillInfo) and, for Enchanting, the craft
-- window (GetCraftInfo); their links carry the spell ID ("enchant:<id>"). WoW Forever answers
-- C_TradeSkillUI.GetRecipeInfo(spellID).learned for the open profession. Every read is guarded and in
-- pcall; nil means unknown.
local _, ns = ...
local A = ns.Adapter

-- The client's difficulty words (Era skillType, Forever Enum.TradeskillRelativeDifficulty) in ours.
A.ERA_DIFFICULTY = { optimal = "orange", medium = "yellow", easy = "green", trivial = "gray" }
A.FOREVER_DIFFICULTY = { [0] = "orange", [1] = "yellow", [2] = "green", [3] = "gray" }

local function call(f, ...)
    if type(f) ~= "function" then return false end
    return pcall(f, ...)
end

local function spellFromLink(link)
    local id = type(link) == "string" and link:match("enchant:(%d+)")
    return id and tonumber(id) or nil
end

-- A filter getter that reports "all" (index 0) on, as 1 or true. Missing or failing counts as filtered.
local function allShown(path)
    local ok, v = call(A.Resolve(path), 0)
    return ok and (v == 1 or v == true)
end

local function checked(frameName)
    local f = A.Resolve(frameName)
    if type(f) ~= "table" then return false end
    local ok, v = call(f.GetChecked, f)
    return ok and (v == 1 or v == true)
end

-- Forever: the open profession's catalog recipes, each asked by spell ID, so window filters do not matter.
-- A recipe the client gives no info for is not in this character's list, so it is not learned.
local function foreverRead(catalog)
    local okB, info = call(A.Resolve("C_TradeSkillUI.GetBaseProfessionInfo"))
    if not okB or type(info) ~= "table" then return nil end
    local profession = A.SKILL_LINES[info.professionID]
    if not profession and type(info.professionName) == "string" then profession = A.SkillLineNames()[info.professionName] end
    if not profession then return nil end
    local get = A.Resolve("C_TradeSkillUI.GetRecipeInfo")
    local read = { profession = profession, known = {}, rows = {}, source = "recipe info" }
    for spell, rec in pairs(catalog and catalog.recipes or {}) do
        if rec.p == profession then
            local ok, r = call(get, spell)
            if ok and type(r) == "table" then
                if r.learned then read.known[spell] = true end
                read.rows[#read.rows + 1] = { spell = spell, client = A.FOREVER_DIFFICULTY[r.relativeDifficulty], learned = r.learned and true or false }
            end
        end
    end
    read.complete = #read.rows > 0
    return read
end

-- Era: the rows the window shows. Complete only when no filter, collapsed header or unkeyed row hid any.
local function eraRead(kind)
    local craft = kind == "craft"
    local line = A.Resolve(craft and "GetCraftDisplaySkillLine" or "GetTradeSkillLine")
    local okL, name = call(line)
    local profession = okL and type(name) == "string" and A.SkillLineNames()[name] or nil
    if not profession then return nil end
    local okN, n = call(A.Resolve(craft and "GetNumCrafts" or "GetNumTradeSkills"))
    if not okN or type(n) ~= "number" then return nil end
    local info = A.Resolve(craft and "GetCraftInfo" or "GetTradeSkillInfo")
    local link = A.Resolve(craft and "GetCraftItemLink" or "GetTradeSkillRecipeLink")
    local read = { profession = profession, known = {}, rows = {}, complete = true, source = craft and "craft window" or "trade skill window" }
    if not craft then
        if not allShown("GetTradeSkillSubClassFilter") or not allShown("GetTradeSkillInvSlotFilter")
            or checked("TradeSkillFrameAvailableFilterCheckButton") then
            read.complete, read.filtered = false, true
        end
    end
    for i = 1, n do
        local ok, _, a, b, c, d = call(info, i)
        local skillType, expanded
        if craft then skillType, expanded = b, d   -- name, subSpellName, craftType, numAvailable, isExpanded
        else skillType, expanded = a, c end       -- name, skillType, numAvailable, isExpanded
        if not ok then
            read.complete = false
        elseif skillType == "header" then
            if not expanded then read.complete, read.collapsed = false, true end
        else
            local okK, l = call(link, i)
            local spell = okK and spellFromLink(l) or nil
            if spell then
                read.known[spell] = true
                read.rows[#read.rows + 1] = { spell = spell, client = A.ERA_DIFFICULTY[skillType], learned = true }
            else
                read.complete, read.unkeyed = false, (read.unkeyed or 0) + 1
            end
        end
    end
    if craft and #read.rows == 0 then
        -- The craft window's links carry no spell ID (task 1.3 checks): Enchanting cannot be recorded here,
        -- so the tooltip stops asking to open it for the rest of the session.
        if n > 0 then A.craftUnkeyed = true end
        return nil
    end
    return read
end

-- True while the window shows someone else's recipes (a linked or guild profession, an NPC crafter):
-- those must never be recorded as this character's.
function A.RecipeWindowForeign()
    for _, path in ipairs({ "IsTradeSkillLinked", "C_TradeSkillUI.IsTradeSkillLinked", "C_TradeSkillUI.IsTradeSkillGuild",
        "C_TradeSkillUI.IsNPCCrafting" }) do
        local ok, v = call(A.Resolve(path))
        if ok and v then return true end
    end
    return false
end

-- The window reads that need no C_TradeSkillUI (Classic Era) are not yet verified in game, so they stay off
-- in this version (spec recipe-knowledge, "Learned status on WoW Forever only in this version"). Tests and
-- a future verified release turn them on here.
A.WINDOW_ROWS_VERIFIED = false

local function recipeInfoPath()
    return A.Has("C_TradeSkillUI.GetBaseProfessionInfo") and A.Has("C_TradeSkillUI.GetRecipeInfo")
end

-- The open window's read: { profession, complete, known = { [spellID] = true }, rows, source }, or nil.
-- kind is "trade" or "craft" (the event that fired).
function A.RecipeWindow(kind, catalog)
    if A.RecipeWindowForeign() then return nil end
    if kind ~= "craft" and recipeInfoPath() then return foreverRead(catalog) end
    if not A.WINDOW_ROWS_VERIFIED then return nil end
    return eraRead(kind)
end

-- Whether this client has a way to record a profession's recipes, so the tooltip hint can be cleared.
function A.RecipeRecordable(profession)
    if recipeInfoPath() then return true end
    if not A.WINDOW_ROWS_VERIFIED then return false end
    if profession == "enchanting" and A.Has("GetCraftItemLink") and A.Has("GetNumCrafts") then return not A.craftUnkeyed end
    return A.Has("GetTradeSkillRecipeLink") and A.Has("GetNumTradeSkills")
end

-- The client's spell-known check for a recipe (for the probe only until it is proven, design D3).
function A.IsPlayerSpell(spellID)
    local ok, v = call(A.Resolve("IsPlayerSpell"), spellID)
    if not ok or v == nil then return nil end
    return v and true or false
end
