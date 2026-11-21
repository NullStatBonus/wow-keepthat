-- Cross-character stock recorder (design D3, D4, D7): reads this character's bags, bank and mailbox
-- into the account-wide store and answers totals for the surfaces. Syndicator's pattern: every event
-- only queues a container; the pending set is read once on the next frame, after checking again that
-- the bank or mailbox is still open. Every game call goes through ns.Adapter.
local _, ns = ...
local L = ns.L

local R = {}
ns.StockRecorder = R

local addon            -- set at start
local identity         -- { name, realm, faction } once login found one
local active = false   -- recording this session
local bankOpen, mailOpen = false, false
local pending = { bags = {}, bank = {}, mail = false }
local scheduled = false
local loginRead = false   -- the login bags read is queued; the reminder (once per session) follows it
local logged = {}         -- failure keys already logged this session
local tracked, trackedCtx
-- Changes the game reported for the bank or inbox that are not read yet, and when each window closed: a
-- change still unread at close, or reported up to LATE seconds after, leaves that record unknown.
local dirty = { bank = {}, mail = false }
local closedAt = {}
local LATE = 10

local function A() return ns.Adapter end

local function logOnce(key, message)
    if logged[key] then return end
    logged[key] = true
    if ns.Log and ns.Log.Failure then pcall(ns.Log.Failure, "stock", message) end
end

local function store()
    local db = addon and addon.db
    local s = db and db.global and db.global.stock
    if ns.Stock.Usable(s) then return s end
    return nil
end

-- Every endgame and leveling catalog item plus every route material (Profession Journal's too while it
-- works), whatever the settings mark. Rebuilt when the context changes.
function R.Tracked()
    local ctx = ns.Context and ns.Context.Get() or {}
    if tracked and ctx == trackedCtx then return tracked end
    local t = {}
    local catalog, routes = ctx.catalog or {}, ctx.routes or {}
    for _, key in ipairs({ "endgame", "leveling" }) do
        for id in pairs(type(catalog[key]) == "table" and catalog[key] or {}) do t[id] = true end
    end
    for _, items in pairs(type(routes.materials) == "table" and routes.materials or {}) do
        for id in pairs(items) do t[id] = true end
    end
    local PJ = ns.ProfessionJournal
    if ctx.extra and PJ and type(PJ.Items) == "function" and type(PJ.PROFESSIONS) == "table" then
        for _, profession in ipairs(PJ.PROFESSIONS) do
            local ok, ids = pcall(PJ.Items, profession)
            for _, id in ipairs(ok and type(ids) == "table" and ids or {}) do t[id] = true end
        end
    end
    tracked, trackedCtx = t, ctx
    return t
end

local function me(create)
    local s = store()
    if not (active and s) then return nil end
    return ns.Stock.Character(s, identity.realm, identity.faction, identity.name, create)
end

local function notify()
    if ns.Options and ns.Options.NotifyChange then pcall(ns.Options.NotifyChange) end
end

-- The game reported a change to a bank container (id) or the inbox (kind "mail") that cannot be read any
-- more: that record is no longer known, so it counts as not counted until the window opens again.
local function forget(kind, id)
    local character = me(false)
    if not character then return end
    local src = character[kind]
    if type(src) ~= "table" or src.unavailable then return end
    if kind == "bank" then
        if type(src.c) ~= "table" or src.c[id] == nil then return end
        src.c[id] = nil
    else
        character.mail = nil
    end
    if ns.Log and ns.Log.Record then
        pcall(ns.Log.Record, "stock", ("%s changed as it closed; not counted until it is opened again"):format(kind))
    end
    notify()
end

local function late(kind)
    local t, now = closedAt[kind], A().Clock()
    return t ~= nil and now ~= nil and now - t <= LATE
end

local function asSet(list)
    local set = {}
    for _, id in ipairs(list or {}) do set[id] = true end
    return set
end

-- A container source with this expected list; records of containers no longer expected are dropped.
local function expect(src, ids)
    if type(src) ~= "table" or src.unavailable or type(src.c) ~= "table" then src = { c = {} } end
    src.expected = ids
    local keep = asSet(ids)
    for id in pairs(src.c) do if not keep[id] then src.c[id] = nil end end
    return src
end

