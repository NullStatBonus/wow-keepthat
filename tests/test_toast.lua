-- Loot toast: pattern parsing, one toast per item per session, combining, three at a time.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ns = { Adapter = { Resolve = function() end } }
ns.defaults = { profile = { toast = false, colors = { endgame = { r = 1, g = 0, b = 0 }, leveling = { r = 0, g = 1, b = 0 } } } }
H.locale(ns)
H.load("Core/Adapter.lua", ns)
ns.Adapter.env = { LOOT_ITEM_SELF = "You receive loot: %s.", LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d." }
H.load("Core/Adapter_Loot.lua", ns)
H.load("Model/Wording.lua", ns)
local marked = { [12360] = true, [10620] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true }
ns.Context = { Classify = function(id) return marked[id] and { endgame = { { profession = "alchemy" } } } or nil end }
ns.Log = { Failure = function(a, m) error("failure " .. tostring(m)) end }
local starter
ns.Start = function(fn) starter = fn end
H.load("UI/Toast.lua", ns)
local Toast = ns.Toast

local function link(id) return ("|cff1eff00|Hitem:%d::::::::60:::::|h[Item %d]|h|r"):format(id, id) end
local function msg(id, n) return n and ("You receive loot: %sx%d."):format(link(id), n) or ("You receive loot: %s."):format(link(id)) end

-- patterns
local pats = ns.Adapter.LootPatterns()
eq(#pats, 2, "two patterns")
local id, n, name = Toast.Parse(msg(12360), pats)
eq(id, 12360, "single id"); eq(n, 1, "single count"); eq(name, "Item 12360", "name from link")
id, n = Toast.Parse(msg(12360, 3), pats)
eq(id, 12360, "multiple id"); eq(n, 3, "multiple count")
eq(Toast.Parse("You receive item: " .. link(12360) .. ".", pats), nil, "pushed message is not loot")
eq(Toast.Parse("Bob receives loot: " .. link(12360) .. ".", pats), nil, "other player's loot")
eq(#ns.Adapter.LootPatterns(), 2, "patterns stable")

-- fake frames
local made, shown = 0, 0
Toast.factory = function()
    made = made + 1
    local f = { alpha = 1, visible = false }
    function f:Set(ic, title, line, c) self.title, self.line, self.color = title, line, c end
    function f:Place() end
    function f:SetAlpha(a) self.alpha = a end
    function f:Show() self.visible = true end
    function f:Hide() self.visible = false end
    return f
end
local function visible()
    local c = 0
    for _, e in ipairs(Toast.active) do if e.frame.visible then c = c + 1 end end
    return c
end
local function loot(m) Toast.OnLoot(m) end

-- default off
loot(msg(12360, 3))
eq(#Toast.active, 0, "off by default: no toast")
ns.defaults.profile.toast = true
eq(Toast.seen[12360], nil, "off pickup did not use the session slot")

-- unmarked / pushed
loot(msg(999, 2))
loot("You receive item: " .. link(12360) .. ".")
eq(#Toast.active, 0, "unmarked and pushed give none")

-- marked shows, combining
loot(msg(12360, 3))
eq(visible(), 1, "marked item toasts")
eq(Toast.active[1].frame.title, "Item 12360 x3", "name and count") -- ItemName missing: link name
eq(Toast.active[1].frame.line, "|cffff0000Endgame|r: |cffddddddAlchemy|r", "the tooltip line without the prefix, category word colored")
eq(Toast.active[1].frame.color.r, 1, "category color")
loot(msg(12360, 2))
eq(visible(), 1, "no second toast")
eq(Toast.active[1].frame.title, "Item 12360 x5", "count combined")

-- fade, then nothing
Toast.Tick(3.5)
eq(Toast.active[1].frame.alpha < 1, true, "fading")
Toast.Tick(1)
eq(#Toast.active, 0, "faded away")
loot(msg(12360, 1))
eq(#Toast.active, 0, "no toast after it faded")

-- new session
Toast.Reset()
loot(msg(12360, 1))
eq(visible(), 1, "new session toasts again")
Toast.Tick(10)

-- five items: three show, rest after fades
for i = 1, 5 do loot(msg(i, 1)) end
eq(visible(), 3, "three at most")
eq(#Toast.queue, 2, "two queued")
eq(made <= 3, true, "frames pooled")
Toast.Tick(4.1)
eq(visible(), 2, "two queued ones shown as the first fade")
eq(#Toast.queue, 0, "queue empty")
loot(msg(4, 1))
eq(visible(), 2, "queued/shown item not toasted twice")
Toast.Tick(10)

-- Review finding 7: toasts turned off while some wait in the queue: the queued ones never show.
Toast.Reset()
for i = 11, 14 do marked[i] = true; loot(msg(i, 1)) end
eq(#Toast.queue, 1, "one waiting")
ns.defaults.profile.toast = false
Toast.Tick(4.1)
eq(visible(), 0, "nothing shows after toasts are turned off")
eq(#Toast.queue, 0, "and the queue is dropped")
ns.defaults.profile.toast = true

-- An item turned off while it waited is dropped; the others still show.
Toast.Tick(10)
Toast.Reset()
for i = 21, 24 do marked[i] = true; loot(msg(i, 1)) end
marked[24] = nil
Toast.Tick(4.1)
eq(visible(), 0, "the unmarked queued item is dropped")
eq(#Toast.queue, 0, "queue empty")

-- start wires the event
local registered
starter({ RegisterEvent = function(_, ev) registered = ev end })
eq(registered, "CHAT_MSG_LOOT", "event registered")

-- Toast position (moved from the Home page): saved per profile, each next toast stacks below.
do
    local H2 = H
    local p = ns.defaults.profile
    p.toastPosition = nil
    local point, x, y = Toast.Position(1)
    H2.eq(point .. " " .. x .. " " .. y, "TOP 0 -140", "default position")
    Toast.SavePosition("BOTTOMLEFT", 120.4, 300.6)
    H2.eq(p.toastPosition.point .. " " .. p.toastPosition.x .. " " .. p.toastPosition.y, "BOTTOMLEFT 120 301", "saved, rounded")
    point, x, y = Toast.Position(3)
    H2.eq(point .. " " .. x .. " " .. y, "BOTTOMLEFT 120 209", "the third toast stacks two spacings below")
    Toast.ResetPosition()
    H2.eq(p.toastPosition.y, -140, "reset to the default")

    -- Alpha: a short fade in, hold, fade out, all scaled by the toast opacity (OLED: dimmable).
    p.toastOpacity = nil
    H2.eq(Toast.Alpha(0), 0, "starts transparent")
    H2.eq(Toast.Alpha(Toast.FADE_IN), 1, "fully shown after the fade in")
    H2.eq(Toast.Alpha(Toast.SHOW - Toast.FADE / 2), 0.5, "halfway through the fade out")
    p.toastOpacity = 0.5
    H2.eq(Toast.Alpha(1), 1, "lifetime alpha is independent of surface dimming")
    p.toastOpacity = 0
    H2.eq(Toast.Alpha(1), 1, "legacy alpha is applied by the separate layers")
    p.toastOpacity = nil
end

-- /kt demo: three sample toasts, whatever the settings say (toast off here).
Toast.Tick(10)
ns.defaults.profile.toast = false
eq(Toast.Demo(), true, "the demo runs with toasts off")
eq(#Toast.samples, 3, "three isolated sample toasts")
Toast.Demo()
eq(#Toast.samples, 3, "running it again keeps exactly three isolated samples")
Toast.Tick(10)
eq(visible(), 0, "they fade like real toasts")

-- Toast sound (spec loot-toast): once on acceptance, silent count merges, one per burst, samples apart.
do
    local plays, clock = {}, 100
    ns.Sounds = { Play = function(key, ch) plays[#plays + 1] = { key, ch }; return key ~= "none" end }
    ns.Adapter.Now = function() return clock end
    local p = ns.defaults.profile
    p.toastSound, p.toastSoundChannel = "auction", "Master"
    Toast.Tick(10); Toast.Reset(); Toast.lastSound = nil
    for i = 31, 40 do marked[i] = true end

    p.toast = false
    loot(msg(31, 1))
    eq(#plays, 0, "toast off: no sound")
    p.toast = true

    loot(msg(31, 1))
    eq(#plays, 1, "first pickup plays once")
    eq(plays[1][1] .. " " .. plays[1][2], "auction Master", "chosen sound and channel")
    clock = 110
    loot(msg(31, 2))
    eq(#plays, 1, "count added: silent")
    Toast.Tick(10)

    -- Five at once: one sound, none when the queued fourth and fifth show later.
    clock = 200; plays = {}
    for i = 32, 36 do loot(msg(i, 1)) end
    eq(#plays, 1, "five items at once: one sound")
    eq(#Toast.queue, 2, "two wait")
    clock = 204.1; Toast.Tick(4.1)
    eq(#Toast.queue, 0, "the waiting ones showed")
    eq(#plays, 1, "no sound when queued toasts show")
    clock = 201.5; loot(msg(37, 1))
    eq(#plays, 1, "within the cooldown: silent")
    clock = 214; loot(msg(38, 1))
    eq(#plays, 2, "after the cooldown: plays again")
    Toast.Tick(10)

    -- None: the toast shows, silently (Sounds.Play is asked with "none" and plays nothing).
    p.toastSound = "none"; clock = 300; plays = {}
    loot(msg(39, 1))
    local shown39 = false
    for _, e in ipairs(Toast.active) do if e.itemID == 39 then shown39 = true end end
    eq(shown39, true, "None: the toast still shows")
    eq(plays[1][1], "none", "None passed to Sounds.Play")
    p.toastSound = "auction"
    Toast.Tick(10)

    -- Samples: once per request, with toasts off and inside the cooldown, without blocking real loot.
    p.toast = false; clock = 400; Toast.lastSound = 399.5; plays = {}
    Toast.Demo(1); eq(#plays, 1, "preview plays once with toasts off, cooldown ignored")
    Toast.Demo(); eq(#plays, 2, "demo plays once for three samples")
    eq(Toast.lastSound, 399.5, "samples do not record the cooldown")
    Toast.Tick(10)
    p.toast = true; clock = 402; Toast.lastSound = nil
    Toast.Demo(1); plays = {}
    loot(msg(40, 1))
    eq(#plays, 1, "real loot right after a sample still plays")
    Toast.Tick(10)

    -- Unknown time: plays and records nothing.
    ns.Adapter.Now = function() return nil end
    Toast.Reset(); Toast.lastSound = nil; plays = {}
    marked[41] = true; loot(msg(41, 1))
    eq(#plays, 1, "no clock: plays"); eq(Toast.lastSound, nil, "no clock: nothing recorded")
end

H.done()
