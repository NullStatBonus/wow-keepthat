-- DFL Profession Journal as one more leveling source (spec leveling-guidance, "Profession Journal adds
-- to the sources when installed"; design D4; contract in docs/contracts.md).
--
-- Reads its static reviewed route, DFLProfessionJournalNS.GuideData[profession].steps, through its own
-- Leveling.OrderedSteps(steps, API.Faction()), and turns each skill step's materials into segments in
-- the format Model/Leveling.lua takes for extra sources. Nothing is copied into our files or saved
-- variables: the segments live in a session cache that is dropped whenever ns.Context is invalidated.
-- A shape it does not expect gives nil (only the built-in sources are used) and one line in the debug
-- report for that profession.
local _, ns = ...
local L = ns.L

local PJ = { NAME = "DFL Profession Journal" }
ns.ProfessionJournal = PJ

-- KeepThat's profession keys; Profession Journal's base guide keys are the same. Its variants
-- (alchemy_no_herbalism and so on) and gathering-only guides are not used.
PJ.PROFESSIONS = { "alchemy", "blacksmithing", "enchanting", "engineering", "leatherworking", "tailoring",
    "cooking", "firstaid", "mining" }

local cache = {}   -- [profession] = { [itemID] = segments } or false (nothing to add)
local failed = {}  -- [profession] = true once its data failed the shape check (session only)

local function namespace()
    local J = ns.Adapter and ns.Adapter.Resolve("DFLProfessionJournalNS")
    return type(J) == "table" and J or nil
end

local function fail(profession, reason)
    if not failed[profession] then
        failed[profession] = true
        if ns.Log then ns.Log.Failure("professionjournal", tostring(profession) .. ": " .. tostring(reason)) end
    end
    return nil
end

-- True when DFL Profession Journal is loaded. Whether its data can be read is Read's job, so a
-- changed shape is logged rather than looking like a missing addon.
function PJ.Detect()
    return namespace() ~= nil
end

-- Steps in Profession Journal's own order for the player's faction (a copy; GuideData is untouched).
local function ordered(J, steps)
    local order = type(J.Leveling) == "table" and J.Leveling.OrderedSteps
    if type(order) ~= "function" then return steps end
    local faction
    local factionOf = type(J.API) == "table" and J.API.Faction
    if type(factionOf) == "function" then
        local ok, f = pcall(factionOf)
        if ok and type(f) == "string" then faction = f end
    end
    local ok, out = pcall(order, steps, faction)
    if not ok then return nil, "OrderedSteps failed: " .. tostring(out) end
    return out
end

local function isList(t)
    if type(t) ~= "table" then return false end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n == #t
end

-- Segments for one profession: { [itemID] = { from, to, low, high, via, ... } }, or nil when Profession
-- Journal is missing, has no guide for it, or its data has an unexpected shape (then logged once).
-- Skill steps count over their own range; preparation steps (making an intermediate ahead of time)
-- count over the range of the step they are for (forStep). low and high are the step's total for the
-- material; via is the item the step makes (0 when unknown).
function PJ.Read(profession)
    local J = namespace()
    if not J then return nil end
    if type(J.GuideData) ~= "table" then return fail("all professions", "GuideData is not a table") end
    local guide = J.GuideData[profession]
    if guide == nil then return nil end
    if type(guide) ~= "table" or not isList(guide.steps) then return fail(profession, "steps is not a list") end
    local steps, err = ordered(J, guide.steps)
    if not steps then return fail(profession, err) end
    if not isList(steps) then return fail(profession, "ordered steps are not a list") end

    local byNumber = {}
    for i, step in ipairs(steps) do
        if type(step) ~= "table" then return fail(profession, "step " .. i .. " is not a table") end
        if step.number ~= nil then byNumber[step.number] = step end
    end

    local out = {}
    for i, step in ipairs(steps) do
        local mats = step.materials
        if mats ~= nil and not isList(mats) then return fail(profession, "step " .. i .. " materials is not a list") end
        local from, to
        if step.kind == nil or step.kind == "skill" then
            from, to = step.from, step.to
            if type(from) ~= "number" or type(to) ~= "number" then
                return fail(profession, "step " .. i .. " has no numeric from and to")
            end
        elseif step.kind == "preparation" then
            local target = byNumber[step.forStep]
            from, to = step.from, step.to
            if (type(from) ~= "number" or type(to) ~= "number") and type(target) == "table" then
                from, to = target.from, target.to
            end
            if type(from) ~= "number" or type(to) ~= "number" then from, to = nil, nil end
        end
        if from then
            local via = type(step.make) == "table" and type(step.make.itemID) == "number" and step.make.itemID or 0
            for j, m in ipairs(mats or {}) do
                if type(m) ~= "table" or type(m.itemID) ~= "number" then
                    return fail(profession, "step " .. i .. " material " .. j .. " has no itemID")
                end
                if m.total ~= nil and type(m.total) ~= "number" then
                    return fail(profession, "step " .. i .. " material " .. j .. " total is not a number")
                end
                local total = m.total or 0
                local segs = out[m.itemID]
                if not segs then segs = {}; out[m.itemID] = segs end
                segs[#segs + 1] = from
                segs[#segs + 1] = to
                segs[#segs + 1] = total
                segs[#segs + 1] = total
                segs[#segs + 1] = via
            end
        end
    end
    return out
end

-- Cached read for one profession (safe: an error in reading is a logged nil).
local function segmentsFor(profession)
    if failed[profession] then return nil end
    local c = cache[profession]
    if c == nil then
        if not PJ.Detect() then return nil end   -- not loaded (yet): cache nothing, it may load later
        local ok, res = pcall(PJ.Read, profession)
        if not ok then fail(profession, res); res = nil end
        c = res or false
        cache[profession] = c
    end
    return c or nil
end

-- The source list Model/Leveling.lua takes as `extra`, or nil when Profession Journal does not use the item.
-- Turned off on the Integrations page (or failed): add nothing, without a reload.
local function on()
    local I = ns.Integrations
    return not I or not I.Active or I.Active("professionjournal")
end

-- True while the integration is on (the Options tree rebuilds when this changes).
PJ.On = on

function PJ.Extra(profession, itemID)
    if not on() then return nil end
    local all = segmentsFor(profession)
    local segs = all and all[itemID]
    if not segs then return nil end
    return { { name = PJ.NAME, segments = segs } }
end

-- Professions whose Profession Journal route uses itemID.
function PJ.Professions(itemID)
    local out = {}
    if not on() then return out end
    for _, profession in ipairs(PJ.PROFESSIONS) do
        local all = segmentsFor(profession)
        if all and all[itemID] then out[#out + 1] = profession end
    end
    return out
end

-- Item IDs Profession Journal's route for profession uses (the Materials tree, /kt find, the Auctionator
-- export): none while it is turned off. anyToggle: also while turned off (stock records materials
-- whatever the settings mark, so a bank read while it is off keeps them and totals stay right).
-- Stock reads Profession Journal while it is turned off, but not on a client the integration does not
-- run on, nor after it failed this session (Integrations/Gate.lua).
local function usable()
    local I = ns.Integrations
    if not I or not I.Status then return true end
    local why = I.Status("professionjournal").reason
    return why == nil or why == "off" or why == "not started"
end

-- True while stock can read it (loaded, on a client it runs on, not failed); Core/Stock.lua rebuilds its
-- tracked list when this changes, e.g. when it loads late or fails.
function PJ.StockReadable()
    return usable() and PJ.Detect() and true or false
end

function PJ.Items(profession, anyToggle)
    local out = {}
    if anyToggle then
        if not usable() then return out end
    elseif not on() then
        return out
    end
    for itemID in pairs(segmentsFor(profession) or {}) do out[#out + 1] = itemID end
    return out
end

function PJ.Reset()
    cache = {}
end

-- Forget this session's shape failures (tests, or a reload of Profession Journal's data).
function PJ.ClearFailures()
    failed = {}
    cache = {}
end

function PJ.Start()
    PJ.active = true
    if not PJ.listening then
        PJ.listening = true
        ns.Context.OnChange(PJ.Reset)
    end
    ns.Context.extra = PJ.Extra
    ns.Context.extraProfessions = PJ.Professions
    ns.Context.Invalidate()
end

-- Opens the recipe's page in Profession Journal's own window. True when it opened.
function PJ.Open(profession, spellID, name)
    local J = namespace()
    local ui = J and J.UI
    if type(ui) ~= "table" or type(ui.OpenRecipeInJournal) ~= "function" then return false end
    local ok, opened = pcall(ui.OpenRecipeInJournal, ui, profession, spellID, name)
    if not ok then
        if ns.Log then ns.Log.Failure("professionjournal", "OpenRecipeInJournal failed: " .. tostring(opened)) end
        return false
    end
    return opened == true
end

-- Why the integration is not running, for the options page.
function PJ.Available()
    if not PJ.Detect() then return false, L["DFL Profession Journal is not installed."] end
    return true
end

-- Drop the cached reads on every context change from load, not only once started: stock reads them
-- while the integration is off, and Profession Journal may load after the first read.
-- While debugging, record each turn on or off with the materials it lists, so an in-game check reads it
-- from the saved variables (test plan check 9.2).
local lastOn
function PJ.LogToggle()
    local Log = ns.Log
    if not (Log and Log.Enabled and Log.Enabled()) or not PJ.Detect() then return end
    local now = on() and true or false
    if now == lastOn then return end
    lastOn = now
    local parts, total = {}, 0
    for _, profession in ipairs(PJ.PROFESSIONS) do
        local n = #PJ.Items(profession)
        if n > 0 then parts[#parts + 1] = profession .. "=" .. n; total = total + n end
    end
    Log.Record("professionjournal", ("%s: %d materials listed%s"):format(now and "on" or "off", total,
        #parts > 0 and (" (" .. table.concat(parts, " ") .. ")") or ""))
end

if ns.Context and ns.Context.OnChange then
    PJ.listening = true
    ns.Context.OnChange(function() PJ.Reset(); PJ.LogToggle() end)
end

if ns.Integrations and ns.Integrations.Register then
    ns.Integrations.Register("professionjournal", { detect = PJ.Detect, start = PJ.Start })
end
