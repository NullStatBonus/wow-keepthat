-- The integration registry: optional and contained (CLAUDE.md), gated to WoW Forever (design D1b).
--
-- API (stable; other Integrations/*.lua files use it at file load):
--
--   ns.Integrations.Register(key, spec)
--     key   the profile.integrations toggle ("baganator", "auctionator", ...)
--     spec  { detect = fn() -> truthy when the other addon is there,
--             start  = fn(ctx) -> nothing, or false, "why" when it cannot integrate,
--             stop   = optional fn(), called after a failure (unregister what start registered),
--             anyClient = optional true: also runs on Classic Era and has no toggle (Blizzard's bags) }
--     ctx = { key = key, guard = function(fn) -> fn wrapped in pcall; an error turns the integration
--             off for the session and logs it }. Wrap every callback the other addon or a hook calls.
--
--   ns.Integrations.Status(key) -> { detected = bool, working = bool, reason = string or nil }
--     reason: "not detected", "off", "not on Classic Era", "not started" or "failed: <why>".
--   ns.Integrations.Active(key) -> true while started, not failed and turned on.
--   ns.Integrations.Fail(key, why) turns one off for the session and records why (ns.Log.Failure).
--   ns.Integrations.Start() starts every detected, enabled, allowed integration that has not started;
--     it runs once settings are ready and again on any setting change, so a toggle turned on later
--     starts its integration then. Every detect and start runs in pcall.
local _, ns = ...

local I = { entries = {}, order = {} }
ns.Integrations = I

local function profile()
    return ns.addon and ns.addon.db and ns.addon.db.profile or ns.defaults and ns.defaults.profile or {}
end

function I.Register(key, spec)
    if type(key) ~= "string" or type(spec) ~= "table" then return end
    if not I.entries[key] then I.order[#I.order + 1] = key end
    I.entries[key] = { key = key, spec = spec }
end

local function allowed(e)
    return e.spec.anyClient or ns.client == "forever"
end

local function enabled(e)
    if e.spec.anyClient then return true end
    local t = profile().integrations
    return not (type(t) == "table" and t[e.key] == false)
end

local function detected(e)
    if type(e.spec.detect) ~= "function" then return false end
    local ok, found = pcall(e.spec.detect)
    return ok and found and true or false
end

function I.Fail(key, why)
    local e = I.entries[key]
    if not e or e.state == "failed" then return end
    e.state, e.reason = "failed", tostring(why or "unknown error")
    if ns.Log then ns.Log.Failure(key, e.reason) end
    if type(e.spec.stop) == "function" then pcall(e.spec.stop) end
    if ns.Overlay and ns.Overlay.Refresh then pcall(ns.Overlay.Refresh) end
end

-- fn wrapped so that an error disables the integration instead of reaching the error handler; after a
-- failure the wrapper does nothing.
function I.Guard(key, fn)
    return function(...)
        local e = I.entries[key]
        if not e or e.state == "failed" then return end
        local ok, err = pcall(fn, ...)
        if not ok then I.Fail(key, err) end
    end
end

function I.Active(key)
    local e = I.entries[key]
    return e ~= nil and e.state == "working" and allowed(e) and enabled(e)
end

local function startOne(e)
    if e.state or not allowed(e) or not enabled(e) or not detected(e) then return end
    if type(e.spec.start) ~= "function" then e.state = "working"; return end
    local ctx = { key = e.key, guard = function(fn) return I.Guard(e.key, fn) end }
    e.state = "working"   -- set first, so guarded callbacks run during start
    local ok, result, why = pcall(e.spec.start, ctx)
    if not ok then
        I.Fail(e.key, result)
    elseif result == false then
        I.Fail(e.key, why or "it could not integrate")
    elseif ns.Log then
        ns.Log.Record(e.key, "started")
    end
end

function I.Start()
    I.started = true
    for _, key in ipairs(I.order) do startOne(I.entries[key]) end
end

function I.Status(key)
    local e = I.entries[key]
    if not e then return { detected = false, working = false, reason = "not detected" } end
    local found = detected(e)
    if e.state == "failed" then return { detected = true, working = false, reason = "failed: " .. e.reason } end
    if not allowed(e) then return { detected = found, working = false, reason = "not on Classic Era" } end
    if not found then return { detected = false, working = false, reason = "not detected" } end
    if not enabled(e) then return { detected = true, working = false, reason = "off" } end
    if e.state == "working" then return { detected = true, working = true } end
    return { detected = true, working = false, reason = "not started" }
end

-- Keys in registration order (the debug report).
function I.Keys()
    local out = {}
    for i, key in ipairs(I.order) do out[i] = key end
    return out
end

-- Start at login, and again whenever another addon finishes loading: an addon (or its hook point)
-- that appears late is picked up then. Started and failed integrations are skipped.
ns.Start(function(addon)
    I.Start()
    if ns.Listen and addon then
        ns.Listen(addon, "ADDON_LOADED", function() I.Start() end)
        ns.Listen(addon, "PLAYER_LOGIN", function() I.Start() end)
    end
end)
if ns.Context and ns.Context.OnChange then
    ns.Context.OnChange(function() if I.started then I.Start() end end)
end
