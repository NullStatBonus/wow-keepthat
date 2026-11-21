-- Core/Adapter.lua: profession ranks on both clients, including localized Classic Era names.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ns = {}
H.load("Core/Adapter.lua", ns)
local A = ns.Adapter

-- Classic Era, German client: GetSkillLineInfo gives localized names, GetSpellInfo names the profession spells.
local lines = { { "Berufe", true }, { "Schneiderei", false, 270 }, { "Kochkunst", false, 120 }, { "Waffe", false, 300 } }
A.env = {
    GetNumSkillLines = function() return #lines end,
    GetSkillLineInfo = function(i) local l = lines[i]; return l[1], l[2], nil, l[3] end,
    GetSpellInfo = function(id) return ({ [3908] = "Schneiderei", [2550] = "Kochkunst" })[id] end,
}
local skills = A.ProfessionSkills()
eq(skills.tailoring, 270, "localized Tailoring found through the profession spell's name")
eq(skills.cooking, 120, "localized Cooking")
eq(next({}) == nil and skills.weapon, nil, "a non-profession skill is ignored")

-- English Era client without GetSpellInfo still works.
lines = { { "Tailoring", false, 50 } }
A.env = { GetNumSkillLines = function() return 1 end,
    GetSkillLineInfo = function(i) local l = lines[i]; return l[1], l[2], nil, l[3] end }
eq(A.ProfessionSkills().tailoring, 50, "English names without any name lookup")

-- Forever: C_SkillInfo by skill line ID.
A.env = { C_SkillInfo = { GetSkillLineInfoByID = function(id) return id == 197 and { skillLineRank = 210 } or nil end } }
eq(A.ProfessionSkills().tailoring, 210, "Forever by skill line ID")

-- Localized display names (localization fix 2): Forever's trade skill names, else the profession spells.
A.env = { C_TradeSkillUI = { GetTradeSkillDisplayName = function(id) return id == 164 and "Schmiedekunst" or nil end },
    GetSpellInfo = function(id) return id == 3908 and "Schneiderei" or nil end }
local names = A.ProfessionDisplayNames()
eq(names.blacksmithing, "Schmiedekunst", "trade skill display name")
eq(names.tailoring, "Schneiderei", "profession spell name")
eq(names.alchemy, nil, "unknown left out")

