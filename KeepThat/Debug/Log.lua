-- Debug log. Log.Record(area, message) keeps the last lines in saved variables while debugging is on,
-- and always keeps failures (Log.Failure) so the report can name a disabled integration.
-- Log.Report() builds the text of /kt log.
local _, ns = ...

local Log = { MAX = 300, failures = {} }
ns.Log = Log

local function store()
    local db = ns.addon and ns.addon.db
    return db and db.global and db.global.log
end

function Log.Enabled()
    local db = ns.addon and ns.addon.db
    return db and db.profile and db.profile.debug or false
end

function Log.Record(area, message)
    local lines = store()
    if not lines or not Log.Enabled() then return end
    lines[#lines + 1] = ("[%s] %s"):format(tostring(area), tostring(message))
    while #lines > Log.MAX do table.remove(lines, 1) end
end

-- A failure that turned something off for the session (an integration, a hook). Kept in memory for the
-- report even when debugging is off.
function Log.Failure(area, message)
    Log.failures[#Log.failures + 1] = { area = tostring(area), message = tostring(message) }
    Log.Record(area, "FAILED: " .. tostring(message))
end

-- Every saved setting as sorted "path = value" lines (tables are walked).
local function flatten(t, prefix, out)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then return a < b end
        return type(a) < type(b)
    end)
    for _, k in ipairs(keys) do
        local v, path = t[k], prefix .. tostring(k)
        if type(v) == "table" then flatten(v, path .. ".", out)
        else out[#out + 1] = ("  %s = %s"):format(path, tostring(v)) end
    end
end

local function describe(status)
    if type(status) ~= "table" then return tostring(status) end
    local parts = {}
    for _, k in ipairs({ "detected", "working", "reason" }) do
        if status[k] ~= nil then parts[#parts + 1] = k .. "=" .. tostring(status[k]) end
    end
    return table.concat(parts, ", ")
end

-- The text of /kt log: settings, integration state, failures, then the recorded lines.
function Log.Report()
    local out = { ("KeepThat %s, client %s"):format(tostring(ns.version), tostring(ns.client)), "", "Settings:" }
    local db = ns.addon and ns.addon.db
    flatten(db and db.profile or ns.defaults.profile, "", out)

    out[#out + 1] = ""
    out[#out + 1] = "Integrations:"
    local status = ns.Integrations and ns.Integrations.Status
    if type(status) ~= "function" then
        out[#out + 1] = "  (state not available)"
    else
        local keys = {}
        if ns.Integrations.Keys then
            for _, k in ipairs(ns.Integrations.Keys()) do keys[#keys + 1] = k end
        else
            for k in pairs(ns.defaults.profile.integrations) do keys[#keys + 1] = k end
            table.sort(keys)
        end
        for _, k in ipairs(keys) do
            local ok, s = pcall(status, k)
            out[#out + 1] = ("  %s: %s"):format(k, ok and describe(s) or ("error: " .. tostring(s)))
        end
    end

    out[#out + 1] = ""
    out[#out + 1] = "Failures:"
    for _, f in ipairs(Log.failures) do out[#out + 1] = ("  [%s] %s"):format(f.area, f.message) end
    if #Log.failures == 0 then out[#out + 1] = "  (none)" end

    out[#out + 1] = ""
    out[#out + 1] = "Recorded lines:"
    local lines = store() or {}
    for _, line in ipairs(lines) do out[#out + 1] = "  " .. line end
    if #lines == 0 then out[#out + 1] = "  (none)" end
    return table.concat(out, "\n")
end
