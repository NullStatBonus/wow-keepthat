-- The in-game test plan (plans/keepthat.yaml) keeps its numbers in order, and every reference to a
-- check in the code, tests and docs names a step or section the plan has (AGENTS.md, CheckThat).
-- The plan is read with patterns: CI has no YAML library and no CheckThat checkout.
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local function read(path)
    local f = assert(io.open(path), path)
    local s = f:read("*a")
    f:close()
    return s
end

local plan = read("plans/keepthat.yaml")
eq(plan:match("\naddon: (%S+)"), "KeepThat", "the plan is KeepThat's")

-- Sections are "- id: s<N>" at the top level; steps are "  - id: kt.s<N>.<M>" inside them.
local sections, steps, order = {}, {}, {}
local section, nextStep = nil, 1
for line in (plan .. "\n"):gmatch("([^\n]*)\n") do
    local s = line:match("^%- id: (%S+)$")
    if s then
        eq(sections[s], nil, "section id is unique: " .. s)
        sections[s] = true
        order[#order + 1] = s
        eq(s, "s" .. #order, "sections are numbered in order")
        section, nextStep = #order, 1
    end
    local id = line:match("^  %- id: (%S+)$")
    if id then
        eq(steps[id], nil, "step id is unique: " .. id)
        steps[id] = true
        eq(id, ("kt.s%d.%d"):format(section or 0, nextStep), "steps are numbered in order within their section")
        nextStep = nextStep + 1
    end
end
eq(#order >= 10, true, "the plan has its sections (" .. #order .. ")")

-- "test plan check 4.1", "test plan 8.2, 8.3", "test plan section 10", "manual test plan §7".
local files = {}
local p = io.popen("find KeepThat tests docs README.md DESIGN.md AGENTS.md -path KeepThat/Libs -prune -o -type f \\( -name '*.lua' -o -name '*.md' \\) -print")
for path in p:lines() do
    if path ~= "tests/test_plan.lua" then files[#files + 1] = path end
end
p:close()
eq(#files > 20, true, "the reference scan finds the source files (" .. #files .. ")")

local refs = 0
for _, path in ipairs(files) do
    local text = read(path):lower()
    for nums in text:gmatch("test plan%s+[%a\194\167]*%s*([%d][%d%.,%s]*)") do
        for n in nums:gmatch("%d+[%.%d]*") do
            n = n:gsub("%.$", "")
            local major, minor = n:match("^(%d+)%.(%d+)$")
            local want = major and ("kt.s%s.%s"):format(major, minor) or ("s" .. n)
            eq((major and steps or sections)[want] == true, true, path .. " cites test plan " .. n .. ", which the plan has as " .. want)
            refs = refs + 1
        end
    end
end
eq(refs > 0, true, "the code and docs cite the test plan (" .. refs .. ")")

H.done()
