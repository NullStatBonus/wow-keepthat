-- CheckThat, the in-game test runner (spec checkthat-integration; design D1 to D4; contract in
-- docs/contracts.md). Every CheckThat call lives here, existence-checked and in pcall, so KeepThat works the
-- same with CheckThat missing, old or idle. CheckThat is a test harness only: it is not in OptionalDeps
-- (CheckThat lists KeepThat, so KeepThat loads first), it runs on both clients, and it has no setting.
--
--   ns.CheckThat.Report(key, value)  reports the fact [KeepThat] key=value. Feature modules look ns.CheckThat
--     up at call time (they load first). A false return (no run open, a refused key, the rate limit) is
--     normal; only a raised error turns the integration off for the session.
--   Entries (ns.CheckThat.ORDER) register at PLAYER_LOGIN through CheckThat.Entry. Each is side-effect free
--     and returns scalars of at most 120 characters, never a character name. An error inside one is a
--     failure in the debug report and returns "error: <message>"; it does not turn the integration off.
local _, ns = ...

local KEY = "checkthat"
local CT = { ADDON = "KeepThat", ORDER = {}, entries = {} }
ns.CheckThat = CT

local function api()
    local t = ns.Adapter and ns.Adapter.Resolve and ns.Adapter.Resolve("CheckThat")
    return type(t) == "table" and t or nil
end

local function gate() return ns.Integrations end

function CT.Detect()
    return api() ~= nil
end

function CT.Report(key, value)
    local I = gate()
    if not (I and I.Active and I.Active(KEY)) then return end
    local t = api()
    if not t or type(t.Report) ~= "function" then return end
    local ok, err = pcall(t.Report, CT.ADDON, key, value)
    if not ok then I.Fail(KEY, "Report: " .. tostring(err)) end
end

---- Entries ----------------------------------------------------------------------------------------

-- "0.7.0" is 700: major*10000 + minor*100 + patch, the encoding of CheckThat's own version fact. nil when
-- the version is unknown or does not parse.
function CT.VersionNumber(v)
    if type(v) ~= "string" then return nil end
    local major, minor, patch = v:match("^v?(%d+)%.(%d+)%.(%d+)")
    if not major then return nil end
    return tonumber(major) * 10000 + tonumber(minor) * 100 + tonumber(patch)
end

local function add(name, fn)
    CT.ORDER[#CT.ORDER + 1] = name
    CT.entries[name] = fn
end

local function cut(s) return (tostring(s):sub(1, 120)) end

add("version", function()
    local n = CT.VersionNumber(ns.version)
    if n then return n end
end)

-- "endgame:blacksmithing;leveling:tailoring" for the item under the current settings and skills, or
-- nothing for an unmarked item.
add("classify", function(itemID)
    itemID = tonumber(itemID)
    local result = itemID and ns.Context and ns.Context.Classify(itemID)
    if type(result) ~= "table" then return end
    local parts = {}
    for _, category in ipairs({ "endgame", "leveling" }) do
        for _, e in ipairs(result[category] or {}) do parts[#parts + 1] = category .. ":" .. tostring(e.profession) end
    end
    if #parts > 0 then return cut(table.concat(parts, ";")) end
end)

-- The count still needed for the item in the profession (the high end of the range), or nothing when no
-- route gives a count.
add("needed", function(itemID, profession)
    itemID = tonumber(itemID)
    if not itemID or type(profession) ~= "string" or not (ns.Context and ns.Leveling) then return end
    local ctx = ns.Context.Get()
    local extra = ctx.extra and ctx.extra(profession, itemID) or nil
    local need = ns.Leveling.Need(ctx.routes, profession, itemID, (ctx.skills or {})[profession], extra)
    if need and need.high then return need.high end
end)

-- The materials an export would put in the list, and the list's name. Never writes a list.
add("exportCount", function(profession, category)
    local X = ns.AuctionatorExport
    if not (X and X.Materials and X.ListName) or type(profession) ~= "string" then return end
    return #X.Materials(profession, category), cut(X.ListName(profession, category))
end)

-- The value /kt get prints for a public setting key, or nothing for an unknown key.
add("setting", function(key)
    local P = ns.Presentation
    if type(key) ~= "string" or not (P and P.keys and P.keys[key:lower()]) then return end
    return cut(P.Value(key:lower()))
end)

-- "working", or the Gate's reason ("not detected", "off", "failed: ...").
add("integration", function(key)
    local I = gate()
    if type(key) ~= "string" or not (I and I.Status) then return end
    local s = I.Status(key)
    if type(s) ~= "table" then return end
    if s.working then return "working" end
    return cut(s.reason or "not started")
end)

-- Whether this character's bank and mailbox are both counted; nothing when stock is unknown.
add("stockCounted", function()
    local R = ns.StockRecorder
    local st = R and R.State and R.State()
    if type(st) ~= "table" then return end
    for _, m in ipairs(st.missing or {}) do
        if m.self then return false end
    end
    return true
end)

local function pack(...) return { n = select("#", ...), ... } end

-- fn in pcall; zero results stay zero (CheckThat reports them as "(none)").
function CT.Wrap(name, fn)
    return function(...)
        local r = pack(pcall(fn, ...))
        if r[1] then return unpack(r, 2, r.n) end
        local msg = tostring(r[2])
        if ns.Log then ns.Log.Failure(KEY, ("entry %s: %s"):format(name, msg)) end
        return ("error: " .. msg):sub(1, 100)
    end
end

-- Registers every entry once. Returns the number CheckThat stored.
function CT.RegisterEntries()
    if CT.registered then return CT.registered end
    local I = gate()
    if I and I.Active and not I.Active(KEY) then return 0 end
    local t = api()
    if not t or type(t.Entry) ~= "function" then return 0 end
    CT.registered = 0
    for _, name in ipairs(CT.ORDER) do
        local ok, stored = pcall(t.Entry, CT.ADDON, name, CT.Wrap(name, CT.entries[name]))
        if not ok then
            if I then I.Fail(KEY, "Entry: " .. tostring(stored)) end
            return CT.registered
        end
        if stored then CT.registered = CT.registered + 1 end
    end
    if ns.Log then ns.Log.Record(KEY, ("entries registered: %d"):format(CT.registered)) end
    return CT.registered
end

-- The Gate starts this at CheckThat's ADDON_LOADED, before PLAYER_LOGIN. CheckThat.Entry must be called at
-- login, so the entries wait for it on a module of their own: AceEvent keeps one handler per event per
-- object, and the Gate already listens for PLAYER_LOGIN on the addon. After login (CheckThat loaded late,
-- or the Gate's own login start) they register at once.
function CT.Start(ctx)
    if ns.Adapter and ns.Adapter.LoggedIn and ns.Adapter.LoggedIn() then
        CT.RegisterEntries()
        return
    end
    local a = ns.addon
    local target = a
    if a and type(a.NewModule) == "function" then
        local ok, module = pcall(a.NewModule, a, "CheckThat", "AceEvent-3.0")
        if ok and module then target = module end
    end
    local register = ctx and ctx.guard and ctx.guard(CT.RegisterEntries) or CT.RegisterEntries
    if not (target and ns.Listen and ns.Listen(target, "PLAYER_LOGIN", function() register() end)) then
        CT.RegisterEntries()
    end
end

if ns.Integrations and ns.Integrations.Register then
    ns.Integrations.Register(KEY, { anyClient = true, detect = CT.Detect, start = CT.Start })
end
