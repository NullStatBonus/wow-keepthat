-- Loads every file of each TOC in order with stubbed Ace libraries and a bare game environment, then
-- runs startup, the way the game would. Catches load-order and wiring mistakes the unit tests miss.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq
local stubs = require("stubs")

local function deepcopy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = deepcopy(v) end
    return o
end

local function fakeFrame()
    local f = {}
    setmetatable(f, { __index = function() return function() return f end end })
    return f
end

-- The real AceConfigRegistry, so the options table is validated the way the game validates it
-- (an unknown field there leaves every settings panel empty and /kt opening nothing).
local function realRegistry()
    local saved = _G.LibStub
    _G.LibStub = nil
    dofile("KeepThat/Libs/LibStub/LibStub.lua")
    dofile("KeepThat/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
    dofile("KeepThat/Libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua")
    local reg = _G.LibStub("AceConfigRegistry-3.0")
    _G.LibStub = saved
    return reg
end
local REGISTRY = realRegistry()

local function fakeAce()
    local events, commands = {}, {}
    local libs = {}
    libs["AceAddon-3.0"] = { NewAddon = function(_, name)
        local a = { name = name, events = events, commands = commands }
        function a:RegisterEvent(e, fn) events[e] = fn end
        function a:UnregisterEvent(e) events[e] = nil end
        function a:RegisterChatCommand(c, fn) commands[c] = fn end
        function a:Print() end
        function a:SecureHook() end
        function a:HookScript() end
        return a
    end }
    libs["AceDB-3.0"] = { New = function(_, _, defaults)
        local db = { profile = deepcopy(defaults.profile), global = deepcopy(defaults.global), keys = { char = "Me - Realm" } }
        function db:RegisterCallback() end
        function db:GetCurrentProfile() return "Default" end
        function db:SetProfile() end
        return db
    end }
    libs["AceConfig-3.0"] = { RegisterOptionsTable = function() end }
    libs["AceConfigRegistry-3.0"] = REGISTRY
    libs["AceConfigDialog-3.0"] = { AddToBlizOptions = function() return {} end, Open = function() end, SelectGroup = function() end, SetDefaultSize = function() end }
    libs["AceGUI-3.0"] = { Create = function() return fakeFrame() end }
    return function(name) return libs[name] or error("unexpected library " .. tostring(name)) end, events, commands
end

local function plain(t) return (tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

local function tocFiles(name)
    local files = {}
    for line in io.lines("KeepThat/KeepThat_" .. name .. ".toc") do
        line = line:gsub("\r", "")
        if line ~= "" and not line:find("^#") and line:find("%.lua$") then files[#files + 1] = (line:gsub("\\", "/")) end
    end
    return files
end

for toc, client in pairs({ Vanilla = "era", Camelot = "forever" }) do
    local LibStub, events, commands = fakeAce()
    stubs.install({
        LibStub = LibStub,
        CreateFrame = function() return fakeFrame() end,
        UIParent = fakeFrame(),
        hooksecurefunc = function() end,
        C_Timer = { After = function() end },
        GetTime = function() return 0 end,
        LOOT_ITEM_SELF = "You receive loot: %s.",
        LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d.",
        -- Forever's tooltip hook, or Era's OnTooltipSetItem script.
        TooltipDataProcessor = client == "forever" and { AddTooltipPostCall = function() end } or nil,
        Enum = client == "forever" and { TooltipDataType = { Item = 0 } } or nil,
        GameTooltip = client == "era" and { HasScript = function() return true end, HookScript = function() end } or nil,
    })
    local ns = {}
    for _, file in ipairs(tocFiles(toc)) do
        local chunk = assert(loadfile("KeepThat/" .. file))
        local ok, err = pcall(chunk, "KeepThat", ns)
        eq(ok, true, toc .. ": " .. file .. " loads (" .. tostring(err) .. ")")
    end
    eq(ns.client, client, toc .. ": client")
    local addon = ns.addon
    local ok, err = pcall(addon.OnInitialize, addon)
    eq(ok, true, toc .. ": OnInitialize runs (" .. tostring(err) .. ")")
    if addon.OnEnable then
        ok, err = pcall(addon.OnEnable, addon)
        eq(ok, true, toc .. ": OnEnable runs (" .. tostring(err) .. ")")
    end
    eq(type(commands.kt), "function", toc .. ": /kt is registered")
    for _, cmd in ipairs({ "demo", "test", "test toast", "test tooltip", "test copy" }) do
        local okCmd, errCmd = pcall(commands.kt, cmd)
        eq(okCmd, true, toc .. ": /kt " .. cmd .. " runs (" .. tostring(errCmd) .. ")")
    end
    ns.Context.demo = nil   -- the sample tooltip's classification would last 15 seconds
    local okValid, errValid = pcall(REGISTRY.GetOptionsTable(REGISTRY, "KeepThat"), "dialog", "AceConfigDialog-3.0")
    eq(okValid, true, toc .. ": the options table passes AceConfig validation (" .. tostring(errValid) .. ")")
    eq(ns.Log.failures[1] == nil, true, toc .. ": nothing failed at startup (" .. tostring(ns.Log.failures[1] and ns.Log.failures[1].message) .. ")")
    local line = ns.Wording.Line(ns.Context.Classify(12360))
    eq(line, "Endgame: Blacksmithing, Engineering", toc .. ": Arcanite Bar classifies with the loaded data")

    -- /kt demo's sample classification: used for its item until it expires, then the real one returns.
    local sample = { leveling = { { profession = "engineering", need = { low = 1, high = 1, from = 1, to = 2, sources = {} } } } }
    ns.Context.SetDemo(12360, sample, 100, 15)
    eq(ns.Context.Classify(12360, 110), sample, toc .. ": the sample while it lasts")
    eq(ns.Context.DemoActive(12360, 110), true, toc .. ": active before it expires")
    eq(ns.Context.DemoActive(12360, 116), false, toc .. ": not active after it expires")
    eq(ns.Context.Classify(12360, 116) ~= sample, true, toc .. ": the real classification afterwards")
    eq(ns.Context.demo, nil, toc .. ": and the sample is gone")

    -- Materials page: recipe links and the Auctionator export control (Auctionator not installed here).
    local bsEndgame = ns.Options.Materials(1).args.blacksmithing
    local arc = bsEndgame.args.i12360
    local copied
    ns.Adapter.ShowCopyBox = function(_, url) copied = url end
    eq(arc.args.recipeLink1, nil, toc .. ": no recipe buttons")
    eq(plain(arc.args.recipes.name):find("Arcanite Reaper", 1, true) ~= nil, true, toc .. ": recipes listed as text")
    arc.args.link.func()
    eq(copied, "https://www.wowhead.com/classic/item=12360", toc .. ": item button opens the copy box")
    eq(plain(arc.args.title.name()), "Arcanite Bar", toc .. ": the page starts with the item's name")
    eq(arc.args.title.image ~= nil, true, toc .. ": and its icon")
    eq(ns.Options.MaterialText("endgame", "blacksmithing", 12360):find("Source", 1, true), nil, toc .. ": no source line")
    eq(bsEndgame.args.exportEndgame.disabled(), true, toc .. ": export disabled without Auctionator")
    eq(plain(bsEndgame.args.exportHelp.name()), "Auctionator is needed.", toc .. ": and says why")

    -- Review finding 8: a material only Profession Journal uses is reviewable, and its count includes it.
    local savedPJ, savedExtra = ns.ProfessionJournal, ns.Context.extra
    ns.ProfessionJournal = { PROFESSIONS = { "alchemy" }, Items = function() return { 999999 } end }
    ns.Context.extra = function(_, id)
        return id == 999999 and { { name = "DFL Profession Journal", segments = { 1, 300, 7, 7, 0 } } } or nil
    end
    ns.Context.Invalidate()
    local pjNode = ns.Options.Materials(1).args.alchemy.args.i999999
    eq(pjNode ~= nil, true, toc .. ": Profession Journal-only material is in the Materials tree")
    eq(ns.Options.MaterialText("leveling", "alchemy", 999999):find("7 needed", 1, true) ~= nil, true,
        toc .. ": its review count includes Profession Journal")
    ns.ProfessionJournal, ns.Context.extra = savedPJ, savedExtra
    ns.Context.Invalidate()
    stubs.restore()
end

H.done()
