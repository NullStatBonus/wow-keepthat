-- Stock recorder (Core/Stock.lua): events queue containers, the pending set is read once on the next
-- frame, closed windows never overwrite a record, whole containers replace, and the login reminder.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local RUNE, WOOL, IRON, OTHER = 14047, 2592, 2772, 999
local DAY = 86400

-- The fake world: what each container and the inbox hold, and which reads fail.
local W
local function newWorld()
    W = {
        identity = { "Me", "Realm", "Alliance" },
        now = 1000 * DAY,
        bagIDs = { 0, 1, 2, 3, 4 },
        bankIDs = { -1, 5, 6 },
        tabs = false,
        tabIDs = {},
        mailAvailable = true,
        c = {},          -- [bagID] = { [itemID] = n }
        fail = {},       -- [bagID] = true: the read fails
        inbox = {},
        inboxFail = false,
        reads = {},      -- [bagID] = number of reads
        frames = {},     -- queued next-frame callbacks
        known = {},      -- [event] = false: the client lacks it
    }
end
newWorld()

local A = {}
function A.PlayerIdentity() if W.identity then return W.identity[1], W.identity[2], W.identity[3], W.identity[4] end end
function A.Clock() return W.now end
function A.After(_, fn) W.frames[#W.frames + 1] = fn; return true end
function A.BagIDs() local o = {}; for i, v in ipairs(W.bagIDs) do o[i] = v end; return o end
function A.BankUsesTabs() return W.tabs end
function A.BankAvailable() return W.bankAvailable ~= false end
function A.BankIDs()
    if W.bankIDs == nil then return nil end
    local o = {}; for i, v in ipairs(W.tabs and W.tabIDs or W.bankIDs) do o[i] = v end; return o
end
function A.BankTabBagID(n) return W.tabs and W.tabIDs[n] or nil end
function A.ReadContainer(id, tracked)
    W.reads[id] = (W.reads[id] or 0) + 1
    if W.fail[id] then return nil end
    local out = {}
    for item, n in pairs(W.c[id] or {}) do if tracked[item] and n > 0 then out[item] = n end end
    return out
end
function A.MailAvailable() return W.mailAvailable end
function A.ReadInbox(tracked)
    W.inboxReads = (W.inboxReads or 0) + 1
    if W.inboxFail then return nil end
    local out = {}
    for item, n in pairs(W.inbox) do if tracked[item] and n > 0 then out[item] = n end end
    return out
end
function A.ItemCount(item)
    local n = 0
    for _, id in ipairs(W.bagIDs) do n = n + ((W.c[id] or {})[item] or 0) end
    return n
end

local ns = { Adapter = A }
H.locale(ns)
H.load("Model/Stock.lua", ns)
local settings = { endgame = true, leveling = false }
ns.Context = { Get = function()
    return { catalog = { endgame = { [RUNE] = { tailoring = { "x" } } } },
             routes = { materials = { tailoring = { [WOOL] = { 1 } }, mining = { [IRON] = { 1 } } } },
             settings = settings }
end }
local failures = {}
ns.Log = { Failure = function(area, m) failures[#failures + 1] = area .. ": " .. tostring(m) end }
local notified = 0
ns.Options = { NotifyChange = function() notified = notified + 1 end }
local starter
ns.Start = function(fn) starter = fn end
ns.Listen = function(target, event, fn)
    if W.known[event] == false then return false end
    target:RegisterEvent(event, fn)
    return true
end
H.load("Core/Stock.lua", ns)
local R = ns.StockRecorder
local Stock = ns.Stock

local handlers, printed, addon
local function newSession(db)
    R.Reset()
    handlers, printed = {}, {}
    addon = { db = db or addon.db }
    function addon:RegisterEvent(e, fn) handlers[e] = fn end
    function addon:Print(m) printed[#printed + 1] = m end
    starter(addon)
end
local function fire(e, ...) if handlers[e] then handlers[e](e, ...) end end
local function frame()
    local fs = W.frames
    W.frames = {}
    for _, fn in ipairs(fs) do fn() end
end
local function freshDB() return { global = { stock = Stock.New() }, profile = { stockReminder = true } } end
local function meRec(name) return Stock.Character(addon.db.global.stock, "Realm", "Alliance", name or "Me", false) end
local function login() fire("PLAYER_LOGIN"); frame() end

---------------------------------------------------------------------------------------------------
-- Login reads every bag; unmarked route material recorded with leveling off; reagent bag included.
W.bagIDs = { 0, 1, 2, 3, 4, 5 } -- 5 is the reagent bag on this client
W.bankIDs = { -1, 6, 7 }
W.c[0] = { [RUNE] = 12, [OTHER] = 3 }
W.c[5] = { [WOOL] = 4 }
newSession(freshDB())
fire("PLAYER_LOGIN")
eq(meRec().bags.c[0], nil, "nothing read before the next frame")
frame()
local me = meRec()
eq(me.seen, W.now, "seen at login")
eq(me.bags.c[0].items[RUNE], 12, "backpack recorded")
eq(me.bags.c[0].items[OTHER], nil, "untracked items not recorded")
eq(me.bags.c[5].items[WOOL], 4, "route material recorded with leveling off, from the reagent bag")
eq(#me.bags.expected, 6, "reagent bag expected")
eq(me.bags.c[1].t, W.now, "empty bag still recorded")
eq(next(me.bags.c[1].items), nil, "empty bag holds nothing")
eq(me.bank, nil, "bank not counted before opening")
eq(R.Identity(), "Me", "identity")
local total, complete = R.Total(RUNE)
eq(total, 12, "total from live bags")
eq(complete, false, "bank and mail missing: incomplete")
eq(R.Counted(), 1, "one character counted")
local reads5 = W.reads[5]
fire("BAG_UPDATE", 5); frame()
eq(W.reads[5], reads5 + 1, "reagent bag update read")

-- Guild bank event changes nothing.
local bagT, reads0 = meRec().bags.c[0].t, W.reads[0]
W.now = W.now + 1
fire("GUILDBANKBAGSLOTS_CHANGED"); frame()
eq(meRec().bags.c[0].t, bagT, "guild bank: bags record unchanged")
eq(W.reads[0], reads0, "guild bank: nothing read")
eq(meRec().bank, nil, "guild bank: no bank record")
W.now = W.now - 1
-- A bank bag update while the bank is closed queues nothing.
fire("BAG_UPDATE", 6)
eq(#W.frames, 0, "bank bag closed: nothing queued")
fire("BAG_UPDATE", -2)
eq(#W.frames, 0, "keyring ignored")

---------------------------------------------------------------------------------------------------
-- Deposit with the bank open: bags and bank change, total unchanged.
W.c[-1] = { [RUNE] = 8 }
fire("BANKFRAME_OPENED")
frame()
me = meRec()
eq(me.bank.c[-1].items[RUNE], 8, "bank read at open")
eq(me.bank.expected[3], 7, "bank expected enumerated")
local before = R.Total(RUNE)
eq(before, 20, "bags + bank")
W.now = W.now + 60
W.c[0][RUNE] = 2; W.c[-1][RUNE] = 18
fire("BAG_UPDATE", 0)
fire("PLAYERBANKSLOTS_CHANGED", 3) -- classic: the main bank container
frame()
me = meRec()
eq(me.bags.c[0].items[RUNE], 2, "bags 10 fewer")
eq(me.bank.c[-1].items[RUNE], 18, "bank 10 more")
eq(me.bank.c[-1].t, W.now, "bank container time updated")
eq(R.Total(RUNE), before, "total unchanged")
local readsBag6 = W.reads[6]
fire("BAG_UPDATE", 6)
frame()
eq(W.reads[6], readsBag6 + 1, "bank bag update read while open")

-- Failed container read keeps that record and age while others update.
local oldT = me.bank.c[6].t
W.now = W.now + 60
W.c[6] = { [RUNE] = 1 }; W.c[7] = { [RUNE] = 2 }
W.fail[6] = true
fire("BANKFRAME_OPENED")
frame()
me = meRec()
eq(me.bank.c[6].t, oldT, "failed container keeps its age")
eq(me.bank.c[6].items[RUNE], nil, "failed container keeps its items")
eq(me.bank.c[7].items[RUNE], 2, "other containers update")
eq(me.bank.c[7].t, W.now, "other container age updated")
eq(#failures, 1, "failure logged")
fire("BANKFRAME_OPENED"); frame()
eq(#failures, 1, "failure logged once per session")
W.fail[6] = nil

-- Open -> queue -> close before the next frame: nothing overwritten.
local bankT = me.bank.c[-1].t
W.now = W.now + 60
W.c[-1] = { [RUNE] = 99 }
fire("BAG_UPDATE", -1)
fire("BANKFRAME_CLOSED")
frame()
me = meRec()
eq(me.bank.c[-1].items[RUNE], 18, "closed bank: record kept")
eq(me.bank.c[-1].t, bankT, "closed bank: age kept")
-- And when the close lands after scheduling but the reopen does not happen: processing rechecks.
fire("BANKFRAME_OPENED")
local f = W.frames; W.frames = {}
fire("BANKFRAME_CLOSED")
for _, fn in ipairs(f) do fn() end
eq(meRec().bank.c[-1].items[RUNE], 18, "closed at run time: bank not read")
W.c[-1] = { [RUNE] = 18 }

---------------------------------------------------------------------------------------------------
-- Mail: taking mail moves a count from the mailbox to the bags.
W.inbox = { [RUNE] = 5 }
fire("MAIL_SHOW")
fire("MAIL_INBOX_UPDATE")
frame()
me = meRec()
eq(me.mail.items[RUNE], 5, "inbox read")
W.now = W.now + 60
W.inbox = {}; W.c[0][RUNE] = 7
fire("BAG_UPDATE", 0)
fire("MAIL_INBOX_UPDATE")
frame()
me = meRec()
eq(me.mail.items[RUNE], nil, "mailbox drops by 5")
eq(me.bags.c[0].items[RUNE], 7, "bags rise by 5")
eq(R.Total(RUNE), 7 + 18 + 2, "total unchanged after taking mail")
-- Inbox read failure keeps the previous record.
local mailT = me.mail.t
W.now = W.now + 60
W.inboxFail = true
fire("MAIL_INBOX_UPDATE"); frame()
eq(meRec().mail.t, mailT, "failed inbox keeps its age")
W.inboxFail = false
-- Close before the next frame: nothing overwritten.
W.inbox = { [RUNE] = 50 }
fire("MAIL_INBOX_UPDATE")
fire("MAIL_CLOSED")
frame()
eq(meRec().mail.t, mailT, "closed mailbox: record kept")
eq(meRec().mail.items[RUNE], nil, "closed mailbox: items kept")
fire("MAIL_INBOX_UPDATE"); frame()
eq(meRec().mail.t, mailT, "inbox update with the mailbox closed is ignored")
eq(notified > 0, true, "options told of changes")
W.inbox = {}

---------------------------------------------------------------------------------------------------
-- Modern bank tabs: a tab slot change updates that tab; a purchase adds the tab to expected.
W.tabs = true
W.tabIDs = { 12, 13 }
W.c[13] = { [RUNE] = 4 }
fire("BANKFRAME_OPENED"); frame()
me = meRec()
eq(#me.bank.expected, 2, "tabs expected")
eq(me.bank.c[-1], nil, "classic containers dropped from the tab list")
eq(me.bank.c[13].items[RUNE], 4, "tab read")
W.now = W.now + 60
W.c[13] = { [RUNE] = 6 }
local reads12 = W.reads[12]
fire("PLAYERBANKSLOTS_CHANGED", 2)
frame()
eq(meRec().bank.c[13].items[RUNE], 6, "tab 2 updated")
eq(W.reads[12], reads12, "other tab not reread")
W.tabIDs = { 12, 13, 14 }
fire("BANK_TABS_CHANGED"); frame()
me = meRec()
eq(me.bank.expected[3], 14, "purchased tab expected")
eq(me.bank.c[14] ~= nil, true, "purchased tab read")
fire("BANKFRAME_CLOSED")
W.tabs = false
fire("BAG_UPDATE", 13)
eq(#W.frames, 0, "bank tab update after closing: nothing queued")

---------------------------------------------------------------------------------------------------
-- No identity: nothing recorded and Total nil.
newWorld()
failures = {}
W.identity = nil
W.c[0] = { [RUNE] = 3 }
local db0 = freshDB()
newSession(db0)
login()
eq(next(db0.global.stock.realms), nil, "no identity: nothing recorded")
eq(R.Total(RUNE), nil, "no identity: total unknown")
eq(R.Missing(), nil, "no identity: missing unknown")
eq(R.State(), nil, "no identity: state unknown")
eq(#printed, 0, "no identity: no reminder")
eq(#failures, 1, "no identity: logged")
eq(failures[1]:sub(1, 6), "stock:", "logged under stock")
login()
eq(#failures, 1, "no identity: logged once")

-- Another store version: left alone.
newWorld()
local dbv = { global = { stock = { version = 2, realms = {} } }, profile = { stockReminder = true } }
newSession(dbv)
login()
eq(next(dbv.global.stock.realms), nil, "other version untouched")
eq(R.Total(RUNE), nil, "other version: unknown")

---------------------------------------------------------------------------------------------------
-- Prune at login, and the reminder.
local function seed(db, name, bank, mail, seen)
    local c = Stock.Character(db.global.stock, "Realm", "Alliance", name, true)
    c.seen = seen or W.now
    c.bags = { expected = { 0 }, c = { [0] = { t = W.now, items = {} } } }
    if bank == "counted" then c.bank = { expected = { -1 }, c = { [-1] = { t = W.now, items = { [RUNE] = 30 } } } }
    elseif bank == "unavailable" then c.bank = { unavailable = true } end
    if mail == "counted" then c.mail = { t = W.now, items = {} }
    elseif mail == "unavailable" then c.mail = { unavailable = true } end
    return c
end

-- Two characters missing: plural. The current one is fully counted.
newWorld()
local db = freshDB()
seed(db, "Me", "counted", "counted")
seed(db, "Bankmule", "counted", nil)
seed(db, "Hunter", nil, "counted", W.now - 89 * DAY)
seed(db, "Old", nil, nil, W.now - 100 * DAY)
local other = db.global.stock
other.realms.Realm.Horde = { Orc = { seen = W.now } }
newSession(db)
fire("PLAYER_LOGIN")
eq(#printed, 0, "reminder waits for the first bag read")
frame()
eq(db.global.stock.realms.Realm.Alliance.Old, nil, "expired character pruned at login")
eq(db.global.stock.realms.Realm.Horde.Orc ~= nil, true, "other faction kept")
eq(#printed, 1, "one reminder")
eq(printed[1], "2 characters have a bank or mailbox not counted. /kt status stock lists them.", "plural line")
eq(R.Counted(), 3, "three characters in scope")
local st = R.State()
eq(st.version, 1, "state version"); eq(st.characters, 3, "state characters"); eq(#st.missing, 2, "state missing")
eq(st.reminder, true, "state reminder"); eq(st.unavailable.bank, false, "state bank available")
local t, comp, rows = R.Total(RUNE)
eq(t, 60, "other characters' banks add up")
eq(comp, false, "incomplete")
eq(rows[1].name, "Me", "self row first"); eq(rows[2].name, "Bankmule", "other row from its record")
-- Printed once per session.
fire("BAG_UPDATE", 0); frame()
fire("PLAYER_LOGIN"); frame()
eq(#printed, 1, "printed once per session")
W.now = W.now + 2 * DAY
eq(R.Counted(), 2, "a character expiring during the session is no longer counted")
W.now = W.now - 2 * DAY
-- A /reload is a new session: printed again.
newSession(db)
login()
eq(#printed, 1, "reload prints again")

-- One missing (the current character's bank): singular.
newWorld()
db = freshDB()
seed(db, "Bankmule", "counted", "counted")
newSession(db)
login()
eq(printed[1], "1 character has a bank or mailbox not counted. /kt status stock lists it.", "singular line")
eq(#printed, 1, "singular printed once")

-- Setting off: silent.
db = freshDB(); db.profile.stockReminder = false
newSession(db)
login()
eq(#printed, 0, "setting off: silent")
eq(R.State().reminder, false, "state reminder off")

-- None missing: silent.
db = freshDB()
seed(db, "Me", "counted", "counted")
newSession(db)
login()
eq(#printed, 0, "nothing missing: silent")

-- Unavailable sources are not missing.
db = freshDB()
seed(db, "Me", "unavailable", "unavailable")
seed(db, "Alt", "counted", "unavailable")
newSession(db)
login()
eq(#printed, 0, "unavailable sources: silent")
eq(R.State().unavailable.bank, true, "state bank unavailable")
eq(R.State().unavailable.mail, true, "state mail unavailable")

-- A bank the client cannot read becomes unavailable at open; mail likewise.
newWorld()
W.bankAvailable = false
W.bankIDs = nil
W.mailAvailable = false
db = freshDB()
newSession(db)
login()
eq(#printed, 1, "fresh character: own bank and mail missing")
fire("BANKFRAME_OPENED"); frame()
fire("MAIL_SHOW"); fire("MAIL_INBOX_UPDATE"); frame()
eq(meRec().bank.unavailable, true, "bank unavailable")
eq(meRec().mail.unavailable, true, "mail unavailable")
eq(#R.Missing(), 0, "unavailable is not missing")
local _, compU = R.Total(RUNE)
eq(compU, true, "unavailable sources keep the total complete")

-- No MAIL_SHOW on this client: the inbox update opens the mailbox.
newWorld()
W.known.MAIL_SHOW = false
W.inbox = { [WOOL] = 2 }
newSession(freshDB())
login()
fire("MAIL_INBOX_UPDATE"); frame()
eq(meRec().mail.items[WOOL], 2, "inbox read without MAIL_SHOW")

-- A failed first bag read leaves bags not counted for others; the next BAG_UPDATE retries.
newWorld()
W.fail[2] = true
newSession(freshDB())
login()
eq(meRec().bags.c[2], nil, "failed bag has no record")
W.fail[2] = nil
fire("BAG_UPDATE", 2); frame()
eq(meRec().bags.c[2] ~= nil, true, "next update retries")
-- A bag swap re-enumerates the bags.
W.bagIDs = { 0, 1, 2, 3, 4, 5 }
fire("BAG_CONTAINER_UPDATE"); frame()
eq(#meRec().bags.expected, 6, "bag swap re-enumerates")
eq(meRec().bags.c[5] ~= nil, true, "new bag read")

---------------------------------------------------------------------------------------------------
-- Codex diff review fixes.
-- A bank whose container list cannot be read (the client has a bank) keeps the saved bank.
newWorld()
db = freshDB()
newSession(db)
login()
W.c[-1] = { [RUNE] = 8 }
fire("BANKFRAME_OPENED"); frame()
fire("BANKFRAME_CLOSED")
local saved = meRec().bank
eq(saved.c[-1].items[RUNE], 8, "bank counted before the failure")
W.bankIDs = nil
fire("BANKFRAME_OPENED"); frame()
eq(meRec().bank, saved, "failed bank list keeps the saved bank")
eq(meRec().bank.unavailable, nil, "failed bank list is not unavailable")
fire("BANKFRAME_CLOSED")

-- A new install has no stock in AceDB defaults; the recorder creates it at login.
newWorld()
db = { global = {}, profile = { stockReminder = true } }
newSession(db)
login()
eq(Stock.Usable(db.global.stock), true, "stock created at login")
eq(type(meRec()), "table", "current character recorded on a new install")

-- A malformed saved entry does not stop the current character being recorded.
newWorld()
db = freshDB()
db.global.stock.realms.Realm = { Alliance = { Ghost = false }, Horde = "bad" }
newSession(db)
login()
eq(type(meRec()), "table", "current character recorded despite a malformed save")
eq(meRec("Ghost"), nil, "malformed character dropped")
eq(R.Total(RUNE) ~= nil, true, "stock known after a malformed save")

-- WoW Forever before 0.4.5 filed a character under its surname as the realm and its first name. Its next
-- login moves the record to the realm and full name; an alt with another surname then counts it.
newWorld()
W.identity = { "Me", "Smith", "Alliance" }
W.c[-1] = { [RUNE] = 7 }
newSession(freshDB())
login()
fire("BANKFRAME_OPENED"); frame(); fire("BANKFRAME_CLOSED")
local old = Stock.Character(addon.db.global.stock, "Smith", "Alliance", "Me", false)
eq(old and old.bank ~= nil, true, "old-style record with a counted bank")
W.identity = { "Me Smith", "Realm", "Alliance", "Smith" }
newSession()
login()
eq(Stock.Character(addon.db.global.stock, "Smith", "Alliance", "Me", false), nil, "the surname record is gone")
eq(meRec("Me Smith"), old, "moved to the realm and full name")
eq(R.Identity(), "Me Smith", "full name")
W.identity = { "Bo Jones", "Realm", "Alliance", "Jones" }
newSession()
login()
eq((R.Total(RUNE)), 7, "an alt with another surname counts Me Smith's bank")
-- Classic Era (no surname): a record under another realm is never moved.
W.identity = { "Me", "Realm", "Alliance" }
addon.db.global.stock.realms.Smith = { Alliance = { Me = { seen = W.now } } }
newSession()
login()
eq(addon.db.global.stock.realms.Smith.Alliance.Me.seen, W.now, "Era: nothing moved")

H.done()
