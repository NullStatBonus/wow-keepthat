-- Core/Context.lua: skill events refresh only when a rank changed or a profession is gone (review #5:
-- reading every Era rank expands and collapses Skills headers, which fires SKILL_LINES_CHANGED again).
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ns = { defaults = { profile = {} } }
local ranks, hidden = { tailoring = 150 }, {}
local under = { tailoring = "Professions", cooking = "Secondary Skills" }
ns.Adapter = { ProfessionSkills = function()
    local c = {}; for k, v in pairs(ranks) do c[k] = v end; return c, hidden, under end }
H.load("Core/Context.lua", ns)
local C = ns.Context
local calls = 0
C.OnChange(function() calls = calls + 1 end)

C.SkillsChanged()
eq(calls, 0, "no cached context: nothing read since the last refresh, nothing to do")
C.Get()
C.SkillsChanged()
eq(calls, 0, "ranks unchanged: no refresh")
ranks.tailoring = 151
C.SkillsChanged()
eq(calls, 1, "a rank changed: refresh")
C.Get()
ranks.cooking = 1
C.SkillsChanged()
eq(calls, 2, "a new profession: refresh")
C.Get()
ranks.cooking = nil
C.SkillsChanged()
eq(calls, 3, "a profession dropped with nothing hidden: refresh")
C.Get()
ranks.tailoring, hidden = nil, { Professions = true }
C.SkillsChanged()
eq(calls, 3, "a profession out of view under its collapsed header: not a change")
hidden = { ["Weapon Skills"] = true }
C.SkillsChanged()
eq(calls, 4, "gone while only another header is collapsed (Codex re-review): refresh")
ranks.tailoring, hidden = 151, {}
eq(C.Get().skills.tailoring, 151, "the rank is read")