local function process()
    scheduled = false
    local work = pending
    pending = { bags = {}, bank = {}, mail = false }
    local character = me(true)
    local now = A().Clock()
    local remind = loginRead
    loginRead = false
    if character and now then
        local items = R.Tracked()
        local changed = false
        local function read(src, kind, set)
            if type(src) ~= "table" or type(src.c) ~= "table" then return end
            for id in pairs(set) do
                if kind == "bank" then dirty.bank[id] = nil end
                local got = A().ReadContainer(id, items)
                if got == nil then
                    logOnce(kind .. id, ("%s container %s could not be read; its last record is kept"):format(kind, tostring(id)))
                else
                    src.c[id] = { t = now, items = got }
                    changed = true
                end
            end
        end
        if type(character.bags) ~= "table" or character.bags.unavailable then
            character.bags = expect(nil, A().BagIDs())
        end
        read(character.bags, "bag", work.bags)
        if bankOpen then read(character.bank, "bank", work.bank) end
        if work.mail and mailOpen then
            dirty.mail = false
            local got = A().ReadInbox(items)
            if got == nil then
                logOnce("inbox", "inbox could not be read; its last record is kept")
            else
                character.mail = { t = now, items = got }
                changed = true
            end
        end
        if changed then notify() end
    end
    if remind then pcall(R.Reminder) end
end

local function schedule()
    if scheduled then return end
    scheduled = true
    local function run()
        local ok, err = pcall(process)
        if not ok then scheduled = false; logOnce("process", ("reading stock failed: %s"):format(tostring(err))) end
    end
    if not A().After(0, run) then run() end
end

local function queueBags()
    local character = me(true)
    if not character then return end
    character.bags = expect(character.bags, A().BagIDs())
    for _, id in ipairs(character.bags.expected) do pending.bags[id] = true end
    schedule()
end

-- Re-enumerates the bank and queues every container; the bank must be open.
local function queueBank()
    local character = me(true)
    if not character then return end
    if not A().BankAvailable() then
        character.bank = { unavailable = true }
        notify()
        return
    end
    local ids = A().BankIDs()
    if ids == nil then
        -- The client has a bank, but its list could not be read: keep the saved bank as it is.
        logOnce("bankids", "the bank's container list could not be read; the saved bank is kept")
        return
    end
    character.bank = expect(character.bank, ids)
    for _, id in ipairs(ids) do pending.bank[id] = true end
    schedule()
end

local function isIn(list, id)
    for _, v in ipairs(list or {}) do if v == id then return true end end
    return false
end

-- Handlers (exposed for tests through R.events).
local on = {}
R.events = on

