-- Model/Stock.lua against the character-stock scenarios.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ns = {}
H.load("Model/Stock.lua", ns)
local S = ns.Stock

local DAY = 86400
local NOW = 1000 * DAY
local RC = 14047

local function src(t, items, ids)
    ids = ids or { 0 }
    local s = { expected = {}, c = {} }
    for i, id in ipairs(ids) do
        s.expected[i] = id
        s.c[id] = { t = t, items = (i == 1) and items or {} }
    end
    return s
end
local function mail(t, items) return { t = t, items = items } end
local function char(seen, bags, bank, mailSrc)
    return { seen = seen, bags = bags, bank = bank, mail = mailSrc }
end

eq(S.EXPIRY, 90 * DAY, "expiry is 90 days")

-- New / Usable / Character / Scope
local store = S.New()
eq(store.version, 1, "new store version")
eq(next(store.realms), nil, "new store empty")
eq(S.Usable(store), true, "new store usable")
eq(S.Usable({ version = 2, realms = {} }), false, "other version unusable")
eq(S.Usable({ version = 1 }), false, "no realms unusable")
eq(S.Usable(nil), false, "nil unusable")
eq(S.Character(store, "R", "A", "Me"), nil, "no character without create")
local me = S.Character(store, "R", "A", "Me", true)
eq(S.Character(store, "R", "A", "Me"), me, "created character found")
eq(S.Character({ version = 2, realms = {} }, "R", "A", "Me", true), nil, "unusable store creates nothing")
eq(next(S.Scope(store, "R", "H")), nil, "empty scope")
eq(S.Scope(store, "R", "A").Me, me, "scope holds the character")
eq(next(S.Scope({ version = 2, realms = {} }, "R", "A")), nil, "unusable store has empty scope")

-- Source
local st, items, oldest = S.Source(src(NOW - 100, { [RC] = 5 }, { 0, 1 }), NOW)
eq(st, "counted", "source counted")
eq(items[RC], 5, "source items")
eq(oldest, NOW - 100, "source oldest")
local two = src(NOW - 100, { [RC] = 5 }, { 0, 1 })
two.c[1].items = { [RC] = 7 }
two.c[1].t = NOW - 500
st, items, oldest = S.Source(two, NOW)
eq(items[RC], 12, "containers are summed")
eq(oldest, NOW - 500, "oldest container wins")
two.c[1] = nil
eq((S.Source(two, NOW)), "missing", "expected bag without a record is missing")
eq((S.Source(nil, NOW)), "missing", "nil source is missing")
eq((S.Source({ unavailable = true }, NOW)), "unavailable", "unavailable")
eq((S.Source(src(NOW - 90 * DAY, {}), NOW)), "missing", "container 90 days old is missing")
eq((S.Source(src(NOW - 90 * DAY + 1, {}), NOW)), "counted", "container just under 90 days counts")
eq((S.Source(mail(NOW - 90 * DAY, {}), NOW)), "missing", "mail 90 days old is missing")
eq((S.Source(mail(NOW - 5, { [RC] = 3 }), NOW)), "counted", "fresh mail counts")
st, items, oldest = S.Source(mail(NOW + 500, { [RC] = 3 }), NOW)
eq(st, "counted", "mail from the future counts")
eq(oldest, NOW, "a t later than now is treated as now")
st, _, oldest = S.Source(src(NOW + 500, {}), NOW)
eq(oldest, NOW, "container from the future is treated as now")
-- A future t does not rescue an old one: t is clamped, not ignored.
eq((S.Source(src(NOW + 100 * DAY, {}), NOW - 200 * DAY)), "counted", "far-future t is just now")