-- With the real adapter: expanding and collapsing headers fires SKILL_LINES_CHANGED, at once (a) or
-- any time later (b). Neither may loop. A rank-up under a collapsed header arrives with CHAT_MSG_SKILL,
-- which refreshes (c).
do
    local ns2 = { defaults = { profile = {} } }
    H.load("Core/Adapter.lua", ns2)
    H.load("Core/Context.lua", ns2)
    local A2, C2 = ns2.Adapter, ns2.Context
    local queue, mode, expands, depth, maxDepth = {}, "now", 0, 0, 0
    local rows = { { name = "Professions", header = true, collapsed = true }, { name = "Tailoring", rank = 150 },
        { name = "Secondary Skills", header = true }, { name = "Cooking", rank = 75 } }
    local function fire()
        if mode == "now" then
            depth = depth + 1; maxDepth = math.max(maxDepth, depth)
            if depth < 20 then C2.SkillsChanged() end
            depth = depth - 1
        else queue[#queue + 1] = true end
    end
    local function visible()
        local v, hide = {}, false
        for _, r in ipairs(rows) do
            if r.header then hide = r.collapsed; v[#v + 1] = r elseif not hide then v[#v + 1] = r end
        end
        return v
    end
    A2.env = {
        GetNumSkillLines = function() return #visible() end,
        GetSkillLineInfo = function(i) local r = visible()[i]; if not r then return nil end
            return r.name, r.header or false, r.header and not r.collapsed or false, r.rank end,
        ExpandSkillHeader = function(i) expands = expands + 1; visible()[i].collapsed = false; fire() end,
        CollapseSkillHeader = function(i) visible()[i].collapsed = true; fire() end,
    }
    C2.OnChange(function() C2.Get() end)   -- the tooltip and overlay read the context again
    C2.Invalidate()
    eq(maxDepth <= 1, true, "(a) events fired during the read do not read again")
    eq(C2.Get().skills.tailoring, 150, "(a) the rank under the collapsed header is read")
    eq(rows[1].collapsed, true, "(a) and the header is collapsed again")
    mode, expands = "queue", 0
    C2.Invalidate()
    local drained = 0
    while #queue > 0 and drained < 50 do
        table.remove(queue, 1); drained = drained + 1
        C2.SkillsChanged()
    end
    eq(#queue, 0, "(b) late events die out, whatever their delay")
    eq(expands, 1, "(b) one expansion for the one refresh")
    rows[4].rank = 76
    C2.SkillsChanged()
    eq(C2.Get().skills.cooking, 76, "a visible rank-up refreshes on SKILL_LINES_CHANGED")
    rows[2].rank = 151
    C2.SkillsChanged()
    eq(C2.Get().skills.tailoring, 150, "a rank-up under a collapsed header is not visible to that event")
    local refreshes = 0
    C2.OnChange(function() refreshes = refreshes + 1 end)
    C2.SkillsChanged(true)   -- CHAT_MSG_SKILL
    eq(C2.Get().skills.tailoring, 151, "(c) the skill chat message picks it up")
    eq(rows[1].collapsed, true, "(c) and the header is collapsed again")
    refreshes = 0
    C2.SkillsChanged(true)   -- a weapon skill-up: no profession rank changed
    eq(refreshes, 0, "(c) a skill message that changes no profession refreshes nothing")
end
-- Codex third review: CHAT_MSG_SKILL's full read fires SKILL_LINES_CHANGED at once; the nested call may
-- refresh first. No error, and the new rank is read.
do
    local ns3 = { defaults = { profile = {} } }
    H.load("Core/Adapter.lua", ns3)
    H.load("Core/Context.lua", ns3)
    local C3 = ns3.Context
    local rows = { { name = "Professions", header = true, collapsed = true }, { name = "Tailoring", rank = 150 } }
    local function visible()
        local v, hide = {}, false
        for _, r in ipairs(rows) do
            if r.header then hide = r.collapsed; v[#v + 1] = r elseif not hide then v[#v + 1] = r end
        end
        return v
    end
    ns3.Adapter.env = {
        GetNumSkillLines = function() return #visible() end,
        GetSkillLineInfo = function(i) local r = visible()[i]; if not r then return nil end
            return r.name, r.header or false, r.header and not r.collapsed or false, r.rank end,
        ExpandSkillHeader = function(i) visible()[i].collapsed = false; C3.SkillsChanged() end,
        CollapseSkillHeader = function(i) visible()[i].collapsed = true; C3.SkillsChanged() end,
    }
    C3.Get()
    rows[2].rank = 151
    local ok, err = pcall(C3.SkillsChanged, true)
    eq(ok, true, "nested refresh during the full read: no error (" .. tostring(err) .. ")")
    eq(C3.Get().skills.tailoring, 151, "and the new rank is read")
    eq(rows[1].collapsed, true, "and the header is collapsed again")
end
-- While debugging, the ranks and collapsed headers are recorded when they change (test plan 9.1).
do
    local ns4 = { defaults = { profile = {} } }
    local recorded = {}
    ns4.Log = { Enabled = function() return true end, Record = function(a, m) recorded[#recorded + 1] = a .. ": " .. m end }
    local r4, h4 = { tailoring = 150, cooking = 75 }, { Professions = true }
    ns4.Adapter = { ProfessionSkills = function() local c = {}; for k, v in pairs(r4) do c[k] = v end; return c, h4, {} end }
    H.load("Core/Context.lua", ns4)
    ns4.Context.Get()
    eq(recorded[1], "skills: cooking=75 tailoring=150; collapsed headers: Professions", "ranks and collapsed headers recorded")
    ns4.Context.Invalidate(); ns4.Context.Get()
    eq(#recorded, 1, "unchanged: not recorded again")
    r4.tailoring = 151
    ns4.Context.Invalidate(); ns4.Context.Get()
    eq(recorded[2], "skills: cooking=75 tailoring=151; collapsed headers: Professions", "a rank-up recorded")
end
H.done()
