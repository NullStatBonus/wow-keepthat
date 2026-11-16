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

H.done()