-- Total
local scope = {
    Me = char(NOW, nil, src(NOW - 2 * 3600, { [RC] = 8 }), mail(NOW - 59, {})),
    Bankmule = char(NOW - DAY, src(NOW - DAY, {}), src(NOW - 3 * DAY, { [RC] = 30 }), mail(NOW - DAY, {})),
    Hunter = char(NOW - DAY, src(NOW - DAY, {}), src(NOW - DAY, {}), mail(NOW - 59, { [RC] = 5 })),
}
local total, complete, rows = S.Total(scope, RC, NOW, "Me", 12)
eq(total, 55, "total across bags, bank, mail and characters")
eq(complete, true, "everything counted is complete")
eq(#rows, 3, "three holders")
eq(rows[1].name, "Me", "self first")
eq(rows[1].self, true, "self flag")
eq(rows[1].bags, 12, "self bags are live")
eq(rows[1].bank, 8, "self bank from record")
eq(rows[1].count, 20, "self count")
eq(rows[1].age, nil, "self has no age")
eq(rows[2].name, "Bankmule", "bigger holder next")
eq(rows[2].bank, 30, "bank count")
eq(rows[2].age, 3 * DAY, "age is the oldest counted source holding the item")
eq(rows[3].name, "Hunter", "smaller holder last")
eq(rows[3].mail, 5, "mail count")
eq(rows[3].bags, nil, "no bags entry when none held")
eq(rows[3].age, 59, "age from the mail that holds it")

-- Age ignores counted sources that do not hold the item.
eq(rows[2].age, 3 * DAY, "empty fresher sources do not lower the age")

-- Age is the oldest of several counted sources holding the item.
local _, _, two2 = S.Total({ B = char(NOW, src(NOW, { [RC] = 1 }), src(NOW - 5 * DAY, { [RC] = 1 }), mail(NOW - 60, { [RC] = 1 })) }, RC, NOW, "Me", 0)
eq(two2[1].age, 5 * DAY, "age is the oldest source that holds the item")

-- Only holders are listed.
local _, _, none = S.Total(scope, 999, NOW, "Me", 0)
eq(#none, 0, "no holders for an unheld item")

-- Self bags nil: incomplete, not zero.
total, complete, rows = S.Total(scope, RC, NOW, "Me", nil)
eq(complete, false, "selfBags nil is incomplete")
eq(total, 43, "unknown bags add nothing")

-- Self's recorded bags are ignored in favour of the live count.
scope.Me.bags = src(NOW, { [RC] = 999 })
total = S.Total(scope, RC, NOW, "Me", 12)
eq(total, 55, "self record bags are not counted")
scope.Me.bags = nil

-- Incomplete when bank or mail missing; bags missing for others too.
local function with(mod)
    local sc = {
        Me = char(NOW, nil, src(NOW, { [RC] = 1 }), mail(NOW, {})),
        Other = char(NOW, src(NOW, { [RC] = 2 }), src(NOW, { [RC] = 4 }), mail(NOW, { [RC] = 8 })),
    }
    mod(sc)
    return S.Total(sc, RC, NOW, "Me", 16)
end
total, complete = with(function() end)
eq(complete, true, "baseline complete")
eq(total, 31, "baseline total")
total, complete = with(function(sc) sc.Other.mail = nil end)
eq(complete, false, "other mail never counted is incomplete")
eq(total, 23, "sums what is counted")
_, complete = with(function(sc) sc.Other.bank = nil end)
eq(complete, false, "other bank missing is incomplete")
_, complete = with(function(sc) sc.Me.bank = nil end)
eq(complete, false, "own bank missing is incomplete")
_, complete = with(function(sc) sc.Me.mail = nil end)
eq(complete, false, "own mail missing is incomplete")
_, complete = with(function(sc) sc.Other.bags = nil end)
eq(complete, false, "other bags missing is incomplete")
_, complete = with(function(sc) sc.Other.bank.c[0] = nil end)
eq(complete, false, "expected bank bag without a record is incomplete")
_, complete = with(function(sc) sc.Other.bank.c[0].t = NOW - 90 * DAY end)
eq(complete, false, "bank container older than 90 days is incomplete")
total, complete = with(function(sc) sc.Other.bank = { unavailable = true } end)
eq(complete, true, "unavailable bank stays complete")
eq(total, 27, "unavailable adds nothing")
_, complete = with(function(sc) sc.Other.mail = { unavailable = true }; sc.Me.bank = { unavailable = true } end)
eq(complete, true, "unavailable mail stays complete")

-- Expired characters ignored by Total and Missing.
total, complete, rows = with(function(sc)
    sc.Old = char(NOW - 90 * DAY, src(NOW, { [RC] = 100 }), nil, nil)
end)
eq(total, 31, "expired character not counted")
eq(complete, true, "expired character does not make it incomplete")
eq(#rows, 2, "expired character not listed")

-- Prune
local ps = S.New()
S.Character(ps, "R", "A", "Old", true).seen = NOW - 90 * DAY
S.Character(ps, "R", "A", "Young", true).seen = NOW - 90 * DAY + 1
S.Character(ps, "R2", "H", "OldOnly", true).seen = NOW - 100 * DAY
S.Character(ps, "R3", "H", "OldFuture", true).seen = NOW - 200 * DAY
S.Character(ps, "R3", "A", "Keep", true).seen = NOW
S.Prune(ps, NOW)
eq(S.Character(ps, "R", "A", "Old"), nil, "90-day character pruned")
eq(ps.realms.R2, nil, "empty realm removed")
eq(ps.realms.R3.H, nil, "empty faction removed")
eq(ps.realms.R3.A.Keep ~= nil, true, "other faction kept")
S.Prune({ version = 2, realms = { R = { A = { X = { seen = 0 } } } } }, NOW)
local v2 = { version = 2, realms = { R = { A = { X = { seen = 0 } } } } }
S.Prune(v2, NOW)
eq(v2.realms.R.A.X ~= nil, true, "unusable store is not pruned")

-- Other realm and faction excluded by Scope.
local ws = S.New()
S.Character(ws, "R", "A", "Me", true).seen = NOW
local h = S.Character(ws, "R", "H", "Horde", true)
h.seen = NOW; h.bags = src(NOW, { [RC] = 30 }); h.bank = src(NOW, {}); h.mail = mail(NOW, {})
local o = S.Character(ws, "Other", "A", "Away", true)
o.seen = NOW; o.bags = src(NOW, { [RC] = 40 }); o.bank = src(NOW, {}); o.mail = mail(NOW, {})
total, _, rows = S.Total(S.Scope(ws, "R", "A"), RC, NOW, "Me", 1)
eq(total, 1, "other faction and realm are not counted")
eq(#rows, 1, "other faction and realm are not listed")
eq(#S.Missing(S.Scope(ws, "R", "A"), NOW, "Me"), 1, "only scope listed as missing")

-- Backwards clock: saved t later than now is now, so the source stays counted.
total, complete = S.Total({ Me = char(NOW + 5 * DAY, nil, src(NOW + 5 * DAY, { [RC] = 4 }), mail(NOW + 5 * DAY, {})) },
    RC, NOW, "Me", 0)
eq(total, 4, "a clock behind saved times still counts")
eq(complete, true, "and is complete")
total, _, rows = S.Total({ B = char(NOW, src(NOW, {}), src(NOW + 5 * DAY, { [RC] = 4 }), mail(NOW, {})) }, RC, NOW, "Me", 0)
eq(rows[1].age, 0, "age of a future t is 0")

-- Row order: self, count desc, name asc.
local os_ = {}
for name, n in pairs({ Zed = 5, Amy = 5, Bob = 9, Me = 1 }) do
    os_[name] = char(NOW, src(NOW, { [RC] = n }), src(NOW, {}), mail(NOW, {}))
end
os_.Me.bags = nil
_, _, rows = S.Total(os_, RC, NOW, "Me", 1)
local names = {}
for i, r in ipairs(rows) do names[i] = r.name end
eq(table.concat(names, ","), "Me,Bob,Amy,Zed", "self, then count desc, then name")

-- Missing
local ms = {
    Zoe = char(NOW, src(NOW, {}), nil, mail(NOW, {})),
    Ann = char(NOW, src(NOW, {}), src(NOW, {}), nil),
    Me = char(NOW, nil, nil, nil),
    Both = char(NOW, src(NOW, {}), src(NOW - 91 * DAY, {}), { unavailable = true }),
    Fine = char(NOW, src(NOW, {}), src(NOW, {}), mail(NOW, {})),
    Unav = char(NOW, src(NOW, {}), { unavailable = true }, { unavailable = true }),
    Gone = char(NOW - 91 * DAY, nil, nil, nil),
}
local miss = S.Missing(ms, NOW, "Me")
local out = {}
for i, m in ipairs(miss) do out[i] = m.name .. (m.self and "*" or "") .. (m.bank and "b" or "") .. (m.mail and "m" or "") end
eq(table.concat(out, ","), "Me*bm,Ann" .. "m,Both" .. "b,Zoe" .. "b", "missing: self first, then name; flags per source")

-- Age buckets
local function age(s) local u, n = S.Age(s); return u .. n end
eq(age(59), "minute1", "59s is minute 1")
eq(age(0), "minute1", "0s is minute 1")
eq(age(120), "minute2", "2 minutes")
eq(age(3599), "minute59", "just under an hour")
eq(age(3600), "hour1", "an hour")
eq(age(2 * 3600), "hour2", "2h is hour 2")
eq(age(86399), "hour23", "just under a day")
eq(age(86400), "day1", "a day")
eq(age(3 * DAY), "day3", "3d is day 3")

-- Malformed records stay unknown, never an empty counted container (Codex diff review).
local okBags = src(NOW, { [RC] = 1 })
local noItems = { expected = { 0 }, c = { [0] = { t = NOW } } }
eq(S.Source(noItems, NOW), "missing", "container without items is missing")
eq(S.Source({ t = NOW }, NOW), "missing", "mail without items is missing")
eq(S.Source(mail(NOW, { [RC] = "5" }), NOW), "missing", "non-numeric count is missing")
local tm, cm = S.Total({ B = char(NOW, okBags, noItems, mail(NOW, {})) }, RC, NOW, "Me", 0)
eq(tm, 1, "malformed bank adds nothing")
eq(cm, false, "malformed bank leaves the total incomplete")
-- Malformed characters and tables are dropped by Prune and ignored by Scope.
local bad = S.New()
bad.realms.R = { A = { Ghost = false, Old = { seen = "x" } }, H = "bad" }
bad.realms.X = 7
S.Prune(bad, NOW)
eq(next(bad.realms), nil, "malformed entries pruned")
local bad2 = S.New(); bad2.realms.R = { A = "bad" }
eq(next(S.Scope(bad2, "R", "A")), nil, "malformed faction gives an empty scope")

H.done()
