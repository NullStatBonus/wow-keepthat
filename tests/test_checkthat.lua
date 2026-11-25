-- Integrations/CheckThat.lua with a fake CheckThat and a fake AceEvent (spec checkthat-integration):
-- missing, old and idle CheckThat, a Report that raises, entries registered at PLAYER_LOGIN on a module of
-- their own, the version entry, the other entries and their errors, Classic Era, no Integrations page row.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local function copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = copy(v) end
    return c
end
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function has(s, needle, msg) eq(s:find(needle, 1, true) ~= nil, true, msg .. " (" .. needle .. ")") end
local function pack(...) return { n = select("#", ...), ... } end

-- AceEvent as CallbackHandler does it: one handler per event per object; a second RegisterEvent replaces it.
local handlers = {}
local function eventObject(o)
    o = o or {}
    function o:RegisterEvent(event, fn)
        handlers[event] = handlers[event] or {}
        handlers[event][self] = fn
    end
    return o
end
local function fire(event, ...)
    local list = {}
    for _, fn in pairs(handlers[event] or {}) do list[#list + 1] = fn end
    for _, fn in ipairs(list) do fn(event, ...) end
end

-- A fake CheckThat: Report records facts (false when closed), Entry stores functions.
local function fakeCheckThat(opts)
    opts = opts or {}
    local ct = { API_VERSION = 2, facts = {}, entries = {}, calls = 0, open = opts.open ~= false }
    if not opts.noReport then
        function ct.Report(addon, key, value)
            ct.calls = ct.calls + 1
            if opts.reportError then error("report broke") end
            if not ct.open then return false end
            ct.facts[#ct.facts + 1] = ("[%s] %s=%s"):format(addon, key, tostring(value))
            return true
        end
    end
    if not opts.noEntry then
        function ct.Entry(addon, name, fn)
            if opts.entryError then error("entry broke") end
            ct.entries[name] = fn
            return true
        end
    end
    return ct
end

local function build(opts)
    opts = opts or {}
    handlers = {}
    local ns = { client = opts.client or "forever", version = opts.version or "0.7.0" }
    local starters = {}
    ns.Start = function(fn) starters[#starters + 1] = fn end
    H.locale(ns)
    H.load("Core/Defaults.lua", ns)
    local profile = copy(ns.defaults.profile)
    profile.debug = true
    local modules = {}
    ns.addon = eventObject({ db = { profile = profile, global = { log = {} } }, modules = modules })
    function ns.addon:NewModule(name)
        assert(not modules[name], "module " .. name .. " already exists")
        modules[name] = eventObject({ name = name })
        return modules[name]
    end
    ns.Listen = function(target, event, fn) return (pcall(target.RegisterEvent, target, event, fn)) end
    H.load("Core/Adapter.lua", ns)
    local env = { IsLoggedIn = function() return opts.loggedIn or false end }
    ns.Adapter.env = env
    ns.env = env
    H.load("Debug/Log.lua", ns)
    H.load("Integrations/Gate.lua", ns)
    -- Another integration that is detected only at login: the Gate's own PLAYER_LOGIN start must still run.
    ns.lateReady = false
    ns.lateStarted = false
    ns.Integrations.Register("late", { anyClient = true, detect = function() return ns.lateReady end,
        start = function() ns.lateStarted = true end })
    H.load("Integrations/CheckThat.lua", ns)
    ns.run = function() for _, fn in ipairs(starters) do fn(ns.addon) end end
    return ns
end

local CT_KEY = "checkthat"

---- CheckThat not installed -----------------------------------------------------------------------
local ns = build()
ns.run()
fire("ADDON_LOADED", "Other")
fire("PLAYER_LOGIN")
eq(ns.Integrations.Status(CT_KEY).reason, "not detected", "no CheckThat: not detected")
ns.CheckThat.Report("toast.seq", 1)   -- no error
eq(#ns.Log.failures, 0, "no CheckThat: no failure")
has(ns.Log.Report(), "checkthat: detected=false, working=false, reason=not detected", "the report lists checkthat")

---- Registration waits for PLAYER_LOGIN, on a module of its own -------------------------------------
ns = build()
ns.run()
local ct = fakeCheckThat()
ns.env.CheckThat = ct
fire("ADDON_LOADED", "CheckThat")
eq(ns.Integrations.Active(CT_KEY), true, "CheckThat detected at its ADDON_LOADED and working")
eq(next(ct.entries), nil, "no entry registered before PLAYER_LOGIN")
eq(ns.addon.modules.CheckThat ~= nil, true, "the integration listens on its own module")
ns.lateReady = true
ns.env.IsLoggedIn = function() return true end
fire("PLAYER_LOGIN")
eq(ns.lateStarted, true, "the Gate's own PLAYER_LOGIN start still runs after the CheckThat integration started")
local n = 0
for _ in pairs(ct.entries) do n = n + 1 end
eq(n, #ns.CheckThat.ORDER, "every entry registered at PLAYER_LOGIN")
eq(ct.entries.version ~= nil and ct.entries.classify ~= nil and ct.entries.stockCounted ~= nil, true, "named entries")
has(table.concat(ns.addon.db.global.log, "\n"), "[checkthat] entries registered: " .. #ns.CheckThat.ORDER, "the count is logged")
has(table.concat(ns.addon.db.global.log, "\n"), "[checkthat] started", "the Gate logs the start")
fire("PLAYER_LOGIN")
eq(ns.CheckThat.registered, #ns.CheckThat.ORDER, "a second login event registers nothing new")

-- Report: a fact, a declined fact (no run open) is normal.
ns.CheckThat.Report("toast.seq", 3)
eq(ct.facts[1], "[KeepThat] toast.seq=3", "a fact reaches CheckThat")
ct.open = false
eq(ns.CheckThat.Report("toast.seq", 4), nil, "Report returns nothing")
eq(ns.Integrations.Active(CT_KEY), true, "a declined fact keeps the integration on")
eq(#ns.Log.failures, 0, "a declined fact records no failure")

---- Started during PLAYER_LOGIN itself (CheckThat detected only then): registers at once --------------
ns = build({ loggedIn = true })
ns.run()
ct = fakeCheckThat()
ns.env.CheckThat = ct
fire("PLAYER_LOGIN")
eq(ct.entries.version ~= nil, true, "started after login: entries registered at once")

---- CheckThat without Entry (an older version) ---------------------------------------------------
ns = build({ loggedIn = true })
ct = fakeCheckThat({ noEntry = true })
ns.env.CheckThat = ct
ns.run()
eq(ns.Integrations.Active(CT_KEY), true, "old CheckThat: working")
eq(ns.CheckThat.registered, nil, "old CheckThat: no entry registered")
ns.CheckThat.Report("export.items", 2)
eq(ct.facts[1], "[KeepThat] export.items=2", "old CheckThat: facts still reported")
eq(#ns.Log.failures, 0, "old CheckThat: no failure")

-- Without Report either: nothing is called and nothing fails.
ns = build({ loggedIn = true })
ns.env.CheckThat = fakeCheckThat({ noEntry = true, noReport = true })
ns.run()
ns.CheckThat.Report("export.items", 2)
eq(#ns.Log.failures, 0, "CheckThat with neither call: no failure")

---- Report raises: off for the session, named in the report, no later calls ------------------------
ns = build({ loggedIn = true })
ct = fakeCheckThat({ reportError = true })
ns.env.CheckThat = ct
ns.run()
ns.CheckThat.Report("toast.seq", 1)
eq(ct.calls, 1, "Report was called once")
eq(ns.Integrations.Active(CT_KEY), false, "a raising Report turns the integration off")
ns.CheckThat.Report("toast.seq", 2)
eq(ct.calls, 1, "no CheckThat call after the failure")
eq(#ns.Log.failures, 1, "one failure recorded")
local report = ns.Log.Report()
has(report, "[checkthat] FAILED: Report:", "the report names the failure")
has(report, "checkthat: detected=true, working=false, reason=failed: Report:", "the report lists the state")

-- Entry raises: off for the session, nothing raised.
ns = build({ loggedIn = true })
ns.env.CheckThat = fakeCheckThat({ entryError = true })
ns.run()
eq(ns.Integrations.Active(CT_KEY), false, "a raising Entry turns the integration off")
has(ns.Log.Report(), "[checkthat] FAILED: Entry:", "the report names the Entry failure")

---- Classic Era ------------------------------------------------------------------------------------
ns = build({ client = "era", loggedIn = true })
ct = fakeCheckThat()
ns.env.CheckThat = ct
ns.run()
eq(ns.Integrations.Status(CT_KEY).working, true, "Classic Era: working")
eq(ct.entries.version ~= nil, true, "Classic Era: entries registered")

---- No Integrations page row, no setting -----------------------------------------------------------
local src = assert(io.open("KeepThat/Options/Options.lua")):read("*a")
local block = src:match("Options%.INTEGRATIONS = (%b{})")
eq(block ~= nil, true, "the Integrations page table is found")
eq(block:find("checkthat", 1, true), nil, "no CheckThat row on the Integrations page")
eq(build().defaults.profile.integrations.checkthat, nil, "no CheckThat toggle")

---- Version entry ----------------------------------------------------------------------------------
local V = ns.CheckThat.VersionNumber
eq(V("0.6.1"), 601, "0.6.1")
eq(V("0.7.0"), 700, "0.7.0")
eq(V("1.2.3"), 10203, "1.2.3")
eq(V("unknown"), nil, "unknown")
eq(V("0.7"), nil, "0.7 does not parse")
local function version(v)
    local b = build({ version = v, loggedIn = true })
    local fake = fakeCheckThat()
    b.env.CheckThat = fake
    b.run()
    return pack(fake.entries.version())
end
local r = version("0.7.0")
eq(r.n, 1, "0.7.0: one result"); eq(r[1], 700, "0.7.0: 700")
eq(version("0.6.1")[1], 601, "0.6.1 through the entry")
eq(version("unknown").n, 0, "unknown version: nothing, not 0")
eq(version("0.7").n, 0, "unparsable version: nothing")

---- The other entries --------------------------------------------------------------------------------
local ARC, LINEN = 12360, 2589
ns = build({ loggedIn = true })
ct = fakeCheckThat()
ns.env.CheckThat = ct
H.load("Model/Leveling.lua", ns)
H.load("Core/Presentation.lua", ns)
local routes = { guides = { { name = "Guide A" } }, materials = { tailoring = { [LINEN] = { 1, 1, 50, 40, 40, 0 } } } }
ns.Context = {
    Classify = function(id)
        if id == ARC then return { endgame = { { profession = "blacksmithing" } }, leveling = { { profession = "tailoring" } } } end
    end,
    Get = function() return { routes = routes, skills = { tailoring = 10 } } end,
}
ns.AuctionatorExport = {
    Materials = function(p, c) return p == "tailoring" and c == "leveling" and { { itemID = LINEN, quantity = 32 } } or {} end,
    ListName = function() return "KeepThat: Tailoring Leveling" end,
}
ns.StockRecorder = { State = function() return { missing = { { name = "Alt", self = false, bank = true } } } end }
ns.run()
local E = ct.entries
local before = copy(ns.addon.db)
eq(E.classify(ARC), "endgame:blacksmithing;leveling:tailoring", "classify: categories and professions")
eq(pack(E.classify(4)).n, 0, "classify: nothing for an unmarked item")
local want = ns.Leveling.Need(routes, "tailoring", LINEN, 10).high
eq(type(want), "number", "the route gives a count")
eq(E.needed(LINEN, "tailoring"), want, "needed: the count still needed")
eq(pack(E.needed(LINEN, "alchemy")).n, 0, "needed: nothing when unknown")
r = pack(E.exportCount("tailoring", "leveling"))
eq(r[1], 1, "exportCount: item count"); eq(r[2], "KeepThat: Tailoring Leveling", "exportCount: list name")
eq(E.setting("tooltip"), "on", "setting: the /kt get value")
eq(E.setting("appearance.toast.scale"), "100", "setting: a number setting")
eq(pack(E.setting("nope")).n, 0, "setting: nothing for an unknown key")
eq(E.integration("checkthat"), "working", "integration: working")
eq(E.integration("baganator"), "not detected", "integration: the Gate reason")
eq(E.stockCounted(), true, "stockCounted: this character counted (another one missing)")
ns.StockRecorder.State = function() return { missing = { { name = "Me", self = true, mail = true } } } end
eq(E.stockCounted(), false, "stockCounted: this character missing")
ns.StockRecorder.State = function() return nil end
eq(pack(E.stockCounted()).n, 0, "stockCounted: nothing when stock is unknown")
eq(same(before, ns.addon.db), true, "the entries change no saved variable")
for _, name in ipairs(ns.CheckThat.ORDER) do eq(type(E[name]), "function", "registered: " .. name) end

-- An entry that raises: "error: ...", a failure in the report, the integration stays on, nothing raised.
ns.Context.Classify = function() error(string.rep("x", 300)) end
local out = E.classify(ARC)
eq(out:sub(1, 7), "error: ", "a raising entry returns error:")
eq(#out <= 100, true, "the error text is cut to 100 characters")
has(ns.Log.Report(), "[checkthat] FAILED: entry classify:", "the report names the entry")
eq(ns.Integrations.Active(CT_KEY), true, "an entry error keeps the integration on")

H.done()
