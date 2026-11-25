-- /kt commands: plain /kt opens settings, debug on|off, log and probe open the copy window; anything else prints the usage.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ns = H.locale({})
H.load("Core/Slash.lua", ns)

local shown, opened, debug = {}, 0, nil
local deps = {
    probe = { Run = function() return "full" end, Hover = function() return "hover" end,
        Path = function(p) return "path " .. p end },
    show = function(title, text) shown[#shown + 1] = title .. ":" .. text end,
    open = function() opened = opened + 1 end,
    setDebug = function(on) debug = on end,
    report = function() return "the report" end,
}
eq(#ns.Slash.Run("probe", deps), 0, "probe prints nothing")
eq(shown[1], "KeepThat probe:full", "probe shows the report")
ns.Slash.Run("  PROBE   Hover ", deps)
eq(shown[2], "KeepThat probe:hover", "probe hover, any case and spacing")
ns.Slash.Run("probe path DFLProfessionJournalNS.API", deps)
eq(shown[3], "KeepThat probe:path DFLProfessionJournalNS.API", "probe path keeps the name's case")
ns.Slash.Run("probe path", deps)
eq(shown[4], "KeepThat probe:full", "probe path without a name shows the full report")

local usage = "Commands: /kt, /kt find <name>, /kt demo, /kt test <toast|tooltip|copy>, /kt debug on|off, /kt log, /kt probe, /kt probe hover, /kt probe path <name>"
eq(#ns.Slash.Run("", deps), 0, "plain /kt prints nothing")
eq(opened, 1, "plain /kt opens the settings")
ns.Slash.Run("   ", deps)
eq(opened, 2, "blank input opens the settings too")
eq(ns.Slash.Run("nonsense", deps)[1], usage, "unknown command prints usage")
eq(ns.Slash.Run("debug", deps)[1], usage, "debug without on/off prints usage")
eq(ns.Slash.Run("debug maybe", deps)[1], usage, "debug with a bad argument prints usage")
eq(opened, 2, "usage opens no settings")

eq(debug, nil, "debug untouched so far")
eq(ns.Slash.Run("debug on", deps)[1], "Debug recording is on. Type /kt log to see the report.", "debug on says so")
eq(debug, true, "debug on turns recording on")
ns.Slash.Run("DEBUG OFF", deps)
eq(debug, false, "debug off turns recording off")

eq(#ns.Slash.Run("log", deps), 0, "log prints nothing")
eq(shown[5], "KeepThat debug report:the report", "log shows the report in the copy window")
eq(#shown, 5, "usage opens no window")

-- /kt demo always shows the visuals.
local tested = 0
local d2 = { open = function() end, setDebug = function() end, report = function() return "" end,
    show = function() end, probe = { Run = function() end }, demo = function() tested = tested + 1 end }
local out = ns.Slash.Run("demo", d2)
eq(tested, 1, "/kt demo shows the sample visuals")
eq(out[1]:find("sample toasts", 1, true) ~= nil, true, "and says what it shows")

-- /kt demo logs what it showed, and "ended" once when the tint sample hides.
local rec = {}
ns.Log = { Record = function(area, m) rec[#rec + 1] = "[" .. area .. "] " .. m end }
local endTint
local dd = { testToastAll = function() return 3 end, testTooltip = function() return true end,
    showTint = function(onEnd) endTint = onEnd; return true end }
ns.Slash.Demo(dd)
eq(rec[1], "[demo] started: toasts=3 tooltip=true tint=true", "demo start line")
eq(#rec, 1, "no ended line before the tint hides")
endTint()
eq(rec[2], "[demo] ended", "demo ended line when the tint hides")
dd.testToastAll = function() return 0 end; dd.testTooltip = function() return true end; dd.showTint = function() return false end
ns.Slash.Demo(dd)
eq(rec[3], "[demo] started: toasts=0 tooltip=true tint=false", "demo start line when only the tooltip showed")
ns.Log = nil

-- /kt test <type>: one explicit in-game test (like /cvn test <kind>).
local ran = {}
local d3 = { open = function() end, setDebug = function() end, report = function() return "" end, show = function() end,
    probe = { Run = function() end }, demo = function() end,
    testToast = function() ran[#ran + 1] = "toast" end, testTooltip = function() ran[#ran + 1] = "tooltip" end,
    testCopy = function() ran[#ran + 1] = "copy" end }
ns.Slash.Run("test toast", d3); ns.Slash.Run("test TOOLTIP", d3); ns.Slash.Run("test copy", d3)
eq(table.concat(ran, ","), "toast,tooltip,copy", "each test type runs its own test")
eq(ns.Slash.Run("test", d3)[1], "Tests: /kt test toast, /kt test tooltip, /kt test copy. /kt demo shows them all.", "no type lists them")
eq(#ran, 3, "listing runs nothing")

local matches, selected, query = {}, nil, nil
local findDeps = { find = function(q) query = q; return matches end,
    openMaterial = function(result) selected = result end }
eq(ns.Slash.Run("find", findDeps)[1], "Usage: /kt find <name>", "find without argument gives usage")
eq(ns.Slash.Run("find missing", findDeps)[1], 'No materials match "missing".', "find none")
matches = { { name = "Arcanite Bar", categoryName = "Endgame materials", professionName = "Blacksmithing" } }
eq(#ns.Slash.Run(" FIND Arcanite ", findDeps), 0, "one match prints nothing")
eq(query, "Arcanite", "find preserves query")
eq(selected, matches[1], "one match opens material")
selected = nil
local searched
findDeps.openSearch = function(q, found) searched = { query = q, found = found } end
matches[2] = { name = "Arcanite Bar", categoryName = "Materials", professionName = "Engineering" }
local results = ns.Slash.Run("find arcanite bar", findDeps)
eq(#results, 0, "several matches print nothing in chat")
eq(searched and searched.query, "arcanite bar", "several matches open Materials filtered to the query")
eq(searched and #searched.found, 2, "with every match")
eq(selected, nil, "and open no single material page")
searched = nil
matches = { { name = "Linen Cloth", visible = false, flags = { leveling = true } },
    { name = "Linen Cloth", visible = false, flags = { leveling = true } } }
eq(ns.Slash.Run("find linen", findDeps)[1], "Linen Cloth is a leveling material. Turn on Leveling materials on Home to see it.",
    "several matches all hidden by Home: explained")
eq(searched, nil, "and nothing opens")
-- /kt find on a material the Home checkboxes hide: say which checkbox shows it, open nothing.
local openedHidden = 0
local hiddenDeps = { find = function() return { { name = "Linen Cloth", visible = false, flags = { leveling = true } } } end,
    openMaterial = function() openedHidden = openedHidden + 1 end }
eq(ns.Slash.Run("find linen", hiddenDeps)[1], "Linen Cloth is a leveling material. Turn on Leveling materials on Home to see it.", "hidden by Home: explained")
eq(openedHidden, 0, "nothing opened")

-- /kt help stock, /kt status stock.
eq(ns.Slash.Run("help bogus", deps)[1], "Topics: appearance, diagnostics, domain, stock.", "topic list names stock")
eq(ns.Slash.Run("status bogus", deps)[1], "Topics: appearance, diagnostics, domain, stock.", "status topic list names stock")
eq(ns.Slash.Run("help stock", deps)[1], "Stock: /kt status stock lists banks and mailboxes not counted. /kt set stock.reminder on|off turns the login reminder on or off.", "help stock")
eq(ns.Slash.Run("status stock", deps)[1], "Stock is not known yet.", "no recorder: not known")
local miss, counted, ident = {}, 3, function() return "Me", "Realm", "Alliance" end
ns.StockRecorder = { Identity = function() return ident() end, Counted = function() return counted end,
    Missing = function() return miss end }
local o = ns.Slash.Run("STATUS Stock", deps)
eq(o[1], "Stock: 3 characters on Realm (Alliance).", "scope line")
eq(o[2], "Every bank and mailbox is counted.", "nothing missing")
eq(#o, 2, "and no more lines")
ns.StockRecorder.State = function() return { unavailable = { bank = true, mail = false } } end
eq(ns.Slash.Run("status stock", deps)[2], "Every bank and mailbox this client can read is counted.", "unreadable source named in the summary")
ns.StockRecorder.State = nil
counted = 1
eq(ns.Slash.Run("status stock", deps)[1], "Stock: 1 character on Realm (Alliance).", "singular scope line")
counted = 3
miss = { { name = "Me", self = true, bank = true, mail = false }, { name = "Alt", bank = false, mail = true },
    { name = "Old", bank = true, mail = true } }
o = ns.Slash.Run("status stock", deps)
eq(o[2], "Me: bank not counted.", "bank only")
eq(o[3], "Alt: mailbox not counted.", "mailbox only")
eq(o[4], "Old: bank and mailbox not counted.", "both")
eq(#o, 4, "no all-counted line when something is missing")
ident = function() return nil end
eq(ns.Slash.Run("status stock", deps)[1], "Stock is not known yet.", "identity unknown")
ident = function() return "Me", "Realm", "Alliance" end
ns.StockRecorder.Missing = function() return nil end
eq(ns.Slash.Run("status stock", deps)[1], "Stock is not known yet.", "missing unknown")
ns.StockRecorder = nil

H.done()