function on.PLAYER_LOGIN()
    if active then return end
    local name, realm, faction, surname = A().PlayerIdentity()
    local now = A().Clock()
    local global = addon and addon.db and addon.db.global
    if not name then logOnce("identity", "no player identity; stock is not recorded this session") return end
    if not now then logOnce("clock", "no clock; stock is not recorded this session") return end
    if not global then return end
    -- Created here, not by AceDB defaults: a recursive defaults merge would write into another version's data.
    if global.stock == nil then global.stock = ns.Stock.New() end
    local s = global.stock
    if not ns.Stock.Usable(s) then logOnce("store", "saved stock has another version; it is left alone") return end
    identity = { name = name, realm = realm, faction = faction }
    active = true
    -- Active only once the current character is set up; a malformed save must not stop recording.
    local ok, err = pcall(function()
        -- WoW Forever before 0.4.5 filed this character under its surname and first name: move it once.
        if surname then
            ns.Stock.Move(s, surname, faction, name:sub(1, #name - #surname - 1), realm, name)
        end
        ns.Stock.Prune(s, now)
        local character = me(true)
        character.seen = now
        -- A source this client cannot read is unavailable from the start, not missing (no reminder for it).
        if not A().BankAvailable() then character.bank = { unavailable = true } end
        if not A().MailAvailable() then character.mail = { unavailable = true } end
    end)
    if not ok then
        active, identity = false, nil
        logOnce("login", tostring(err))
        return
    end
    loginRead = true
    queueBags()
end

function on.BAG_UPDATE(_, bagID)
    local character = me(false)
    if not character then return end
    local bags = type(character.bags) == "table" and character.bags.expected or A().BagIDs()
    if isIn(bags, bagID) then
        pending.bags[bagID] = true
        schedule()
    elseif type(character.bank) == "table" and isIn(character.bank.expected, bagID) then
        if bankOpen then
            pending.bank[bagID] = true
            dirty.bank[bagID] = true
            schedule()
        elseif late("bank") then
            forget("bank", bagID)
        end
    end
end

function on.PLAYERBANKSLOTS_CHANGED(_, slot)
    local character = (bankOpen or late("bank")) and me(false)
    if not character then return end
    if type(character.bank) ~= "table" or character.bank.unavailable then return end
    local id
    if A().BankUsesTabs() then
        id = A().BankTabBagID(slot)
    else
        id = type(character.bank.expected) == "table" and character.bank.expected[1] or -1
    end
    if id == nil then return end
    if not bankOpen then forget("bank", id) return end
    pending.bank[id] = true
    dirty.bank[id] = true
    schedule()
end

local function reenumerate()
    if not me(false) then return end
    queueBags()
    if bankOpen then queueBank() end
end
on.BAG_CONTAINER_UPDATE = reenumerate
on.PLAYERBANKBAGSLOTS_CHANGED = reenumerate
on.BANK_TABS_CHANGED = reenumerate
on.BANK_TAB_SETTINGS_UPDATED = reenumerate

function on.BANKFRAME_OPENED()
    bankOpen, closedAt.bank = true, nil
    queueBank()
end

function on.BANKFRAME_CLOSED()
    bankOpen = false
    pending.bank = {}
    for id in pairs(dirty.bank) do forget("bank", id) end
    dirty.bank = {}
    closedAt.bank = A().Clock()
end

function on.MAIL_SHOW()
    mailOpen, closedAt.mail = true, nil
end

local mailShowKnown = true
function on.MAIL_INBOX_UPDATE()
    if not mailOpen and late("mail") then forget("mail") return end
    if not mailShowKnown then mailOpen = true end
    if not mailOpen then return end
    local character = me(true)
    if not character then return end
    if not A().MailAvailable() then
        character.mail = { unavailable = true }
        notify()
        return
    end
    pending.mail = true
    dirty.mail = true
    schedule()
end

function on.MAIL_CLOSED()
    mailOpen = false
    pending.mail = false
    if dirty.mail then forget("mail") end
    dirty.mail = false
    closedAt.mail = A().Clock()
end

-- Surfaces --------------------------------------------------------------------------------------

local function scope()
    local s = store()
    if not (active and s) then return nil end
    local now = A().Clock()
    if not now then return nil end
    return ns.Stock.Scope(s, identity.realm, identity.faction), now
end

function R.Identity()
    if not (active and store()) then return nil end
    return identity.name, identity.realm, identity.faction
end

-- total, complete, rows for the current realm and faction; nil when stock is unknown.
function R.Total(itemID)
    local sc, now = scope()
    if not sc then return nil end
    return ns.Stock.Total(sc, itemID, now, identity.name, A().ItemCount(itemID))
end

function R.Missing()
    local sc, now = scope()
    if not sc then return nil end
    return ns.Stock.Missing(sc, now, identity.name)
end

function R.Counted()
    local sc, now = scope()
    if not sc then return 0 end
    local n = 0
    for _, c in pairs(sc) do
        if now - (c.seen or 0) < ns.Stock.EXPIRY then n = n + 1 end
    end
    return n
end

function R.State()
    local character = me(false)
    if not character then return nil end
    local profile = addon.db.profile or {}
    return {
        version = store().version,
        characters = R.Counted(),
        missing = R.Missing() or {},
        unavailable = {
            bank = type(character.bank) == "table" and character.bank.unavailable == true,
            mail = type(character.mail) == "table" and character.mail.unavailable == true,
        },
        reminder = profile.stockReminder == true,
    }
end

-- The login reminder line, when it is on and some character in scope has a bank or mailbox not counted.
function R.Reminder()
    local profile = addon and addon.db and addon.db.profile
    if not (profile and profile.stockReminder) then return end
    local missing = R.Missing()
    local n = missing and #missing or 0
    if n == 0 then return end
    if n == 1 then
        addon:Print(L["1 character has a bank or mailbox not counted. /kt status stock lists it."])
    else
        addon:Print(L["%d characters have a bank or mailbox not counted. /kt status stock lists them."]:format(n))
    end
end

-- Test hook: forget the session (a /reload starts a new one).
function R.Reset()
    addon, identity, active, bankOpen, mailOpen = nil, nil, false, false, false
    pending = { bags = {}, bank = {}, mail = false }
    scheduled, loginRead, logged, tracked, trackedCtx = false, false, {}, nil, nil
    dirty, closedAt = { bank = {}, mail = false }, {}
    mailShowKnown = true
end

local EVENTS = { "PLAYER_LOGIN", "BAG_UPDATE", "PLAYERBANKSLOTS_CHANGED", "BAG_CONTAINER_UPDATE",
    "PLAYERBANKBAGSLOTS_CHANGED", "BANK_TABS_CHANGED", "BANK_TAB_SETTINGS_UPDATED", "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED", "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_CLOSED" }

-- Events go to a module of their own: AceEvent keeps one handler per event per object, and other
-- files already listen for PLAYER_LOGIN on the addon.
ns.Start(function(a)
    addon = a
    local target = a
    if type(a.NewModule) == "function" then
        local ok, module = pcall(a.NewModule, a, "Stock", "AceEvent-3.0")
        if ok and module then target = module end
    end
    for _, event in ipairs(EVENTS) do
        local handler = on[event]
        local listened = ns.Listen(target, event, function(...)
            local ok, err = pcall(handler, ...)
            if not ok then logOnce("event " .. event, ("%s failed: %s"):format(event, tostring(err))) end
        end)
        if event == "MAIL_SHOW" and not listened then mailShowKnown = false end
    end
end)