-- Review #5: Classic Era lists only rows under expanded headers. Collapsed headers are expanded to read
-- the ranks, then collapsed again; the same headers end collapsed.
local function skillTab(rows)
    local t = {}
    local function visible()
        local v, hide = {}, false
        for _, r in ipairs(rows) do
            if r.header then hide = r.collapsed; v[#v + 1] = r elseif not hide then v[#v + 1] = r end
        end
        return v
    end
    t.GetNumSkillLines = function() return #visible() end
    t.GetSkillLineInfo = function(i) local r = visible()[i]; if not r then return nil end
        return r.name, r.header or false, r.header and not r.collapsed or false, r.rank end
    t.ExpandSkillHeader = function(i) local r = visible()[i]; assert(r and r.header, "expand a header"); r.collapsed = false end
    t.CollapseSkillHeader = function(i) local r = visible()[i]; assert(r and r.header, "collapse a header"); r.collapsed = true end
    return t
end
local rows = { { name = "Class Skills", header = true }, { name = "Defense", rank = 50 },
    { name = "Professions", header = true, collapsed = true }, { name = "Tailoring", rank = 150 },
    { name = "Secondary Skills", header = true, collapsed = true }, { name = "Cooking", rank = 75 },
    { name = "Weapon Skills", header = true, collapsed = true }, { name = "Swords", rank = 300 } }
A.env = skillTab(rows)
skills = A.ProfessionSkills()
eq(skills.tailoring, 150, "Tailoring under a collapsed header is read")
eq(skills.cooking, 75, "Cooking under another collapsed header too")
eq(tostring(rows[1].collapsed or false) .. tostring(rows[3].collapsed) .. tostring(rows[5].collapsed) .. tostring(rows[7].collapsed),
    "falsetruetruetrue", "exactly the same headers are collapsed afterwards")
rows[3].collapsed = false
A.ProfessionSkills()
eq(tostring(rows[3].collapsed) .. tostring(rows[5].collapsed), "falsetrue", "an expanded header stays expanded")
local noExpand = skillTab(rows)
noExpand.ExpandSkillHeader = nil
rows[3].collapsed = true
A.env = noExpand
eq(A.ProfessionSkills().tailoring, nil, "without ExpandSkillHeader: only the visible rows, as before")
local failing = skillTab(rows)
failing.ExpandSkillHeader = function() error("blocked") end
A.env = failing
eq(next((A.ProfessionSkills())), nil, "an expand error: nothing read, no error")
eq(rows[3].collapsed, true, "and nothing changed")
-- Codex re-review: one failed collapse leaves only that header open (headers are found by name).
local flaky = skillTab(rows)
local realCollapse, failedOnce = flaky.CollapseSkillHeader, false
flaky.CollapseSkillHeader = function(i)
    if not failedOnce then failedOnce = true; error("blocked") end
    return realCollapse(i)
end
rows[3].collapsed, rows[5].collapsed, rows[7].collapsed = true, true, true
A.env = flaky
eq(A.ProfessionSkills().tailoring, 150, "read with a failing collapse")
eq(tostring(rows[3].collapsed) .. tostring(rows[5].collapsed) .. tostring(rows[7].collapsed), "falsetruetrue",
    "only the header whose collapse failed stays open")
-- visibleOnly: never expands, and says rows were hidden.
rows[3].collapsed = true
local expanded = 0
local watch = skillTab(rows)
local realExpand = watch.ExpandSkillHeader
watch.ExpandSkillHeader = function(i) expanded = expanded + 1; return realExpand(i) end
A.env = watch
local vis, hid = A.ProfessionSkills(true)
eq(vis.tailoring, nil, "visibleOnly: a collapsed profession is not read")
eq(hid.Professions, true, "and the read names the collapsed header that hid rows")
eq(expanded, 0, "and nothing was expanded")
-- Codex re-review: a failed count during the restore still collapses the headers again.
local shaky = skillTab(rows)
local realNum, calls = shaky.GetNumSkillLines, 0
shaky.GetNumSkillLines = function()
    calls = calls + 1
    if calls == 3 then error("busy") end   -- 1: first count, 2: after expanding, 3: first restore scan
    return realNum()
end
rows[3].collapsed, rows[5].collapsed, rows[7].collapsed = true, true, true
A.env = shaky
eq(A.ProfessionSkills().tailoring, 150, "read with a failing count")
eq(tostring(rows[3].collapsed) .. tostring(rows[5].collapsed) .. tostring(rows[7].collapsed), "truetruetrue",
    "every header collapsed again")
local _, _, where = A.ProfessionSkills()
eq(where.tailoring, "Professions", "the header each profession sits under")

-- wow-api review: Forever's C_SkillInfo rows are tables with isCollapsed (no isExpanded), and expand and
-- collapse live in C_SkillInfo. Reached when no profession is found by skill line ID.
local era = skillTab(rows)
local function asTable(i)
    local name, header, isExpanded, rank = era.GetSkillLineInfo(i)
    if not name then return nil end
    return { name = name, isHeader = header, isCollapsed = header and not isExpanded or false, rank = rank }
end
rows[1].collapsed, rows[3].collapsed, rows[5].collapsed, rows[7].collapsed = false, true, true, true
A.env = { C_SkillInfo = { GetNumSkillLines = era.GetNumSkillLines, GetSkillLineInfo = asTable,
    ExpandSkillHeader = era.ExpandSkillHeader, CollapseSkillHeader = era.CollapseSkillHeader } }
skills, hid = A.ProfessionSkills()
eq(skills.tailoring, 150, "Forever: a profession under a collapsed header is read")
eq(next(hid), nil, "Forever: every collapsed header was expanded, none left hidden")
eq(tostring(rows[1].collapsed) .. tostring(rows[3].collapsed) .. tostring(rows[5].collapsed) .. tostring(rows[7].collapsed),
    "falsetruetruetrue", "Forever: the same headers are collapsed afterwards")
local _, hidVis = A.ProfessionSkills(true)
eq(tostring(hidVis["Class Skills"]) .. tostring(hidVis.Professions), "niltrue",
    "Forever visibleOnly: only collapsed headers are named")

-- Nothing available: empty, no error.
A.env = {}
eq(next((A.ProfessionSkills())), nil, "no API: no skills")

-- Footer "Clear search" button in an AceGUI window: shown while wanted, cleaned up on AceGUI's
-- OnRelease callback (fired by AceGUI:Release, the path Close and Escape take), on a window change,
-- and when no window is open (Codex review).
local function fakeFrame()
    local f = { shown = false, points = {} }
    function f:SetSize() end
    function f:SetParent(p) self.parent = p end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function f:SetText(t) self.text = t end
    function f:SetScript(_, fn) self.onClick = fn end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    return f
end
local made, lastButton = 0, nil
A.env = { CreateFrame = function() made = made + 1; lastButton = fakeFrame(); return lastButton end }
local function fakeWidget()
    local statusbg = fakeFrame()
    local w = { frame = fakeFrame(), events = {}, statusbg = statusbg,
        statustext = { GetParent = function() return statusbg end } }
    function w:SetCallback(name, fn) self.events[name] = fn end
    function w:Fire(name) if self.events[name] then self.events[name](self) end end
    return w
end
local function lastX(f) return f.points[#f.points][2] end
local widget = fakeWidget()
eq(A.FooterButton(widget, "Clear search", function() end, true), true, "button placed")
eq(made, 1, "one button")
eq(lastButton.shown, true, "shown while searching")
eq(lastX(widget.statusbg), -236, "the status bar is narrowed while it shows")
A.FooterButton(widget, "Clear search", function() end, false)
eq(lastButton.shown, false, "hidden when not searching")
eq(lastX(widget.statusbg), -132, "and the status bar restored")
A.FooterButton(widget, "Clear search", function() end, true)
widget:Fire("OnRelease")   -- what AceGUI:Release does for Close and Escape
eq(lastButton.shown, false, "released window: the button is hidden")
eq(lastButton.onClick, nil, "and its KeepThat click is gone")
eq(lastX(widget.statusbg), -132, "and the status bar restored")
-- Switching to another window cleans up the first.
local w1, w2 = fakeWidget(), fakeWidget()
A.FooterButton(w1, "Clear search", function() end, true)
A.FooterButton(w2, "Clear search", function() end, false)
eq(lastX(w1.statusbg), -132, "the previous window's status bar is restored on a switch")
-- No open window: hidden.
A.FooterButton(w1, "Clear search", function() end, true)
eq(A.FooterButton(nil, "Clear search", function() end, true), false, "no window: nothing shown")
eq(lastButton.shown, false, "and the button is hidden")
eq(lastX(w1.statusbg), -132, "and the status bar restored")
eq(made, 1, "the same button is reused")


-- Closing the game's Settings window: the current SettingsPanel, the older frame, or nothing.
local hidden = {}
local function panel(name) return { Hide = function() hidden[#hidden + 1] = name .. ":Hide" end } end
A.env = { SettingsPanel = panel("SettingsPanel"), HideUIPanel = function(f) hidden[#hidden + 1] = f == A.env.SettingsPanel and "SettingsPanel" or "other" end }
eq(A.CloseGameSettings(), true, "SettingsPanel closed")
eq(hidden[#hidden], "SettingsPanel", "through HideUIPanel")
A.env = { InterfaceOptionsFrame = panel("InterfaceOptionsFrame") }
eq(A.CloseGameSettings(), true, "older options frame closed")
eq(hidden[#hidden], "InterfaceOptionsFrame:Hide", "with Hide when HideUIPanel is missing")
A.env = { SettingsPanel = panel("SettingsPanel"), HideUIPanel = function() error("blocked") end }
eq(A.CloseGameSettings(), true, "an error while closing is contained")
A.env = {}
eq(A.CloseGameSettings(), nil, "no Settings window: nil")
-- Events: the client says which exist; unknown when it cannot.
A.env = { C_EventUtils = { IsEventValid = function(e) return e == "LEARNED_SPELL_IN_SKILL_LINE" end } }
eq(A.EventKnown("LEARNED_SPELL_IN_SKILL_LINE"), true, "a client event is known")
eq(A.EventKnown("LEARNED_SPELL_IN_TAB"), false, "a removed event is not")
A.env = {}
eq(A.EventKnown("LEARNED_SPELL_IN_TAB"), nil, "no IsEventValid: unknown")

-- AceDB 33's character key: UnitName - GetRealmName, realm spaces kept; nil when a part is missing.
A.env = { UnitName = function() return "Bob" end, GetRealmName = function() return "Argent Dawn" end }
eq(A.LegacyCharacterKey(), "Bob - Argent Dawn", "realm with a space kept as is")
A.env = { UnitName = function() return "Bob" end }
eq(A.LegacyCharacterKey(), nil, "no GetRealmName: nil")
A.env = { UnitName = function() return "" end, GetRealmName = function() return "R" end }
eq(A.LegacyCharacterKey(), nil, "empty name: nil")
A.env = { UnitName = function() error("x") end, GetRealmName = function() return "R" end }
eq(A.LegacyCharacterKey(), nil, "an error: nil")

-- Sounds (Core/Adapter_Sound.lua): guarded play calls, channel limited to Master/SFX, sound packs.
H.load("Core/Adapter_Sound.lua", ns)
A.env = {}
eq(A.PlaySound(5274, "Master"), nil, "no PlaySound: nil")
eq(A.SoundPacks(), nil, "no LibStub: nil")
local played
A.env = { PlaySound = function(id, ch) played = { id, ch }; return true, 7 end,
    PlaySoundFile = function(p, ch) played = { p, ch }; return false end }
eq(A.PlaySound(416, "Music"), true, "willPlay returned")
eq(played[1], 416, "id passed"); eq(played[2], "Master", "unknown channel becomes Master")
A.PlaySound(416, "SFX"); eq(played[2], "SFX", "SFX kept")
eq(A.PlaySoundFile("x.ogg", "SFX"), false, "PlaySoundFile willPlay false passed through")
A.env = { PlaySound = function() error("boom") end }
eq(A.PlaySound(416), nil, "an error gives nil")
A.env = { LibStub = function(name, silent) return nil end }
eq(A.SoundPacks(), nil, "LibStub without the library: nil")
local lsm = { HashTable = function(self, kind) return kind == "sound" and { None = "x", ["Air Horn"] = "horn.ogg", Bad = {} } or {} end }
A.env = { LibStub = setmetatable({}, { __call = function(_, name) return name == "LibSharedMedia-3.0" and lsm or nil end }) }
local packs = A.SoundPacks()
eq(packs["Air Horn"], "horn.ogg", "a registered sound")
eq(packs.None, nil, "the library's None entry is left out")
eq(packs.Bad, nil, "a non-path value is left out")
lsm.HashTable = function() error("broken") end
eq(A.SoundPacks(), nil, "a library error gives nil")
H.done()
