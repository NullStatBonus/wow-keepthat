-- Cross-character stock model (design D1, D6). Plain Lua: no game globals, so it runs under luajit.
-- Saved shape: store = { version = 1, realms = { [realm] = { [faction] = { [name] = Character } } } }.
local _, ns = ...

local Stock = {}
ns.Stock = Stock

Stock.EXPIRY = 90 * 86400

local EXPIRY = Stock.EXPIRY

function Stock.New()
    return { version = 1, realms = {} }
end

-- A store written by a newer KeepThat (another version) is not usable and is left untouched.
function Stock.Usable(store)
    return type(store) == "table" and store.version == 1 and type(store.realms) == "table"
end

function Stock.Character(store, realm, faction, name, create)
    if not Stock.Usable(store) then return nil end
    local r = store.realms[realm]
    if not r then
        if not create then return nil end
        r = {}
        store.realms[realm] = r
    end
    local f = r[faction]
    if not f then
        if not create then return nil end
        f = {}
        r[faction] = f
    end
    local c = f[name]
    if not c and create then
        c = {}
        f[name] = c
    end
    return c
end

function Stock.Scope(store, realm, faction)
    if not Stock.Usable(store) then return {} end
    local r = store.realms[realm]
    local f = type(r) == "table" and r[faction]
    return type(f) == "table" and f or {}
end

-- Moves one character's record to another realm and name, keeping every source and time, only into an
-- empty slot; emptied buckets are removed. True when moved. Used for records saved under a WoW Forever
-- surname as the realm (spec character-stock, "Earlier Forever stock records are moved once").
function Stock.Move(store, fromRealm, faction, fromName, toRealm, toName)
    if not Stock.Usable(store) then return false end
    local r = store.realms[fromRealm]
    local f = type(r) == "table" and r[faction]
    local c = type(f) == "table" and f[fromName]
    if type(c) ~= "table" then return false end
    local tr = store.realms[toRealm]
    if tr ~= nil and type(tr) ~= "table" then return false end
    local tf = tr and tr[faction]
    if tf ~= nil and type(tf) ~= "table" then return false end
    if tf and tf[toName] ~= nil then return false end
    f[fromName] = nil
    if next(f) == nil then r[faction] = nil end
    if next(r) == nil then store.realms[fromRealm] = nil end
    tr = store.realms[toRealm] or {}
    store.realms[toRealm] = tr
    tr[faction] = tr[faction] or {}
    tr[faction][toName] = c
    return true
end

-- A malformed saved entry (not a table, or no numeric seen) counts as expired, so Prune drops it.
local function expired(character, now)
    if type(character) ~= "table" or type(character.seen) ~= "number" then return true end
    return now - character.seen >= EXPIRY
end

function Stock.Prune(store, now)
    if not Stock.Usable(store) then return end
    for realm, factions in pairs(store.realms) do
        if type(factions) ~= "table" then
            store.realms[realm] = nil
        else
            for faction, characters in pairs(factions) do
                if type(characters) ~= "table" then
                    factions[faction] = nil
                else
                    for name, character in pairs(characters) do
                        if expired(character, now) then characters[name] = nil end
                    end
                    if next(characters) == nil then factions[faction] = nil end
                end
            end
            if next(factions) == nil then store.realms[realm] = nil end
        end
    end
end

-- A saved time later than now (clock went back) counts as now.
local function fresh(t, now)
    if type(t) ~= "number" then return false end
    if t > now then t = now end
    return now - t < EXPIRY, t
end

-- One container or mail record: its time when fresh and well formed (an items table of numbers), else nil.
-- A malformed record stays unknown; it is never read as an empty, counted container.
local function record(rec, now)
    if type(rec) ~= "table" or type(rec.items) ~= "table" then return nil end
    local ok, t = fresh(rec.t, now)
    if not ok then return nil end
    for _, n in pairs(rec.items) do if type(n) ~= "number" then return nil end end
    return t
end

-- The records of a source (one per expected container, or the mail record), or a state string.
local function records(src, now)
    if type(src) ~= "table" then return "missing" end
    if src.unavailable then return "unavailable" end
    local out = {}
    if src.expected then
        if type(src.expected) ~= "table" or type(src.c) ~= "table" then return "missing" end
        for _, id in ipairs(src.expected) do
            local rec = src.c[id]
            local t = record(rec, now)
            if not t then return "missing" end
            out[#out + 1] = { t = t, items = rec.items }
        end
        return out
    end
    local t = record(src, now)
    if not t then return "missing" end
    return { { t = t, items = src.items } }
end

-- state, items, oldest. state: "counted" | "missing" | "unavailable".
function Stock.Source(src, now)
    local recs = records(src, now)
    if type(recs) == "string" then return recs end
    local items, oldest = {}, nil
    for _, rec in ipairs(recs) do
        if not oldest or rec.t < oldest then oldest = rec.t end
        for item, n in pairs(rec.items) do items[item] = (items[item] or 0) + n end
    end
    return "counted", items, oldest
end

-- state, count of one item, oldest time among the records holding it. Reads only that item (tooltips).
local function sourceCount(src, now, itemID)
    local recs = records(src, now)
    if type(recs) == "string" then return recs end
    -- The age is the whole source's oldest record (spec: "the age of its oldest counted source").
    local n, oldest = 0, nil
    for _, rec in ipairs(recs) do
        local c = rec.items[itemID]
        if c and c > 0 then n = n + c end
        if not oldest or rec.t < oldest then oldest = rec.t end
    end
    return "counted", n, oldest
end

function Stock.Total(scope, itemID, now, selfName, selfBags)
    local total, complete, rows = 0, selfBags ~= nil, {}
    for name, character in pairs(scope) do
        if not expired(character, now) then
            local isSelf = name == selfName
            local row = { name = name, self = isSelf, count = 0 }
            local oldest
            local function add(field, state, n, since)
                if state == "missing" then complete = false end
                if state ~= "counted" then return end
                if n and n > 0 then
                    row[field] = n
                    row.count = row.count + n
                    if not oldest or since < oldest then oldest = since end
                end
            end
            if isSelf then
                if selfBags and selfBags > 0 then
                    row.bags = selfBags
                    row.count = row.count + selfBags
                end
            else
                add("bags", sourceCount(character.bags, now, itemID))
            end
            add("bank", sourceCount(character.bank, now, itemID))
            add("mail", sourceCount(character.mail, now, itemID))
            if row.count > 0 then
                if not isSelf and oldest then row.age = now - oldest end
                rows[#rows + 1] = row
                total = total + row.count
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.self ~= b.self then return a.self end
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    return total, complete, rows
end

function Stock.Missing(scope, now, selfName)
    local list = {}
    for name, character in pairs(scope) do
        if not expired(character, now) then
            local bank = Stock.Source(character.bank, now) == "missing"
            local mail = Stock.Source(character.mail, now) == "missing"
            if bank or mail then
                list[#list + 1] = { name = name, self = name == selfName, bank = bank, mail = mail }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.self ~= b.self then return a.self end
        return a.name < b.name
    end)
    return list
end

function Stock.Age(seconds)
    if seconds < 3600 then return "minute", math.max(1, math.floor(seconds / 60)) end
    if seconds < 86400 then return "hour", math.floor(seconds / 3600) end
    return "day", math.floor(seconds / 86400)
end
