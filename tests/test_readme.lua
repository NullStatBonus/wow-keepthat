-- Every command the README lists is one Core/Slash.lua handles (CLAUDE.md, Documentation).
package.path = "tests/?.lua;" .. package.path
local H = require("harness")
local eq = H.eq

local ns = H.locale({})
H.load("Core/Slash.lua", ns)

local f = assert(io.open("README.md"))
local readme = f:read("*a")
f:close()
local section = readme:match("## Commands\n(.-)\n## ")
eq(section ~= nil, true, "README has a Commands section")

local function fakeDeps()
    local noop = function() return "" end
    return { find = function() return {} end, openMaterial = noop, open = noop, setDebug = noop, report = noop, show = noop, demo = noop, testToast = noop, testTooltip = noop, testCopy = noop,
        probe = { Run = noop, Hover = noop, Path = noop } }
end
local usage = ns.Slash.Run("nonsense-command-xyz", fakeDeps())[1]
local listed = 0
for cmd in section:gmatch("`(/kt[^`]*)`") do
    listed = listed + 1
    local args = cmd:gsub("^/kt%s*", ""):gsub("<name>", "Foo"):gsub("%[page%]", "appearance"):gsub("%[topic%]", "appearance"):gsub("%[kind%]", "toast"):gsub("<key>", "toast"):gsub("<value>", "on")
    local out = ns.Slash.Run(args, fakeDeps())
    eq(args == "" or out[1] ~= usage, true, "README command is handled: " .. cmd)
end
eq(listed >= 6, true, "the README lists the commands (" .. listed .. ")")

H.done()
