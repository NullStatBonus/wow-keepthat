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

-- Nothing available: empty, no error.
A.env = {}
eq(next(A.ProfessionSkills()), nil, "no API: no skills")

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

H.done()
